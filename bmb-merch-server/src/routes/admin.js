/**
 * Admin Routes
 * ────────────
 * Protected by ADMIN_TOKEN header.
 * No Shopify catalog modifications — admin only manages local config.
 *
 * Endpoints:
 *   PATCH /admin/products/:internalId  → toggle isActive
 *   GET   /admin/products              → list all products (active + inactive)
 *   GET   /admin/fulfillment           → list fulfillment entries by status
 *   POST  /admin/send-to-printer       → trigger real printer delivery with artifactId
 *   GET   /admin/logs/summary          → last 20 events, recent failures, delivery config
 */

const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const config = require('../config');
const productConfig = require('../services/product-config');
const fulfillmentLog = require('../services/fulfillment-log');
const artifactStore = require('../services/artifact-store');
const { generatePackingSlip } = require('../services/packing-slip');
const { deliverPrintFiles, getDeliveryConfig } = require('../services/printer-delivery');

/* ──────────────────────────────────────────────────────────
 * Admin Token Middleware
 * ────────────────────────────────────────────────────────── */
function requireAdminToken(req, res, next) {
  const token = req.headers['x-admin-token'] || req.query.admin_token;

  if (!config.adminToken) {
    return res.status(503).json({
      error: 'Admin endpoint not configured',
      hint: 'Set ADMIN_TOKEN environment variable to enable admin access',
    });
  }

  if (!token || token !== config.adminToken) {
    return res.status(401).json({ error: 'Invalid or missing admin token' });
  }

  next();
}

// Apply admin token middleware to all routes in this router
router.use(requireAdminToken);

/* ──────────────────────────────────────────────────────────
 * PATCH /admin/products/:internalId
 *   Toggle isActive for a product without redeploy.
 *
 * Body (JSON):
 *   { "isActive": true|false }
 *
 * This does NOT modify the Shopify catalog.
 * It only updates the local product-catalog.json file.
 * ────────────────────────────────────────────────────────── */
router.patch('/products/:internalId', (req, res) => {
  const { internalId } = req.params;
  const { isActive } = req.body;

  if (typeof isActive !== 'boolean') {
    return res.status(400).json({
      error: 'isActive must be a boolean (true or false)',
      example: { isActive: false },
    });
  }

  const result = productConfig.toggleActive(internalId, isActive);

  if (!result.success) {
    return res.status(404).json({ error: result.error });
  }

  res.json({
    status: 'ok',
    message: `Product ${internalId} is now ${isActive ? 'ACTIVE' : 'INACTIVE'}`,
    product: result.product,
    _note: 'Shopify catalog was NOT modified. Only local product config updated.',
  });
});

/* ──────────────────────────────────────────────────────────
 * GET /admin/products
 *   List all products including inactive ones.
 * ────────────────────────────────────────────────────────── */
router.get('/products', (req, res) => {
  const products = productConfig.getAllProductsIncludingInactive().map(p => ({
    internalId: p.internalId,
    shopifyProductId: p.shopifyProductId,
    title: p.shortTitle,
    productType: p.productType,
    isActive: p.isActive,
    discontinuedAt: p.discontinuedAt || null,
    supportedVariants: p.supportedVariants || [],
    basePrice: p.basePrice,
    printUpcharge: p.printUpcharge,
  }));

  const active = products.filter(p => p.isActive).length;
  const inactive = products.filter(p => !p.isActive).length;

  res.json({ products, count: products.length, active, inactive });
});

/* ──────────────────────────────────────────────────────────
 * GET /admin/fulfillment?status=failed
 *   List fulfillment entries, optionally filtered by status.
 *
 * Query params:
 *   status — "pending" | "sent" | "failed" (optional)
 * ────────────────────────────────────────────────────────── */
router.get('/fulfillment', (req, res) => {
  const { status } = req.query;

  if (status && ['pending', 'sent', 'failed'].includes(status)) {
    const entries = fulfillmentLog.queryByStatus(status);
    return res.json({ status, entries, count: entries.length });
  }

  // Return all
  const all = fulfillmentLog.getAllEntries();
  const entries = Object.values(all);
  const byStatus = {
    pending: entries.filter(e => e.status === 'pending').length,
    sent: entries.filter(e => e.status === 'sent').length,
    failed: entries.filter(e => e.status === 'failed').length,
  };

  res.json({ entries, count: entries.length, byStatus });
});

