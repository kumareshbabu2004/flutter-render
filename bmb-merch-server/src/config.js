/**
 * Server Configuration
 * ────────────────────
 * Central config parsed from environment variables.
 * Provides OUTPUT_COLOR_MODES to toggle RGB / CMYK outputs
 * without code changes.
 */

require('dotenv').config();

/**
 * OUTPUT_COLOR_MODES
 * ──────────────────
 * Controls which print-ready color modes are generated and emailed.
 *
 * Env var:  OUTPUT_COLOR_MODES=RGB,CMYK   (comma-separated)
 * Default:  ["RGB", "CMYK"]               (both enabled)
 *
 * To disable CMYK:  OUTPUT_COLOR_MODES=RGB
 * To disable RGB:   OUTPUT_COLOR_MODES=CMYK   (unusual, but supported)
 */
function parseColorModes() {
  const raw = process.env.OUTPUT_COLOR_MODES || 'RGB,CMYK';
  const modes = raw.split(',').map(m => m.trim().toUpperCase()).filter(Boolean);

  // Validate
  const valid = modes.filter(m => ['RGB', 'CMYK'].includes(m));
  if (valid.length === 0) {
    console.warn('[Config] No valid OUTPUT_COLOR_MODES found, defaulting to ["RGB","CMYK"]');
    return ['RGB', 'CMYK'];
  }
  return valid;
}

const config = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',

  // ── Output modes ──
  colorModes: parseColorModes(),
  get rgbEnabled()  { return this.colorModes.includes('RGB'); },
  get cmykEnabled() { return this.colorModes.includes('CMYK'); },

  // ── Shopify ──
  shopifyStoreDomain: process.env.SHOPIFY_STORE_DOMAIN || '',
  shopifyAdminToken: process.env.SHOPIFY_ADMIN_TOKEN || '',
  shopifyWebhookSecret: process.env.SHOPIFY_WEBHOOK_SECRET || '',

  // ── Email ──
  smtpHost: process.env.SMTP_HOST || '',
  smtpPort: parseInt(process.env.SMTP_PORT || '587', 10),
  smtpUser: process.env.SMTP_USER || '',
  smtpPass: process.env.SMTP_PASS || '',
  printerEmail: process.env.PRINTER_EMAIL || 'jkim@aceusainc.com',
  ccEmails: process.env.CC_EMAILS || 'ahmad@backmybracket.com,amchi81@gmail.com',

  // ── Admin ──
  adminToken: process.env.ADMIN_TOKEN || '',

  // ── Printer Delivery ──
  // PRINTER_DELIVERY=email|folder|sftp (comma-separated for multiple)
  printerDelivery: process.env.PRINTER_DELIVERY || 'email',

  // ── SFTP (optional, for sftp delivery method) ──
  sftpHost: process.env.SFTP_HOST || '',
  sftpPort: parseInt(process.env.SFTP_PORT || '22', 10),
  sftpUser: process.env.SFTP_USER || '',
  sftpPass: process.env.SFTP_PASS || '',
  sftpRemoteDir: process.env.SFTP_REMOTE_DIR || '/uploads',

  // ── Printer Dropbox (optional, for folder delivery method) ──
  printerDropboxDir: process.env.PRINTER_DROPBOX_DIR || '',

  // ── Email Retry ──
  emailMaxRetries: parseInt(process.env.EMAIL_MAX_RETRIES || '3', 10),
  emailRetryBaseMs: parseInt(process.env.EMAIL_RETRY_BASE_MS || '2000', 10),
};

module.exports = config;
