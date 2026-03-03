/**
 * Fulfillment Log
 * ───────────────
 * JSON-file-based persistence for order fulfillment tracking.
 *
 * Provides:
 *   - Idempotency: prevents duplicate fulfillment emails per shopifyOrderId
 *   - Status tracking: pending → sent → failed
 *   - Timestamps: createdAt, processedAt, lastAttemptAt
 *   - File manifest: list of generated files per order
 *   - Query: by status (for admin retry dashboard)
 *
 * Storage: data/fulfillment_log.json
 *   {
 *     "<shopifyOrderId>": {
 *       status: "pending" | "sent" | "failed",
 *       orderNumber: "#1234",
 *       artifactId: "abc123...",
 *       attempts: 0,
 *       lastError: null,
 *       createdAt: ISO,
 *       processedAt: ISO | null,
 *       lastAttemptAt: ISO | null,
 *       files: { svg: "...", rgb_png: "...", cmyk_pdf: "...", packing_slip: "..." }
 *     }
 *   }
 *
 * Minimal persistence — no external DB for fast launch.
 */

const path = require('path');
const fs = require('fs');

const LOG_PATH = path.join(__dirname, '..', 'data', 'fulfillment_log.json');

// ── In-memory cache (loaded from disk at startup) ──
let _log = {};

/**
 * Load the fulfillment log from disk.
 * Called once at startup.
 */
function loadLog() {
  if (fs.existsSync(LOG_PATH)) {
    try {
      _log = JSON.parse(fs.readFileSync(LOG_PATH, 'utf8'));
      console.log(`[FulfillmentLog] Loaded ${Object.keys(_log).length} entries`);
    } catch (err) {
      console.error(`[FulfillmentLog] Failed to parse log: ${err.message}`);
      _log = {};
    }
  } else {
    _log = {};
    _saveLog();
    console.log('[FulfillmentLog] Created new log file');
  }
}

/**
 * Persist the in-memory log to disk.
 * @private
 */
function _saveLog() {
  const dir = path.dirname(LOG_PATH);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(LOG_PATH, JSON.stringify(_log, null, 2));
}

// Auto-load on require
loadLog();

/* ──────────────────────────────────────────────────────────
 * Public API
 * ────────────────────────────────────────────────────────── */

/**
 * Check if an order has already been processed (idempotency gate).
 *
 * @param {string} shopifyOrderId - Shopify order ID (numeric string or name)
 * @returns {{ alreadyProcessed: boolean, entry: Object|null }}
 */
function checkIdempotency(shopifyOrderId) {
  const key = String(shopifyOrderId);
  const entry = _log[key] || null;

  if (entry && entry.status === 'sent') {
    return { alreadyProcessed: true, entry };
  }
  return { alreadyProcessed: false, entry };
}

/**
 * Create or update a fulfillment entry as "pending".
 *
 * @param {string} shopifyOrderId
 * @param {Object} meta - { orderNumber, artifactId, productId, ... }
 * @returns {Object} The entry
 */
function createEntry(shopifyOrderId, meta = {}) {
  const key = String(shopifyOrderId);
  const existing = _log[key];

  _log[key] = {
    status: 'pending',
    shopifyOrderId: key,
    orderNumber: meta.orderNumber || existing?.orderNumber || key,
    artifactId: meta.artifactId || existing?.artifactId || null,
    productId: meta.productId || existing?.productId || null,
    attempts: existing?.attempts || 0,
    lastError: null,
    createdAt: existing?.createdAt || new Date().toISOString(),
    processedAt: null,
    lastAttemptAt: null,
    files: existing?.files || {},
    ...meta,
  };
  _saveLog();
  return _log[key];
}

/**
 * Mark an order as successfully sent.
 *
 * @param {string} shopifyOrderId
 * @param {Object} fileManifest - { svg, rgb_png, cmyk_pdf, packing_slip }
 * @param {Object} emailResult  - { messageId, attachmentCount }
 */
function markSent(shopifyOrderId, fileManifest = {}, emailResult = {}) {
  const key = String(shopifyOrderId);
  if (!_log[key]) {
    _log[key] = { shopifyOrderId: key, createdAt: new Date().toISOString() };
  }

  _log[key].status = 'sent';
  _log[key].processedAt = new Date().toISOString();
  _log[key].lastAttemptAt = new Date().toISOString();
  _log[key].attempts = (_log[key].attempts || 0) + 1;
  _log[key].files = fileManifest;
  _log[key].emailResult = emailResult;
  _log[key].lastError = null;

  _saveLog();
  console.log(`[FulfillmentLog] Order ${key} marked SENT (attempt ${_log[key].attempts})`);
}

/**
 * Mark an order as failed.
 *
 * @param {string} shopifyOrderId
 * @param {string} errorMessage
 */
function markFailed(shopifyOrderId, errorMessage) {
  const key = String(shopifyOrderId);
  if (!_log[key]) {
    _log[key] = { shopifyOrderId: key, createdAt: new Date().toISOString() };
  }

  _log[key].status = 'failed';
  _log[key].lastAttemptAt = new Date().toISOString();
  _log[key].attempts = (_log[key].attempts || 0) + 1;
  _log[key].lastError = errorMessage;

  _saveLog();
  console.log(`[FulfillmentLog] Order ${key} marked FAILED (attempt ${_log[key].attempts}): ${errorMessage}`);
}

/**
 * Get a single fulfillment entry.
 *
 * @param {string} shopifyOrderId
 * @returns {Object|null}
 */
function getEntry(shopifyOrderId) {
  return _log[String(shopifyOrderId)] || null;
}

/**
 * Query entries by status.
 *
 * @param {string} status - "pending" | "sent" | "failed"
 * @returns {Object[]} Array of entries matching the status
 */
function queryByStatus(status) {
  return Object.values(_log)
    .filter(e => e.status === status)
    .sort((a, b) => new Date(b.lastAttemptAt || b.createdAt) - new Date(a.lastAttemptAt || a.createdAt));
}

/**
 * Get all entries (for admin/debugging).
 * @returns {Object} The full log
 */
function getAllEntries() {
  return { ..._log };
}

/**
 * Reload log from disk (useful after external edits).
 */
function reloadLog() {
  loadLog();
}

module.exports = {
  checkIdempotency,
  createEntry,
  markSent,
  markFailed,
  getEntry,
  queryByStatus,
  getAllEntries,
  reloadLog,
};