/* ──────────────────────────────────────────────────────────
 * POST /admin/send-to-printer
 *   Trigger real printer delivery for an existing artifact.
 *   Generates a packing slip, delivers via PRINTER_DELIVERY,
 *   and logs as "sent-test" in fulfillment_log.
 *
 * Body (JSON):
 *   {
 *     "artifactId": "abc123...",         (required — existing artifact)
 *     "testOrderNumber": "#TEST-ADMIN-001",
 *     "testCustomer": { "name":"Test User","email":"t@t.com",
 *                        "address":"123 Main","city":"Dallas","state":"TX","zip":"75001" },
 *     "testAddress": "123 Main St"       (shorthand — or use testCustomer)
 *   }
 * ────────────────────────────────────────────────────────── */
router.post('/send-to-printer', async (req, res) => {
  const {
    artifactId,
    testOrderNumber,
    testCustomer = {},
  } = req.body;

  if (!artifactId) {
    return res.status(400).json({
      error: 'artifactId is required',
      hint: 'Use an artifactId returned by POST /generate-preview',
    });
  }

  // Load the artifact
  const artifact = artifactStore.loadArtifact(artifactId);
  if (!artifact) {
    return res.status(404).json({ error: `Artifact not found: ${artifactId}` });
  }

  const paths = artifactStore.getArtifactPaths(artifactId);
  if (!paths || !paths.svgPath) {
    return res.status(404).json({ error: `Artifact files missing for: ${artifactId}` });
  }

  const orderNumber = testOrderNumber || `#ADMIN-TEST-${Date.now()}`;
  const shopifyOrderId = `admin-test-${Date.now()}`;
  const meta = artifact.manifest.metadata || {};

  // Resolve product
  const product = productConfig.findProduct(meta.shopifyProductId)
    || productConfig.findProduct(meta.productId)
    || null;

  // Generate packing slip
  const packingSlipPath = await generatePackingSlip({
    orderNumber,
    customerName: testCustomer.name || 'Admin Test',
    address: testCustomer.address || '123 Test St',
    city: testCustomer.city || 'Dallas',
    state: testCustomer.state || 'TX',
    zip: testCustomer.zip || '75001',
    email: testCustomer.email || '',
    phone: testCustomer.phone || '',
    productTitle: product ? product.title : (meta.productId || 'Test Product'),
    color: meta.colorName || 'Black',
    size: testCustomer.size || 'L',
    bracketTitle: meta.bracketTitle || 'TOURNAMENT',
    teamCount: meta.teamCount || 16,
    championName: meta.championName || 'TBD',
    printStyle: meta.style || 'classic',
    createdAt: new Date().toISOString(),
    productType: product ? product.productType : 'hoodie',
    shopifyProductId: meta.shopifyProductId || '',
    shopifyVariantId: meta.shopifyVariantId || '',
    printWidthInches: product ? product.printWidthInches : 12,
    garmentModel: product ? product.shortTitle : (meta.productId || 'Test'),
  });

  artifactStore.addPackingSlip(artifactId, packingSlipPath);

  // Deliver via all configured methods
  const emailParams = {
    orderNumber,
    customerName: testCustomer.name || 'Admin Test',
    productTitle: product ? product.shortTitle : (meta.productId || 'Test Product'),
    color: meta.colorName || 'Black',
    size: testCustomer.size || 'L',
    bracketTitle: meta.bracketTitle || 'TOURNAMENT',
    teamCount: meta.teamCount || 16,
    championName: meta.championName || 'TBD',
    printStyle: meta.style || 'classic',
    svgPath: paths.svgPath,
    printReadyRgbPath: paths.printReadyRgbPath,
    printReadyCmykPath: paths.printReadyCmykPath,
    packingSlipPath,
    productType: product ? product.productType : 'hoodie',
    shopifyProductId: meta.shopifyProductId || '',
    printWidthInches: product ? product.printWidthInches : 12,
    garmentModel: product ? product.shortTitle : (meta.productId || 'Test'),
  };

  const filePaths = {
    svg: paths.svgPath,
    rgb: paths.printReadyRgbPath,
    cmyk: paths.printReadyCmykPath,
    packingSlip: packingSlipPath,
  };

  const deliveryResults = await deliverPrintFiles(emailParams, filePaths);
  const anySuccess = deliveryResults.some(r => r.success);

  // Log in fulfillment log as sent-test
  fulfillmentLog.createEntry(shopifyOrderId, {
    orderNumber,
    artifactId,
    productId: meta.productId || null,
  });

  const fileManifest = {
    svg: paths.svgPath ? path.basename(paths.svgPath) : null,
    rgb_png: paths.printReadyRgbPath ? path.basename(paths.printReadyRgbPath) : null,
    cmyk_pdf: paths.printReadyCmykPath ? path.basename(paths.printReadyCmykPath) : null,
    packing_slip: packingSlipPath ? path.basename(packingSlipPath) : null,
  };

  if (anySuccess) {
    fulfillmentLog.markSent(shopifyOrderId, fileManifest, { source: 'admin-send-to-printer' });
  } else {
    const errors = deliveryResults.map(r => `${r.method}: ${r.error || 'unknown'}`).join('; ');
    fulfillmentLog.markFailed(shopifyOrderId, errors);
  }

  console.log(`[FULFILLMENT] admin-send orderId=${shopifyOrderId} status=${anySuccess ? 'sent' : 'failed'} artifactId=${artifactId}`);

  res.json({
    status: anySuccess ? 'ok' : 'delivery_failed',
    testMode: true,
    shopifyOrderId,
    orderNumber,
    artifactId,
    files: fileManifest,
    delivery: deliveryResults.map(r => ({ method: r.method, success: r.success, error: r.error || null })),
  });
});

