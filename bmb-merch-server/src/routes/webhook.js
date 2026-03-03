/**
 * Shopify Webhook Routes
 * ----------------------
 * POST /webhooks/shopify
 *   Listens for Shopify "orders/paid" webhook.
 *   On payment:
 *     1. Verify HMAC signature
 *     2. Idempotency check (fulfillment_log)
 *     3. Extract order details (customer, product, bracket data)
 *     4. Load artifacts by artifactId if present; otherwise regenerate
 *     5. Generate packing slip PDF
 *     6. Deliver to printer (email + optional folder/sftp)
 *     7. Log fulfillment status
 *
 * POST /webhooks/shopify/test  (ADMIN_TOKEN protected)
 *   Accepts a sample payload and runs the full processing pipeline
 *   (artifact load, packing slip, printer delivery) for testing
 *   without Shopify. Bypasses HMAC verification.
 */

const express = require('express');
const router = express.Router();
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const config = require('../config');
const { generateBracketSvg } = require('../services/svg-generator');
const { generatePrintReady } = require('../services/compositor');
const { generatePackingSlip } = require('../services/packing-slip');
const { deliverPrintFiles } = require('../services/printer-delivery');
const productConfig = require('../services/product-config');
const artifactStore = require('../services/artifact-store');
const fulfillmentLog = require('../services/fulfillment-log');

/* ──────────────────────────────────────────────────────────
 * Admin Token Check (for /test endpoint)
 * ────────────────────────────────────────────────────────── */
function requireAdminToken(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.admin_token;
  if (!config.adminToken) {
    return res.status(503).json({ error: 'Admin not configured — set ADMIN_TOKEN env var' });
  }
  if (!token || token !== config.adminToken) {
    return res.status(401).json({ error: 'Invalid or missing admin token' });
  }
  next();
}

/* ──────────────────────────────────────────────────────────
 * HMAC Verification
 * ────────────────────────────────────────────────────────── */
function verifyShopifyHmac(rawBody, hmacHeader) {
  const secret = process.env.SHOPIFY_WEBHOOK_SECRET;
  if (!secret || secret.startsWith('whsec_xxx')) {
    console.warn('[Webhook] No SHOPIFY_WEBHOOK_SECRET set -- skipping verification in dev mode');
    return true;
  }
  if (!hmacHeader) return false;
  try {
    const hash = crypto
      .createHmac('sha256', secret)
      .update(rawBody)
      .digest('base64');
    const hashBuf = Buffer.from(hash);
    const hmacBuf = Buffer.from(hmacHeader);
    if (hashBuf.length !== hmacBuf.length) return false;
    return crypto.timingSafeEqual(hashBuf, hmacBuf);
  } catch {
    return false;
  }
}

/* ──────────────────────────────────────────────────────────
 * POST /webhooks/shopify
 * ────────────────────────────────────────────────────────── */
