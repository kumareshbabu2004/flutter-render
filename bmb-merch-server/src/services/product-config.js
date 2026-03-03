/**
 * Product Configuration Service
 * -----------------------------
 * Loads product-catalog.json at startup and provides lookup methods
 * for resolving Shopify product/variant IDs to merch pipeline config.
 *
 * This is the SINGLE SOURCE OF TRUTH for product -> mockup -> placement
 * mapping. No hardcoded product IDs anywhere else in the codebase.
 *
 * Catalog v2.0 additions:
 *   - isActive:          boolean (replaces "active" — used by GET /products filter)
 *   - discontinuedAt:    ISO date or null (informational, set when product retired)
 *   - supportedVariants: array of Shopify variant IDs currently fulfillable
 *
 * Admin toggle:
 *   - toggleActive(internalId, isActive) — updates catalog + re-indexes
 *     No redeploy needed; PATCH /admin/products/:internalId calls this.
 *
 * Lookup strategies (tried in order):
 *   1. shopifyProductId  (from Shopify webhook line_items[].product_id)
 *   2. internalId        (from Flutter app productId like "bp_grid_iron")
 *   3. shopifyHandle     (from Shopify product URL slug)
 */

const path = require('path');
const fs = require('fs');

const CATALOG_PATH = path.join(__dirname, '..', 'data', 'product-catalog.json');
const MOCKUPS_DIR = path.join(__dirname, '..', '..', 'assets', 'mockups');

let _catalog = null;
let _byInternal = {};   // internalId -> product
let _byShopifyId = {};  // shopifyProductId -> product
let _byHandle = {};     // shopifyHandle -> product

// Also index ALL products (active + inactive) for admin operations
let _allByInternal = {};

/**
 * Load the product catalog from JSON.
 * Called once at startup; can be reloaded by calling again.
 */
function loadCatalog() {
  if (!fs.existsSync(CATALOG_PATH)) {
    console.error(`[ProductConfig] Catalog not found: ${CATALOG_PATH}`);
    _catalog = { products: [] };
    return;
  }

  const raw = fs.readFileSync(CATALOG_PATH, 'utf8');
  _catalog = JSON.parse(raw);

  // Migrate: convert legacy "active" field to "isActive"
  for (const p of _catalog.products) {
    if (p.isActive === undefined && p.active !== undefined) {
      p.isActive = p.active;
    }
    // Default to true if neither field exists
    if (p.isActive === undefined) {
      p.isActive = true;
    }
  }

  // Build indexes
  _byInternal = {};
  _byShopifyId = {};
  _byHandle = {};
  _allByInternal = {};

  for (const p of _catalog.products) {
    _allByInternal[p.internalId] = p;

    if (!p.isActive) continue;
    _byInternal[p.internalId] = p;
    _byShopifyId[p.shopifyProductId] = p;
    _byHandle[p.shopifyHandle] = p;
  }

  const total = _catalog.products.length;
  const active = Object.keys(_byInternal).length;
  console.log(`[ProductConfig] Loaded ${total} products (${active} active, ${total - active} inactive)`);
}

// Auto-load on require
loadCatalog();

/* ──────────────────────────────────────────────────────────
 * Lookup functions
 * ────────────────────────────────────────────────────────── */

/**
 * Find a product by any identifier (active products only).
 */
function findProduct(id) {
  if (!id) return null;
  return _byInternal[id] || _byShopifyId[id] || _byHandle[id] || null;
}

/**
 * Find by Shopify numeric product ID (from webhook payload).
 */
function findByShopifyId(shopifyProductId) {
  return _byShopifyId[String(shopifyProductId)] || null;
}

/**
 * Find by internal BMB product ID (from Flutter app).
 */
function findByInternalId(internalId) {
  return _byInternal[internalId] || null;
}

/**
 * Find by internal ID (ANY product, active or inactive).
 * Used by admin endpoints and webhook (which may reference inactive products).
 */
