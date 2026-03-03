/**
 * Fulfillment Status Routes
 * ─────────────────────────
 * Public endpoint for checking order fulfillment status.
 *
 * GET /fulfillment/:shopifyOrderId
 *   → { status, timestamps, fileManifest }
 */

const express = require('express');
const router = express.Router();
const fulfillmentLog = require('../services/fulfillment-log');

/* ──────────────────────────────────────────────────────────
 * GET /fulfillment/:shopifyOrderId
 *   Returns fulfillment status for a given order.
 * ────────────────────────────────────────────────────────── */
router.get('/:shopifyOrderId', (req, res) => {
  const { shopifyOrderId } = req.params;
  const entry = fulfillmentLog.getEntry(shopifyOrderId);

  if (!entry) {
    return res.status(404).json({
      error: 'Fulfillment record not found',
      shopifyOrderId,
    });
  }

  res.json({
    shopifyOrderId: entry.shopifyOrderId,
    orderNumber: entry.orderNumber,
    status: entry.status,
    artifactId: entry.artifactId || null,
    timestamps: {
      createdAt: entry.createdAt,
      processedAt: entry.processedAt || null,
      lastAttemptAt: entry.lastAttemptAt || null,
    },
    attempts: entry.attempts || 0,
    lastError: entry.lastError || null,
    files: entry.files || {},
  });
});

module.exports = router;