router.post('/shopify', async (req, res) => {
  try {
    // -- Step 1: Verify HMAC --
    const hmac = req.headers['x-shopify-hmac-sha256'];
    const topic = req.headers['x-shopify-topic'];

    if (!verifyShopifyHmac(req.body, hmac)) {
      console.error('[Webhook] HMAC verification failed');
      return res.status(401).json({ error: 'HMAC verification failed' });
    }

    // Parse body (raw Buffer from express.raw middleware)
    const order = JSON.parse(req.body.toString());
    const shopifyOrderId = String(order.id || order.name || '');

    console.log(`[Webhook] Received ${topic} for order ${order.name || order.id}`);
    console.log(`[FULFILLMENT] webhook orderId=${shopifyOrderId} status=started`);

    // Only process orders/paid
    if (topic && topic !== 'orders/paid') {
      console.log(`[Webhook] Ignoring topic: ${topic}`);
      return res.status(200).json({ status: 'ignored', topic });
    }

    // -- Step 2: Idempotency check --
    const { alreadyProcessed, entry: existingEntry } = fulfillmentLog.checkIdempotency(shopifyOrderId);
    if (alreadyProcessed) {
      console.log(`[Webhook] Order ${shopifyOrderId} already processed — skipping`);
      return res.status(200).json({
        status: 'already_processed',
        orderNumber: existingEntry.orderNumber,
        processedAt: existingEntry.processedAt,
        artifactId: existingEntry.artifactId,
      });
    }

    // -- Step 3: Extract order details --
    const orderData = extractOrderData(order);

    if (!orderData.bracketId) {
      console.log(`[Webhook] Order ${orderData.orderNumber} has no bracket_id -- standard order, skipping print flow`);
      return res.status(200).json({ status: 'ok', message: 'No bracket print in this order' });
    }

    // -- Create fulfillment log entry (pending) --
    fulfillmentLog.createEntry(shopifyOrderId, {
      orderNumber: orderData.orderNumber,
      artifactId: orderData.artifactId || null,
      productId: orderData.productId,
    });

    // -- Resolve product config from catalog --
    // Use findByShopifyIdAll to include inactive products (orders may reference them)
    const product = productConfig.findByShopifyIdAll(orderData.shopifyProductId)
      || productConfig.findProduct(orderData.productId)
      || null;

    console.log(`[Webhook] Processing bracket print for order ${orderData.orderNumber}`);
    console.log(`[Webhook] Bracket ID: ${orderData.bracketId}`);
    console.log(`[Webhook] Artifact ID: ${orderData.artifactId || 'NONE — will regenerate'}`);
    console.log(`[Webhook] Product: ${product ? `${product.shortTitle} (${product.internalId})` : 'UNKNOWN — using defaults'}`);
    console.log(`[Webhook] Shopify Product ID: ${orderData.shopifyProductId || 'N/A'}`);
    console.log(`[Webhook] Color modes: ${config.colorModes.join(', ')}`);

    // -- Step 4: Load artifacts or regenerate --
    let svgPath, printReadyRgbPath, printReadyCmykPath;

    const artifactPaths = orderData.artifactId
      ? artifactStore.getArtifactPaths(orderData.artifactId)
      : null;

    if (artifactPaths && artifactPaths.svgPath && artifactPaths.printReadyRgbPath) {
      // Use pre-generated artifacts
      console.log(`[Webhook] Loading artifacts from store: ${orderData.artifactId}`);
      svgPath = artifactPaths.svgPath;
      printReadyRgbPath = artifactPaths.printReadyRgbPath;
      printReadyCmykPath = artifactPaths.printReadyCmykPath;
    } else {
      // Fallback: regenerate files
      if (orderData.artifactId) {
        console.warn(`[Webhook] Artifact ${orderData.artifactId} not found or incomplete — regenerating`);
      }

      const svgString = await getBracketSvg(orderData);
      svgPath = path.join(__dirname, '..', '..', 'output', 'svgs', `bracket_${orderData.orderNumber}.svg`);
      fs.writeFileSync(svgPath, svgString);
      console.log(`[Webhook] SVG saved: bracket_${orderData.orderNumber}.svg`);

      const printReady = await generatePrintReady(
        svgString,
        `print_ready_rgb_${orderData.orderNumber}`
      );
      printReadyRgbPath = printReady.rgbPath;
      printReadyCmykPath = printReady.cmykPath;
    }

    // -- Step 5: Generate packing slip PDF --
    const packingSlipPath = await generatePackingSlip({
      orderNumber: orderData.orderNumber,
      customerName: orderData.customerName,
      address: orderData.address,
      city: orderData.city,
      state: orderData.state,
      zip: orderData.zip,
      email: orderData.email,
      phone: orderData.phone,
      productTitle: orderData.productTitle,
      color: orderData.color,
      size: orderData.size,
      bracketTitle: orderData.bracketTitle,
      teamCount: orderData.teamCount,
      championName: orderData.championName,
      printStyle: orderData.printStyle,
      createdAt: order.created_at,
      productType: product ? product.productType : 'hoodie',
      shopifyProductId: orderData.shopifyProductId,
      shopifyVariantId: orderData.shopifyVariantId,
      printWidthInches: product ? product.printWidthInches : 12,
      garmentModel: product ? product.shortTitle : orderData.productTitle,
    });
    console.log(`[Webhook] Packing slip: packing_slip_${orderData.orderNumber}.pdf`);

    // Store packing slip in artifact if available
    if (orderData.artifactId) {
      artifactStore.addPackingSlip(orderData.artifactId, packingSlipPath);
    }

    // -- Step 6: Deliver to printer (email + optional folder/sftp) --
    const emailParams = {
      orderNumber: orderData.orderNumber,
      customerName: orderData.customerName,
      productTitle: orderData.productTitle,
      color: orderData.color,
      size: orderData.size,
      bracketTitle: orderData.bracketTitle,
      teamCount: orderData.teamCount,
      championName: orderData.championName,
      printStyle: orderData.printStyle,
      svgPath,
      printReadyRgbPath,
      printReadyCmykPath,
      packingSlipPath,
      productType: product ? product.productType : 'hoodie',
      shopifyProductId: orderData.shopifyProductId,
      printWidthInches: product ? product.printWidthInches : 12,
      garmentModel: product ? product.shortTitle : orderData.productTitle,
    };

    const filePaths = {
      svg: svgPath,
      rgb: printReadyRgbPath,
      cmyk: printReadyCmykPath,
      packingSlip: packingSlipPath,
    };

    const deliveryResults = await deliverPrintFiles(emailParams, filePaths);

    // Check if any delivery succeeded
    const anySuccess = deliveryResults.some(r => r.success);

    // -- Step 7: Update fulfillment log --
    const fileManifest = {
      svg: svgPath ? path.basename(svgPath) : null,
      rgb_png: printReadyRgbPath ? path.basename(printReadyRgbPath) : null,
      cmyk_pdf: printReadyCmykPath ? path.basename(printReadyCmykPath) : null,
      packing_slip: `packing_slip_${orderData.orderNumber}.pdf`,
    };

    if (anySuccess) {
      const emailResult = deliveryResults.find(r => r.method === 'email') || {};
      fulfillmentLog.markSent(shopifyOrderId, fileManifest, emailResult);
    } else {
      const errors = deliveryResults.map(r => `${r.method}: ${r.error || 'unknown'}`).join('; ');
      fulfillmentLog.markFailed(shopifyOrderId, errors);
    }

    console.log(`[FULFILLMENT] orderId=${shopifyOrderId} orderNumber=${orderData.orderNumber} status=${anySuccess ? 'sent' : 'failed'} artifactId=${orderData.artifactId || 'regenerated'} delivery=${deliveryResults.map(r => `${r.method}:${r.success}`).join(',')}`);

    // -- Build response --
    const responsePayload = {
      status: anySuccess ? 'ok' : 'delivery_failed',
      orderNumber: orderData.orderNumber,
      artifactId: orderData.artifactId || null,
      colorModes: config.colorModes,
      files: fileManifest,
      delivery: deliveryResults.map(r => ({ method: r.method, success: r.success })),
    };

    if (product) {
      responsePayload.product = {
        internalId: product.internalId,
        shopifyProductId: product.shopifyProductId,
        title: product.shortTitle,
        productType: product.productType,
      };
    }

    res.status(200).json(responsePayload);

  } catch (err) {
    console.error('[Webhook] Error processing order:', err);

    // Try to log failure
    try {
      const order = JSON.parse(req.body.toString());
      const shopifyOrderId = String(order.id || order.name || '');
      if (shopifyOrderId) {
        fulfillmentLog.markFailed(shopifyOrderId, err.message);
      }
    } catch { /* best effort */ }

    // Always return 200 to Shopify to prevent retries on our errors
    res.status(200).json({ status: 'error', message: err.message });
  }
});

