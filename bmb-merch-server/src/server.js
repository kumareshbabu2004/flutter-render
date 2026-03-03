/**
 * BMB Merch Server v3.1.0
 * ───────────────────────
 * POST /generate-preview              → bracket JSON in, preview.jpg + artifactId out
 * GET  /preview/:id                   → retrieve saved preview JPEG
 * GET  /products                      → active product catalog (?includeInactive=true for all)
 * POST /webhooks/shopify              → Shopify orders/paid → printer delivery
 * POST /webhooks/shopify/test         → ADMIN_TOKEN: full pipeline test without Shopify
 * GET  /fulfillment/:orderId          → fulfillment status + file manifest
 * PATCH /admin/products/:id           → toggle isActive (ADMIN_TOKEN required)
 * GET  /admin/products                → all products (active + inactive)
 * GET  /admin/fulfillment             → list fulfillment entries by status
 * POST /admin/send-to-printer         → ADMIN_TOKEN: deliver artifact to printer
 * GET  /admin/logs/summary            → ADMIN_TOKEN: last 20 events + recent failures
 * GET  /health                        → 200 OK
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const config = require('./config');
const previewRoutes = require('./routes/preview');
const webhookRoutes = require('./routes/webhook');
const adminRoutes = require('./routes/admin');
const fulfillmentRoutes = require('./routes/fulfillment');
const { getDeliveryConfig } = require('./services/printer-delivery');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Middleware ───────────────────────────────────────────
app.use(cors());

// Raw body for Shopify HMAC verification on the REAL webhook only.
// The /test sub-route needs parsed JSON, so we scope raw() to /webhooks/shopify exactly.
app.use('/webhooks/shopify', (req, res, next) => {
  // Only apply raw body parsing to the exact POST /webhooks/shopify route (not /test)
  if (req.path === '/' || req.path === '') {
    return express.raw({ type: 'application/json' })(req, res, next);
  }
  next();
});

// JSON parser for all other routes (including /webhooks/shopify/test)
app.use(express.json({ limit: '5mb' }));

// Serve generated previews as static files.
// PRODUCTION SAFETY: disable directory listing — artifact URLs are unguessable
// (16-char hex IDs from crypto.randomBytes).  Only exact file paths are served.
app.use('/output', express.static(path.join(__dirname, '..', 'output'), {
  dotfiles: 'deny',     // block hidden files
  index: false,          // disable directory listing / index.html
  extensions: false,     // require full filename with extension
}));

// ── Routes ──────────────────────────────────────────────
app.use('/', previewRoutes);
app.use('/webhooks', webhookRoutes);
app.use('/admin', adminRoutes);
app.use('/fulfillment', fulfillmentRoutes);

// ── Health check ────────────────────────────────────────
app.get('/health', (req, res) => {
  const delivery = getDeliveryConfig();

  res.json({
    status: 'ok',
    service: 'bmb-merch-server',
    version: '3.1.0',
    uptime: process.uptime(),
    colorModes: config.colorModes,
    rgb: config.rgbEnabled,
    cmyk: config.cmykEnabled,
    printerDelivery: delivery.methods,
    adminEnabled: !!config.adminToken,
  });
});

// ── Ensure output directories exist ─────────────────────
const dirs = [
  'output/previews',
  'output/print_ready',
  'output/print_ready_cmyk',
  'output/packing_slips',
  'output/svgs',
  'output/artifacts',
];
dirs.forEach(d => {
  const dirPath = path.join(__dirname, '..', d);
  if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath, { recursive: true });
});

// Ensure printer_dropbox exists if folder delivery is configured
if (config.printerDelivery.includes('folder')) {
  const dropbox = config.printerDropboxDir
    || path.join(__dirname, '..', 'printer_dropbox');
  if (!fs.existsSync(dropbox)) {
    fs.mkdirSync(dropbox, { recursive: true });
    console.log(`[Server] Created printer dropbox: ${dropbox}`);
  }
}

// ── Start ───────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  const delivery = getDeliveryConfig();

  console.log(`\n  BMB Merch Server v3.1.0 listening on port ${PORT}`);
  console.log(`  Health:          http://localhost:${PORT}/health`);
  console.log(`  Preview:         POST http://localhost:${PORT}/generate-preview`);
  console.log(`  Products:        GET  http://localhost:${PORT}/products`);
  console.log(`  Fulfillment:     GET  http://localhost:${PORT}/fulfillment/:orderId`);
  console.log(`  Webhook:         POST http://localhost:${PORT}/webhooks/shopify`);
  console.log(`  Webhook (test):  POST http://localhost:${PORT}/webhooks/shopify/test`);
  console.log(`  Admin products:  PATCH http://localhost:${PORT}/admin/products/:id`);
  console.log(`  Admin fulfillment: GET http://localhost:${PORT}/admin/fulfillment`);
  console.log(`  Admin printer:   POST http://localhost:${PORT}/admin/send-to-printer`);
  console.log(`  Admin logs:      GET  http://localhost:${PORT}/admin/logs/summary`);
  console.log(`  Color modes:     ${config.colorModes.join(', ')}`);
  console.log(`  RGB: ${config.rgbEnabled ? 'ON' : 'OFF'}  |  CMYK: ${config.cmykEnabled ? 'ON' : 'OFF'}`);
  console.log(`  Delivery:        ${delivery.methods.join(', ')}`);
  console.log(`  Admin token:     ${config.adminToken ? 'CONFIGURED' : 'NOT SET (admin endpoints disabled)'}`);
  console.log(`  Output dir:      directory listing DISABLED (unguessable URLs only)\n`);
});

module.exports = app;
