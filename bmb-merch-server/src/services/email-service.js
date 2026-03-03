/**
 * Email Service (Nodemailer)
 * --------------------------
 * Sends printer fulfillment emails with up to 4 attachments:
 *   1. bracket_<order>.svg           -- vector print file
 *   2. print_ready_rgb_<order>.png   -- 3600px RGB raster (300 DPI)
 *   3. print_ready_cmyk_<order>.pdf  -- CMYK PDF for print shops
 *   4. packing_slip_<order>.pdf      -- order info + shipping label
 *
 * Attachment inclusion is controlled by OUTPUT_COLOR_MODES in config.
 * Files are only attached if they exist on disk.
 *
 * Retry: on failure, retries up to EMAIL_MAX_RETRIES (default 3)
 * with exponential backoff (2s, 4s, 8s).
 */

const nodemailer = require('nodemailer');
const path = require('path');
const fs = require('fs');
const config = require('../config');

/* ──────────────────────────────────────────────────────────
 * SMTP Transporter
 * ────────────────────────────────────────────────────────── */
function createTransporter() {
  const host = process.env.SMTP_HOST;
  const port = parseInt(process.env.SMTP_PORT || '587', 10);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  const isPlaceholder = (v) => !v || v.includes('xxxx') || v.startsWith('your_');
  if (isPlaceholder(host) || isPlaceholder(user) || isPlaceholder(pass)) {
    console.warn('[Email] No valid SMTP credentials configured. Emails will be logged to console.');
    return null;
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
}

/* ──────────────────────────────────────────────────────────
 * sleep()
 * ────────────────────────────────────────────────────────── */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/* ──────────────────────────────────────────────────────────
 * sendPrinterEmail()
 *   Sends the fulfillment email with all generated files.
 *   Retries up to config.emailMaxRetries on failure.
 * ────────────────────────────────────────────────────────── */
async function sendPrinterEmail(params) {
  const {
    orderNumber,
    customerName,
    productTitle,
    color,
    size,
    bracketTitle,
    teamCount,
    championName,
    printStyle,
    svgPath,
    printReadyRgbPath,
    printReadyCmykPath,
    packingSlipPath,
    // Product config metadata
    productType = 'hoodie',
    shopifyProductId,
    printWidthInches = 12,
    garmentModel,
  } = params;

  const printerEmail = process.env.PRINTER_EMAIL || 'jkim@aceusainc.com';
  const ccEmails = process.env.CC_EMAILS || 'ahmad@backmybracket.com,amchi81@gmail.com';
  const fromEmail = process.env.SMTP_USER || 'orders@backmybracket.com';

  const subject = `[BMB Order #${orderNumber}] ${productTitle} -- ${color} ${size}`;

  // -- Build attachment manifest for the HTML body --
  const attachmentLines = [];
  attachmentLines.push(`<li><strong>bracket_${orderNumber}.svg</strong> -- Vector print file (use for production)</li>`);
  if (config.rgbEnabled) {
    attachmentLines.push(`<li><strong>print_ready_rgb_${orderNumber}.png</strong> -- 3600px RGB raster, 300 DPI (12 inches)</li>`);
  }
  if (config.cmykEnabled && printReadyCmykPath) {
    attachmentLines.push(`<li><strong>print_ready_cmyk_${orderNumber}.pdf</strong> -- CMYK PDF, 300 DPI, 12-inch canvas (print-shop ready)</li>`);
  }
  attachmentLines.push(`<li><strong>packing_slip_${orderNumber}.pdf</strong> -- Packing slip (include in shipment)</li>`);

  const htmlBody = `
<!DOCTYPE html>
<html>
<head><style>
  body { font-family: 'Helvetica Neue', Arial, sans-serif; color: #333; }
  .header { background: #0A0E27; color: white; padding: 20px; text-align: center; }
  .header h1 { margin: 0; font-size: 24px; letter-spacing: 2px; }
  .content { padding: 20px; }
  .section { margin-bottom: 20px; }
  .section h3 { color: #0A0E27; border-bottom: 2px solid #FFD700; padding-bottom: 5px; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 6px 0; }
  .label { color: #999; width: 140px; font-weight: 600; }
  .value { color: #000; font-weight: 700; }
  .footer { background: #f5f5f5; padding: 15px; text-align: center; font-size: 12px; color: #999; }
  .badge { display: inline-block; background: #FFD700; color: #000; padding: 4px 12px; border-radius: 4px; font-weight: 700; }
  .color-mode { display: inline-block; background: #e8f5e9; color: #2e7d32; padding: 2px 8px; border-radius: 3px; font-size: 11px; font-weight: 600; margin-right: 4px; }
</style></head>
<body>
  <div class="header">
    <h1>BACK MY BRACKET</h1>
    <p style="margin: 5px 0 0; opacity: 0.7;">Print Fulfillment Order</p>
  </div>
  <div class="content">
    <div class="section">
      <h3>Order #${orderNumber}</h3>
      <table>
        <tr><td class="label">Product:</td><td class="value">${productTitle}</td></tr>
        <tr><td class="label">Color:</td><td class="value">${color}</td></tr>
        <tr><td class="label">Size:</td><td class="value">${size}</td></tr>
        <tr><td class="label">Print Style:</td><td class="value">${printStyle}</td></tr>
        <tr><td class="label">Garment Type:</td><td class="value">${(productType || 'hoodie').charAt(0).toUpperCase() + (productType || 'hoodie').slice(1)}${garmentModel ? ` (${garmentModel})` : ''}</td></tr>
        <tr><td class="label">Print Area:</td><td class="value">Full back -- DTG -- ${printWidthInches}"-wide at 300 DPI</td></tr>
        <tr><td class="label">Color Modes:</td><td class="value">${config.colorModes.map(m => `<span class="color-mode">${m}</span>`).join(' ')}</td></tr>
        ${shopifyProductId ? `<tr><td class="label">Shopify ID:</td><td class="value" style="font-size:11px;color:#888">${shopifyProductId}</td></tr>` : ''}
      </table>
    </div>
    <div class="section">
      <h3>Bracket Details</h3>
      <table>
        <tr><td class="label">Bracket:</td><td class="value">${bracketTitle}</td></tr>
        <tr><td class="label">Teams:</td><td class="value">${teamCount}-team bracket</td></tr>
        <tr><td class="label">Champion:</td><td class="value"><span class="badge">${championName}</span></td></tr>
      </table>
    </div>
    <div class="section">
      <h3>Ship To</h3>
      <p><strong>${customerName}</strong></p>
    </div>
    <div class="section">
      <h3>Attachments (${attachmentLines.length} files)</h3>
      <ol>
        ${attachmentLines.join('\n        ')}
      </ol>
    </div>
  </div>
  <div class="footer">
    BackMyBracket.com | Questions? ahmad@backmybracket.com
  </div>
</body>
</html>`;

  // -- Build actual file attachments --
  const attachments = [];

  // 1. SVG (always)
  if (svgPath && fs.existsSync(svgPath)) {
    attachments.push({
      filename: `bracket_${orderNumber}.svg`,
      path: svgPath,
      contentType: 'image/svg+xml',
    });
  }

  // 2. RGB PNG (if enabled)
  if (config.rgbEnabled && printReadyRgbPath && fs.existsSync(printReadyRgbPath)) {
    attachments.push({
      filename: `print_ready_rgb_${orderNumber}.png`,
      path: printReadyRgbPath,
      contentType: 'image/png',
    });
  }

  // 3. CMYK PDF (if enabled and conversion succeeded)
  if (config.cmykEnabled && printReadyCmykPath && fs.existsSync(printReadyCmykPath)) {
    attachments.push({
      filename: `print_ready_cmyk_${orderNumber}.pdf`,
      path: printReadyCmykPath,
      contentType: 'application/pdf',
    });
  }

  // 4. Packing slip PDF (always)
  if (packingSlipPath && fs.existsSync(packingSlipPath)) {
    attachments.push({
      filename: `packing_slip_${orderNumber}.pdf`,
      path: packingSlipPath,
      contentType: 'application/pdf',
    });
  }

  const mailOptions = {
    from: `"BMB Orders" <${fromEmail}>`,
    to: printerEmail,
    cc: ccEmails,
    subject,
    html: htmlBody,
    attachments,
  };

  // Send or log — with retry
  const transporter = createTransporter();

  if (transporter) {
    return await _sendWithRetry(transporter, mailOptions, attachments.length);
  } else {
    // Dev mode: log email details
    console.log('\n' + '='.concat('='.repeat(53)));
    console.log('  PRINTER EMAIL (dev mode -- not sent)');
    console.log('='.concat('='.repeat(53)));
    console.log(`  TO:          ${printerEmail}`);
    console.log(`  CC:          ${ccEmails}`);
    console.log(`  SUBJECT:     ${subject}`);
    console.log(`  COLOR MODES: ${config.colorModes.join(', ')}`);
    console.log(`  ATTACHMENTS (${attachments.length}):`);
    attachments.forEach((a, i) => {
      const size = fs.existsSync(a.path) ? `${(fs.statSync(a.path).size / 1024).toFixed(0)} KB` : 'missing';
      console.log(`    ${i + 1}. ${a.filename} (${size})`);
    });
    console.log('='.concat('='.repeat(53)) + '\n');
    return { success: true, messageId: 'dev-mode-logged', attachmentCount: attachments.length };
  }
}

/* ──────────────────────────────────────────────────────────
 * _sendWithRetry()
 *   Retry email sending up to config.emailMaxRetries times
 *   with exponential backoff.
 * ────────────────────────────────────────────────────────── */
async function _sendWithRetry(transporter, mailOptions, attachmentCount) {
  const maxRetries = config.emailMaxRetries || 3;
  const baseMs = config.emailRetryBaseMs || 2000;
  let lastError = null;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      const info = await transporter.sendMail(mailOptions);
      console.log(`[Email] Sent to ${mailOptions.to} with ${attachmentCount} attachments: ${info.messageId} (attempt ${attempt})`);
      return {
        success: true,
        messageId: info.messageId,
        attachmentCount,
        attempts: attempt,
      };
    } catch (err) {
      lastError = err;
      console.error(`[Email] Attempt ${attempt}/${maxRetries} failed: ${err.message}`);

      if (attempt < maxRetries) {
        const delay = baseMs * Math.pow(2, attempt - 1); // 2s, 4s, 8s
        console.log(`[Email] Retrying in ${delay}ms...`);
        await sleep(delay);
      }
    }
  }

  // All retries exhausted
  console.error(`[Email] All ${maxRetries} attempts failed. Last error: ${lastError.message}`);
  return {
    success: false,
    error: lastError.message,
    attachmentCount,
    attempts: maxRetries,
  };
}

module.exports = { sendPrinterEmail };