function findByInternalIdAll(internalId) {
  return _allByInternal[internalId] || null;
}

/**
 * Find by Shopify product ID (ANY product, active or inactive).
 * Used by webhook — orders may reference products that were
 * deactivated after the order was placed.
 */
function findByShopifyIdAll(shopifyProductId) {
  const id = String(shopifyProductId);
  for (const p of (_catalog ? _catalog.products : [])) {
    if (p.shopifyProductId === id) return p;
  }
  return null;
}

/**
 * Get the mockup image path for a product.
 */
function getMockupSource(product) {
  if (!product || !product.mockup) return null;
  if (product.mockup.localFile) {
    const localPath = path.join(MOCKUPS_DIR, product.mockup.localFile);
    if (fs.existsSync(localPath)) return localPath;
  }
  return product.mockup.fallbackUrl || null;
}

/**
 * Get preview placement config for a product.
 */
function getPlacement(product) {
  if (!product || !product.previewPlacement) {
    return { xCenter: true, yOffsetPx: 500, bracketWidthPct: 0.45 };
  }
  return product.previewPlacement;
}

/**
 * Resolve a Shopify variant ID from color + size.
 */
function resolveVariantId(product, color, size) {
  if (!product || !product.shopifyVariantIds) return null;
  const key = `${color} / ${size}`;
  return product.shopifyVariantIds[key] || null;
}

/**
 * Check if a variant is in the supportedVariants list.
 */
function isVariantSupported(product, variantId) {
  if (!product || !product.supportedVariants) return true; // No filter = all supported
  return product.supportedVariants.includes(String(variantId));
}

/**
 * Get all active products.
 */
function getAllProducts() {
  return _catalog ? _catalog.products.filter(p => p.isActive) : [];
}

/**
 * Get ALL products (active + inactive). Used by admin endpoints.
 */
function getAllProductsIncludingInactive() {
  return _catalog ? [..._catalog.products] : [];
}

/**
 * Determine if a product is a hoodie.
 */
function isHoodie(product) {
  if (!product) return true;
  return product.productType === 'hoodie';
}

/* ──────────────────────────────────────────────────────────
 * Admin: toggle isActive without server redeploy
 * ────────────────────────────────────────────────────────── */

/**
 * Toggle a product's isActive flag and persist to disk.
 *
 * @param {string} internalId
 * @param {boolean} isActive
 * @returns {{ success: boolean, product?: Object, error?: string }}
 */
function toggleActive(internalId, isActive) {
  const product = _allByInternal[internalId];
  if (!product) {
    return { success: false, error: `Product not found: ${internalId}` };
  }

  const wasActive = product.isActive;
  product.isActive = isActive;

  // Set discontinuedAt when deactivating (clear when reactivating)
  if (!isActive && wasActive) {
    product.discontinuedAt = new Date().toISOString();
  } else if (isActive && !wasActive) {
    product.discontinuedAt = null;
  }

  // Persist to disk
  try {
    fs.writeFileSync(CATALOG_PATH, JSON.stringify(_catalog, null, 2));
  } catch (err) {
    // Revert in-memory
    product.isActive = wasActive;
    return { success: false, error: `Failed to write catalog: ${err.message}` };
  }

  // Re-index
  loadCatalog();

  console.log(`[ProductConfig] ${internalId} isActive: ${wasActive} → ${isActive}`);
  return {
    success: true,
    product: {
      internalId: product.internalId,
      title: product.shortTitle,
      isActive: product.isActive,
      discontinuedAt: product.discontinuedAt,
    },
  };
}

module.exports = {
  loadCatalog,
  findProduct,
  findByShopifyId,
  findByInternalId,
  findByInternalIdAll,
  findByShopifyIdAll,
  getMockupSource,
  getPlacement,
  resolveVariantId,
  isVariantSupported,
  getAllProducts,
  getAllProductsIncludingInactive,
  isHoodie,
  toggleActive,
};