/* ──────────────────────────────────────────────────────────
 * POST /webhooks/shopify/test   (ADMIN_TOKEN protected)
 *
 * Accepts a JSON body that mimics a Shopify orders/paid payload
 * and runs the *full* processing pipeline (artifact load / regenerate,
 * packing slip, printer delivery) — without requiring a real Shopify
 * webhook or HMAC signature.
 *
 * Use for:
 *   • End-to-end smoke tests before going live
 *   • Verifying printer delivery works with real SMTP / SFTP / folder
 *   • Testing artifact lookup and packing-slip generation
 *
 * Body (JSON): Same shape as Shopify order — or a minimal subset:
 *   {
 *     "id": 99990001,
 *     "name": "#TEST-001",
 *     "email": "test@example.com",
 *     "shipping_address": { "first_name":"Test","last_name":"User", ... },
 *     "line_items": [{
 *       "title": "Grid Iron Hoodie",
 *       "product_id": 9208241586344,
 *       "variant_id": 48123456789000,
 *       "properties": [
 *         { "name":"bracket_id","value":"test-bracket-001" },
 *         { "name":"artifact_id","value":"<existing artifactId>" },
 *         ...
 *       ]
 *     }]
 *   }
 * ────────────────────────────────────────────────────────── */
router.post('/shopify/test', requireAdminToken, express.json({ limit: '5mb' }), async (req, res) => {
  try {
    const order = req.body;
    const shopifyOrderId = `test-${String(order.id || order.name || Date.now())}`;

    console.log(`[FULFILLMENT] test orderId=${shopifyOrderId} status=started`);

    // -- Extract order details (reuse the same helper) --
    const orderData = extractOrderData(order);

    if (!orderData.bracketId) {
      return res.status(400).json({
        error: 'Test payload must include a line_item with bracket_id property',
        hint: 'Add properties: [{ "name":"bracket_id", "value":"test-bracket-001" }]',
      });
    }

    // -- Create fulfillment log entry (pending) --
    fulfillmentLog.createEntry(shopifyOrderId, {
      orderNumber: orderData.orderNumber || `#TEST-${Date.now()}`,
      artifactId: orderData.artifactId || null,
      productId: orderData.productId,
    });

    // -- Resolve product config --
    const product = productConfig.findByShopifyIdAll(orderData.shopifyProductId)
      || productConfig.findProduct(orderData.productId)
      || null;

    // -- Load artifacts or regenerate --
    let svgPath, printReadyRgbPath, printReadyCmykPath;

    const artifactPaths = orderData.artifactId
      ? artifactStore.getArtifactPaths(orderData.artifactId)
      : null;

    if (artifactPaths && artifactPaths.svgPath && artifactPaths.printReadyRgbPath) {
      svgPath = artifactPaths.svgPath;
      printReadyRgbPath = artifactPaths.printReadyRgbPath;
      printReadyCmykPath = artifactPaths.printReadyCmykPath;
    } else {
      const svgString = await getBracketSvg(orderData);
      svgPath = path.join(__dirname, '..', '..', 'output', 'svgs', `bracket_${orderData.orderNumber || 'test'}.svg`);
      fs.writeFileSync(svgPath, svgString);

      const printReady = await generatePrintReady(
        svgString,
        `print_ready_rgb_test_${Date.now()}`
      );
      printReadyRgbPath = printReady.rgbPath;
      printReadyCmykPath = printReady.cmykPath;
    }

    // -- Generate packing slip --
    const packingSlipPath = await generatePackingSlip({
      orderNumber: orderData.orderNumber || `#TEST-${Date.now()}`,
      customerName: orderData.customerName || 'Test Customer',
      address: orderData.address || '123 Test St',
      city: orderData.city || 'Testville',
      state: orderData.state || 'TX',
      zip: orderData.zip || '75001',
      email: orderData.email || 'test@example.com',
      phone: orderData.phone || '',
      productTitle: orderData.productTitle || 'Test Product',
      color: orderData.color || 'Black',
      size: orderData.size || 'L',
      bracketTitle: orderData.bracketTitle,
      teamCount: orderData.teamCount,
      championName: orderData.championName,
      printStyle: orderData.printStyle,
      createdAt: new Date().toISOString(),
      productType: product ? product.productType : 'hoodie',
      shopifyProductId: orderData.shopifyProductId,
      shopifyVariantId: orderData.shopifyVariantId,
      printWidthInches: product ? product.printWidthInches : 12,
      garmentModel: product ? product.shortTitle : orderData.productTitle,
    });

    if (orderData.artifactId) {
      artifactStore.addPackingSlip(orderData.artifactId, packingSlipPath);
    }

    // -- Deliver to printer --
    const emailParams = {
      orderNumber: orderData.orderNumber || `#TEST-${Date.now()}`,
      customerName: orderData.customerName || 'Test Customer',
      productTitle: orderData.productTitle || 'Test Product',
      color: orderData.color || 'Black',
      size: orderData.size || 'L',
      bracketTitle: orderData.bracketTitle,
      teamCount: orderData.teamCount,
      championName: orderData.championName,
      printStyle: orderData.printStyle,
      svgPath,
      printReadyRgbPath,
      printReadyCmykPath,
      packingSlipPath,
      productType: product ? product.productType : 'hoodie',
      shopifyProductId: orderData.shopifyProductId,
      printWidthInches: product ? product.printWidthInches : 12,
      garmentModel: product ? product.shortTitle : orderData.productTitle,
    };

    const filePaths = {
      svg: svgPath,
      rgb: printReadyRgbPath,
      cmyk: printReadyCmykPath,
      packingSlip: packingSlipPath,
    };

    const deliveryResults = await deliverPrintFiles(emailParams, filePaths);
    const anySuccess = deliveryResults.some(r => r.success);

    // -- Update fulfillment log --
    const fileManifest = {
      svg: svgPath ? path.basename(svgPath) : null,
      rgb_png: printReadyRgbPath ? path.basename(printReadyRgbPath) : null,
      cmyk_pdf: printReadyCmykPath ? path.basename(printReadyCmykPath) : null,
      packing_slip: packingSlipPath ? path.basename(packingSlipPath) : null,
    };

    if (anySuccess) {
      const emailResult = deliveryResults.find(r => r.method === 'email') || {};
      fulfillmentLog.markSent(shopifyOrderId, fileManifest, emailResult);
    } else {
      const errors = deliveryResults.map(r => `${r.method}: ${r.error || 'unknown'}`).join('; ');
      fulfillmentLog.markFailed(shopifyOrderId, errors);
    }

    console.log(`[FULFILLMENT] test orderId=${shopifyOrderId} status=${anySuccess ? 'sent' : 'failed'}`);

    res.json({
      status: anySuccess ? 'ok' : 'delivery_failed',
      testMode: true,
      shopifyOrderId,
      orderNumber: orderData.orderNumber,
      artifactId: orderData.artifactId || null,
      files: fileManifest,
      delivery: deliveryResults.map(r => ({ method: r.method, success: r.success, error: r.error || null })),
      product: product ? {
        internalId: product.internalId,
        shopifyProductId: product.shopifyProductId,
        title: product.shortTitle,
        productType: product.productType,
      } : null,
    });

  } catch (err) {
    console.error('[Webhook:test] Error:', err.message);
    res.status(500).json({ error: 'Test pipeline failed', details: err.message });
  }
});

