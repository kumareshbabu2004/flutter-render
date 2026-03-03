/**
 * Preview Routes
 * --------------
 * POST /generate-preview
 *   Receives bracket JSON + product identifiers, generates SVG,
 *   composites onto the correct mockup, returns preview image.
 *   Persists all artifacts under a unique artifactId.
 *
 * GET  /preview/:id
 *   Retrieve a previously generated preview by ID.
 *
 * GET  /products
 *   Return the product catalog (active only by default).
 *   ?includeInactive=true for admin/testing.
 *
 * Product resolution order:
 *   1. shopifyProductId  (numeric Shopify ID)
 *   2. productId         (internal BMB ID like "bp_grid_iron")
 *   3. mockupUrl         (explicit override — skips catalog lookup)
 */

const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');

const config = require('../config');
const { generateBracketSvg } = require('../services/svg-generator');
const { compositePreview, getMockupPath } = require('../services/compositor');
const productConfig = require('../services/product-config');
const artifactStore = require('../services/artifact-store');

/**
 * POST /generate-preview
 *
 * Body (JSON):
 *   bracketTitle:      string   "MARCH MADNESS 2025"
 *   championName:      string   "DUKE"
 *   teamCount:         number   16
 *   teams:             string[] ["Team 1", "Team 2", ...]
 *   picks:             object   { "slot_left_r0_m0_team1": "Duke", ... }
 *   style:             string   "classic" | "premium" | "bold"
 *   productId:         string   "bp_grid_iron"           (internal BMB ID)
 *   shopifyProductId:  string   "9208241586344"          (Shopify product ID)
 *   shopifyVariantId:  string   "48123456789003"         (Shopify variant ID)
 *   colorName:         string   "Black"
 *   isDarkGarment:     boolean  true
 *   mockupUrl:         string   (optional explicit override URL)
 *
 * Returns (JSON — when ?format=json):
 *   { previewUrl, svgUrl, printReadyRgbUrl, artifactId, ... }
 */