/* ──────────────────────────────────────────────────────────
 * GET /admin/logs/summary
 *   Observability endpoint.
 *   Returns:
 *     - last 20 fulfillment events (sorted newest-first)
 *     - failures in the last 24 hours
 *     - active printer delivery methods
 * ────────────────────────────────────────────────────────── */
router.get('/logs/summary', (req, res) => {
  const all = fulfillmentLog.getAllEntries();
  const entries = Object.values(all);

  // Sort by most recent activity
  const sorted = entries
    .slice()
    .sort((a, b) => {
      const ta = new Date(a.lastAttemptAt || a.processedAt || a.createdAt).getTime();
      const tb = new Date(b.lastAttemptAt || b.processedAt || b.createdAt).getTime();
      return tb - ta;
    });

  // Last 20
  const last20 = sorted.slice(0, 20).map(e => ({
    shopifyOrderId: e.shopifyOrderId,
    orderNumber: e.orderNumber,
    status: e.status,
    artifactId: e.artifactId || null,
    attempts: e.attempts || 0,
    lastError: e.lastError || null,
    createdAt: e.createdAt,
    processedAt: e.processedAt || null,
    lastAttemptAt: e.lastAttemptAt || null,
    files: e.files || {},
  }));

  // Failures in last 24h
  const cutoff = Date.now() - 24 * 60 * 60 * 1000;
  const recentFailures = sorted.filter(e => {
    if (e.status !== 'failed') return false;
    const ts = new Date(e.lastAttemptAt || e.createdAt).getTime();
    return ts >= cutoff;
  }).map(e => ({
    shopifyOrderId: e.shopifyOrderId,
    orderNumber: e.orderNumber,
    lastError: e.lastError,
    attempts: e.attempts,
    lastAttemptAt: e.lastAttemptAt,
  }));

  // Active delivery config
  const delivery = getDeliveryConfig();

  // Status breakdown
  const byStatus = {
    pending: entries.filter(e => e.status === 'pending').length,
    sent: entries.filter(e => e.status === 'sent').length,
    failed: entries.filter(e => e.status === 'failed').length,
  };

  res.json({
    summary: {
      totalEntries: entries.length,
      byStatus,
      failuresLast24h: recentFailures.length,
    },
    recentEvents: last20,
    recentFailures,
    printerDelivery: delivery,
  });
});

module.exports = router;
