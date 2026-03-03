/**
 * Printer Delivery Service
 * ────────────────────────
 * Delivers print-ready files to the printer via one or more methods:
 *
 *   email  — Nodemailer SMTP (existing, primary)
 *   folder — Copy files to a local printer_dropbox/ directory
 *   sftp   — Upload files to a remote SFTP server
 *
 * Configuration:
 *   PRINTER_DELIVERY=email           → email only (default)
 *   PRINTER_DELIVERY=email,folder    → email + local folder
 *   PRINTER_DELIVERY=email,sftp      → email + SFTP
 *   PRINTER_DELIVERY=folder          → local folder only (no email)
 *
 * SFTP config (only needed if sftp is in PRINTER_DELIVERY):
 *   SFTP_HOST, SFTP_PORT, SFTP_USER, SFTP_PASS, SFTP_REMOTE_DIR
 *
 * Folder config (only needed if folder is in PRINTER_DELIVERY):
 *   PRINTER_DROPBOX_DIR  (default: ./printer_dropbox)
 */

const path = require('path');
const fs = require('fs');
const { sendPrinterEmail } = require('./email-service');

const DROPBOX_DIR = process.env.PRINTER_DROPBOX_DIR
  || path.join(__dirname, '..', '..', 'printer_dropbox');

/* ──────────────────────────────────────────────────────────
 * Parse PRINTER_DELIVERY env var
 * ────────────────────────────────────────────────────────── */
function parseDeliveryMethods() {
  const raw = process.env.PRINTER_DELIVERY || 'email';
  const methods = raw.split(',').map(m => m.trim().toLowerCase()).filter(Boolean);
  const valid = methods.filter(m => ['email', 'folder', 'sftp'].includes(m));
  if (valid.length === 0) {
    console.warn('[PrinterDelivery] No valid PRINTER_DELIVERY methods, defaulting to ["email"]');
    return ['email'];
  }
  return valid;
}

const deliveryMethods = parseDeliveryMethods();

/* ──────────────────────────────────────────────────────────
 * deliverToFolder()
 *   Copy files to local printer_dropbox/ directory.
 * ────────────────────────────────────────────────────────── */
function deliverToFolder(orderNumber, filePaths) {
  const orderDir = path.join(DROPBOX_DIR, orderNumber.replace(/[^a-zA-Z0-9_#-]/g, '_'));
  if (!fs.existsSync(orderDir)) fs.mkdirSync(orderDir, { recursive: true });

  const copied = [];
  for (const [label, srcPath] of Object.entries(filePaths)) {
    if (srcPath && fs.existsSync(srcPath)) {
      const destPath = path.join(orderDir, path.basename(srcPath));
      fs.copyFileSync(srcPath, destPath);
      copied.push(label);
    }
  }

  console.log(`[PrinterDelivery:folder] Copied ${copied.length} files to ${orderDir}`);
  return { method: 'folder', success: true, dir: orderDir, fileCount: copied.length };
}

/* ──────────────────────────────────────────────────────────
 * deliverViaSftp()
 *   Upload files to SFTP server (optional, behind config flag).
 *   Uses ssh2-sftp-client if installed; otherwise logs a warning.
 * ────────────────────────────────────────────────────────── */
async function deliverViaSftp(orderNumber, filePaths) {
  const host = process.env.SFTP_HOST;
  const port = parseInt(process.env.SFTP_PORT || '22', 10);
  const username = process.env.SFTP_USER;
  const password = process.env.SFTP_PASS;
  const remoteDir = process.env.SFTP_REMOTE_DIR || '/uploads';

  if (!host || !username) {
    console.warn('[PrinterDelivery:sftp] SFTP not configured (missing SFTP_HOST / SFTP_USER). Skipping.');
    return { method: 'sftp', success: false, error: 'SFTP not configured' };
  }

  let SftpClient;
  try {
    SftpClient = require('ssh2-sftp-client');
  } catch {
    console.warn('[PrinterDelivery:sftp] ssh2-sftp-client not installed. Run: npm install ssh2-sftp-client');
    return { method: 'sftp', success: false, error: 'ssh2-sftp-client not installed' };
  }

  const sftp = new SftpClient();
  try {
    await sftp.connect({ host, port, username, password });

    const remotePath = `${remoteDir}/${orderNumber.replace(/[^a-zA-Z0-9_#-]/g, '_')}`;
    await sftp.mkdir(remotePath, true);

    let uploaded = 0;
    for (const [label, srcPath] of Object.entries(filePaths)) {
      if (srcPath && fs.existsSync(srcPath)) {
        const destFile = `${remotePath}/${path.basename(srcPath)}`;
        await sftp.put(srcPath, destFile);
        uploaded++;
      }
    }

    console.log(`[PrinterDelivery:sftp] Uploaded ${uploaded} files to ${host}:${remotePath}`);
    return { method: 'sftp', success: true, host, remotePath, fileCount: uploaded };
  } catch (err) {
    console.error(`[PrinterDelivery:sftp] Error: ${err.message}`);
    return { method: 'sftp', success: false, error: err.message };
  } finally {
    await sftp.end();
  }
}

/* ──────────────────────────────────────────────────────────
 * deliverPrintFiles()
 *   Main entry point — delivers via all configured methods.
 *
 * @param {Object} emailParams  - Full params for sendPrinterEmail()
 * @param {Object} filePaths    - { svg, rgb, cmyk, packingSlip } paths
 * @returns {Object[]} Results from each delivery method
 * ────────────────────────────────────────────────────────── */
async function deliverPrintFiles(emailParams, filePaths) {
  const results = [];

  for (const method of deliveryMethods) {
    try {
      switch (method) {
        case 'email': {
          const emailResult = await sendPrinterEmail(emailParams);
          results.push({ method: 'email', success: emailResult.success, ...emailResult });
          break;
        }
        case 'folder': {
          const folderResult = deliverToFolder(emailParams.orderNumber, filePaths);
          results.push(folderResult);
          break;
        }
        case 'sftp': {
          const sftpResult = await deliverViaSftp(emailParams.orderNumber, filePaths);
          results.push(sftpResult);
          break;
        }
        default:
          console.warn(`[PrinterDelivery] Unknown method: ${method}`);
      }
    } catch (err) {
      console.error(`[PrinterDelivery:${method}] Delivery failed: ${err.message}`);
      results.push({ method, success: false, error: err.message });
    }
  }

  const successCount = results.filter(r => r.success).length;
  console.log(`[PrinterDelivery] ${successCount}/${results.length} delivery methods succeeded`);

  return results;
}

/**
 * Get the current delivery method configuration.
 */
function getDeliveryConfig() {
  return {
    methods: deliveryMethods,
    dropboxDir: deliveryMethods.includes('folder') ? DROPBOX_DIR : null,
    sftpHost: deliveryMethods.includes('sftp') ? (process.env.SFTP_HOST || null) : null,
  };
}

module.exports = {
  deliverPrintFiles,
  getDeliveryConfig,
  deliveryMethods,
};