/* ──────────────────────────────────────────────────────────
 * extractOrderData()
 *   Pull bracket print data from Shopify order payload.
 * ────────────────────────────────────────────────────────── */
function extractOrderData(order) {
  const data = {
    orderNumber: order.name || `#${order.order_number || order.id}`,
    customerName: '',
    address: '',
    city: '',
    state: '',
    zip: '',
    email: order.email || '',
    phone: '',
    productTitle: '',
    color: '',
    size: '',
    // Shopify identifiers (from line item)
    shopifyProductId: null,
    shopifyVariantId: null,
    productId: null,
    // Artifact ID (from line-item properties, set at checkout)
    artifactId: null,
    // Bracket data
    bracketId: null,
    bracketTitle: 'TOURNAMENT',
    championName: 'TBD',
    teamCount: 16,
    teams: [],
    picks: {},
    printStyle: 'classic',
    palette: 'light',
  };

  // Customer + shipping
  const shipping = order.shipping_address || order.billing_address || {};
  data.customerName = `${shipping.first_name || ''} ${shipping.last_name || ''}`.trim();
  data.address = shipping.address1 || '';
  data.city = shipping.city || '';
  data.state = shipping.province_code || shipping.province || '';
  data.zip = shipping.zip || '';
  data.phone = shipping.phone || order.phone || '';

  // Line items -- find the one with bracket_id
  const lineItems = order.line_items || [];
  for (const item of lineItems) {
    const props = {};
    (item.properties || []).forEach(p => {
      props[p.name] = p.value;
    });

    if (props.bracket_id) {
      data.bracketId = props.bracket_id;
      data.productTitle = item.title || item.name || '';
      data.color = props.color || '';
      data.size = props.size || item.variant_title || '';
      data.bracketTitle = props.bracket_title || 'TOURNAMENT';
      data.championName = props.champion_name || 'TBD';
      data.teamCount = parseInt(props.team_count || '16', 10);
      data.printStyle = props.print_style || 'classic';
      data.palette = props.palette || 'light';

      // Shopify native product/variant IDs
      data.shopifyProductId = item.product_id ? String(item.product_id) : null;
      data.shopifyVariantId = item.variant_id ? String(item.variant_id) : null;

      // Internal BMB product ID (from line-item property)
      data.productId = props.product_id || null;

      // Artifact ID (from line-item property, set at checkout)
      data.artifactId = props.artifact_id || null;

      // Preview URL (for reference/logging)
      data.previewUrl = props.preview_url || null;

      try { data.teams = JSON.parse(props.teams || '[]'); } catch { data.teams = []; }
      try { data.picks = JSON.parse(props.picks || '{}'); } catch { data.picks = {}; }

      break;
    }
  }

  return data;
}

/* ──────────────────────────────────────────────────────────
 * getBracketSvg()
 *   Check for saved SVG first, regenerate if not found.
 * ────────────────────────────────────────────────────────── */
async function getBracketSvg(orderData) {
  const savedPath = path.join(__dirname, '..', '..', 'output', 'svgs', `bracket_${orderData.bracketId}.svg`);
  if (fs.existsSync(savedPath)) {
    console.log(`[Webhook] Found saved SVG for bracket ${orderData.bracketId}`);
    return fs.readFileSync(savedPath, 'utf8');
  }

  console.log(`[Webhook] Regenerating SVG for bracket ${orderData.bracketId}`);
  return generateBracketSvg({
    bracketTitle: orderData.bracketTitle,
    championName: orderData.championName,
    teamCount: orderData.teamCount,
    teams: orderData.teams,
    picks: orderData.picks,
    style: orderData.printStyle,
    palette: orderData.palette,
  });
}

module.exports = router;