router.post('/generate-preview', async (req, res) => {
  try {
    const {
      bracketTitle = 'TOURNAMENT',
      championName = 'TBD',
      teamCount = 16,
      teams = [],
      picks = {},
      style = 'classic',
      productId,
      shopifyProductId,
      shopifyVariantId,
      colorName = 'Black',
      isDarkGarment = true,
      mockupUrl,
    } = req.body;

    // Validate
    if (teamCount < 4 || teamCount > 64 || (teamCount & (teamCount - 1)) !== 0) {
      return res.status(400).json({ error: 'teamCount must be a power of 2 between 4 and 64' });
    }

    // -- Resolve product from catalog --
    const product = productConfig.findProduct(shopifyProductId)
      || productConfig.findProduct(productId)
      || null;

    // Generate unique IDs
    const artifactId = artifactStore.generateArtifactId();
    const outputFilename = `preview_${artifactId}`;

    // Step 1: Generate bracket SVG
    const palette = isDarkGarment ? 'light' : 'dark';
    const svgString = generateBracketSvg({
      bracketTitle,
      championName,
      teamCount,
      teams,
      picks,
      style,
      palette,
    });

    // Step 2: Determine mockup image source via product config
    let mockupPath;

    if (mockupUrl) {
      mockupPath = mockupUrl;
    } else if (product) {
      mockupPath = productConfig.getMockupSource(product);
    } else {
      const resolvedId = productId || 'bp_grid_iron';
      const localPath = getMockupPath(resolvedId, colorName);
      if (localPath) mockupPath = localPath;
    }

    if (!mockupPath) {
      return res.status(400).json({
        error: `No mockup found for product. Provide productId, shopifyProductId, or mockupUrl.`,
        hint: 'Valid productIds: ' + productConfig.getAllProducts().map(p => p.internalId).join(', '),
      });
    }

    // Step 3: Get placement from product config (or defaults)
    const placement = product
      ? productConfig.getPlacement(product)
      : { xCenter: true, yOffsetPx: 500, bracketWidthPct: 0.45 };

    const result = await compositePreview({
      svgString,
      mockupPath,
      outputFilename,
      bracketWidthPct: placement.bracketWidthPct,
      collarOffset: placement.yOffsetPx,
      format: 'jpeg',
    });

    // Step 4: Persist artifacts
    const artifactMeta = {
      bracketTitle,
      championName,
      teamCount,
      style,
      productId: product ? product.internalId : productId,
      shopifyProductId: product ? product.shopifyProductId : shopifyProductId,
      shopifyVariantId: shopifyVariantId || null,
      colorName,
      isDarkGarment,
    };

    artifactStore.saveArtifact({
      artifactId,
      previewPath: result.previewPath,
      svgPath: result.svgPath,
      printReadyRgbPath: result.printReadyRgbPath,
      printReadyCmykPath: result.printReadyCmykPath,
      metadata: artifactMeta,
    });

    // Return based on requested format
    const wantJson = req.query.format === 'json';

    if (wantJson) {
      const baseUrl = `${req.protocol}://${req.get('host')}`;
      const jsonResponse = {
        previewUrl: `${baseUrl}/output/previews/${outputFilename}.jpg`,
        svgUrl: `${baseUrl}/output/svgs/${outputFilename}.svg`,
        printReadyRgbUrl: `${baseUrl}/output/print_ready/${outputFilename}_rgb.png`,
        artifactId,
        previewId: artifactId, // backward compat
        colorModes: config.colorModes,
        dimensions: result.dimensions,
      };

      // Product metadata (if resolved)
      if (product) {
        jsonResponse.product = {
          internalId: product.internalId,
          shopifyProductId: product.shopifyProductId,
          shopifyHandle: product.shopifyHandle,
          title: product.shortTitle,
          productType: product.productType,
        };
      }

      // CMYK URL if generated
      if (result.printReadyCmykPath) {
        const cmykFilename = path.basename(result.printReadyCmykPath);
        jsonResponse.printReadyCmykUrl = `${baseUrl}/output/print_ready_cmyk/${cmykFilename}`;
      }

      return res.json(jsonResponse);
    }

    // Default: return image binary
    res.set('Content-Type', 'image/jpeg');
    res.set('Content-Disposition', `inline; filename="${outputFilename}.jpg"`);
    res.set('X-Preview-Id', artifactId);
    res.set('X-Artifact-Id', artifactId);
    if (product) {
      res.set('X-Product-Id', product.internalId);
      res.set('X-Shopify-Product-Id', product.shopifyProductId);
    }
    res.send(result.previewBuffer);

  } catch (err) {
    console.error('[Preview] Error:', err.message);
    res.status(500).json({ error: 'Preview generation failed', details: err.message });
  }
});

/**
 * GET /preview/:id
 * Retrieve a previously generated preview by ID.
 */
router.get('/preview/:id', (req, res) => {
  const previewPath = path.join(__dirname, '..', '..', 'output', 'previews', `preview_${req.params.id}.jpg`);
  if (fs.existsSync(previewPath)) {
    res.sendFile(previewPath);
  } else {
    res.status(404).json({ error: 'Preview not found' });
  }
});

/**
 * GET /products
 * Return the product catalog.
 *
 * By default returns only isActive=true products.
 * Add ?includeInactive=true to include all products (for admin/testing).
 */
router.get('/products', (req, res) => {
  const includeInactive = req.query.includeInactive === 'true';

  const rawProducts = includeInactive
    ? productConfig.getAllProductsIncludingInactive()
    : productConfig.getAllProducts();

  const products = rawProducts.map(p => ({
    internalId: p.internalId,
    shopifyProductId: p.shopifyProductId,
    shopifyHandle: p.shopifyHandle,
    title: p.title,
    shortTitle: p.shortTitle,
    productType: p.productType,
    colors: p.colors,
    sizes: p.sizes,
    basePrice: p.basePrice,
    printUpcharge: p.printUpcharge,
    previewPlacement: p.previewPlacement,
    isActive: p.isActive,
    ...(includeInactive ? {
      discontinuedAt: p.discontinuedAt || null,
      supportedVariants: p.supportedVariants || [],
    } : {}),
  }));

  res.json({ products, count: products.length });
});

module.exports = router;
