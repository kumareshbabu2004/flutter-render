/**
 * Packing Slip PDF Generator
 * ──────────────────────────
 * Generates a packing slip PDF with:
 *   - Order number
 *   - Customer info (name, address)
 *   - Product details (name, color, size)
 *   - Bracket info (title, team count, champion)
 *   - BMB branding
 */

const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');

const OUTPUT_DIR = path.join(__dirname, '..', '..', 'output', 'packing_slips');

/**
 * Generate a packing slip PDF.
 *
 * @param {Object} order
 * @param {string} order.orderNumber     - e.g. "BMB-2025-12345"
 * @param {string} order.customerName
 * @param {string} order.address
 * @param {string} order.city
 * @param {string} order.state
 * @param {string} order.zip
 * @param {string} order.email
 * @param {string} order.phone
 * @param {string} order.productTitle    - e.g. "Grid Iron Hoodie"
 * @param {string} order.color
 * @param {string} order.size
 * @param {string} order.bracketTitle
 * @param {number} order.teamCount
 * @param {string} order.championName
 * @param {string} order.printStyle      - "Classic" | "Premium" | "Bold"
 * @param {string} order.createdAt       - ISO date string
 * @param {string} order.productType     - "hoodie" | "tee" | "accessory"
 * @param {string} order.shopifyProductId - Shopify numeric product ID
 * @param {string} order.shopifyVariantId - Shopify variant ID
 * @param {number} order.printWidthInches - Print width (default 12)
 * @param {string} order.garmentModel    - Garment model name (e.g. "Grid Iron Hoodie")
 * @returns {Promise<string>} path to generated PDF
 */
async function generatePackingSlip(order) {
  return new Promise((resolve, reject) => {
    const filename = `packing_slip_${order.orderNumber}.pdf`;
    const outputPath = path.join(OUTPUT_DIR, filename);
    const doc = new PDFDocument({ size: 'LETTER', margin: 50 });
    const stream = fs.createWriteStream(outputPath);

    doc.pipe(stream);

    // ── Header ──────────────────────────────────────────
    doc.fontSize(24).font('Helvetica-Bold').text('BACK MY BRACKET', { align: 'center' });
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica').fillColor('#666666').text('Custom Bracket Print Fulfillment', { align: 'center' });
    doc.moveDown(0.5);

    // Divider
    doc.strokeColor('#CCCCCC').lineWidth(1)
      .moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(0.5);

    // ── Order Info ──────────────────────────────────────
    doc.fontSize(16).font('Helvetica-Bold').fillColor('#000000')
      .text(`ORDER #${order.orderNumber}`);
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica').fillColor('#666666')
      .text(`Date: ${formatDate(order.createdAt)}`);
    doc.moveDown(1);

    // ── Ship To ─────────────────────────────────────────
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#999999').text('SHIP TO');
    doc.moveDown(0.3);
    doc.fontSize(12).font('Helvetica-Bold').fillColor('#000000')
      .text(order.customerName);
    doc.fontSize(11).font('Helvetica').fillColor('#333333')
      .text(order.address)
      .text(`${order.city}, ${order.state} ${order.zip}`);
    if (order.email) doc.text(`Email: ${order.email}`);
    if (order.phone) doc.text(`Phone: ${order.phone}`);
    doc.moveDown(1);

    // ── Divider ─────────────────────────────────────────
    doc.strokeColor('#EEEEEE').lineWidth(1)
      .moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(0.5);

    // ── Product Details ─────────────────────────────────
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#999999').text('PRODUCT');
    doc.moveDown(0.3);

    const productDetails = [
      ['Item', order.productTitle],
      ['Color', order.color],
      ['Size', order.size],
      ['Garment Type', (order.productType || 'hoodie').charAt(0).toUpperCase() + (order.productType || 'hoodie').slice(1)],
    ];
    if (order.garmentModel && order.garmentModel !== order.productTitle) {
      productDetails.push(['Model', order.garmentModel]);
    }
    if (order.shopifyProductId) {
      productDetails.push(['Shopify ID', order.shopifyProductId]);
    }

    productDetails.forEach(([label, value]) => {
      doc.fontSize(11).font('Helvetica').fillColor('#666666').text(label + ':', {
        continued: true,
        width: 100,
      });
      doc.font('Helvetica-Bold').fillColor('#000000').text('  ' + value);
    });
    doc.moveDown(1);

    // ── Bracket Print Details ───────────────────────────
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#999999').text('BRACKET PRINT');
    doc.moveDown(0.3);

    const bracketDetails = [
      ['Bracket', order.bracketTitle],
      ['Teams', `${order.teamCount}-team bracket`],
      ['Champion', order.championName],
      ['Print Style', order.printStyle],
      ['Print Area', 'Full back'],
      ['Print Width', `${order.printWidthInches || 12} inches at 300 DPI`],
    ];

    bracketDetails.forEach(([label, value]) => {
      doc.fontSize(11).font('Helvetica').fillColor('#666666').text(label + ':', {
        continued: true,
        width: 120,
      });
      doc.font('Helvetica-Bold').fillColor('#000000').text('  ' + value);
    });
    doc.moveDown(1.5);

    // ── Divider ─────────────────────────────────────────
    doc.strokeColor('#EEEEEE').lineWidth(1)
      .moveTo(50, doc.y).lineTo(562, doc.y).stroke();
    doc.moveDown(0.5);

    // ── Print Instructions ──────────────────────────────
    doc.fontSize(10).font('Helvetica-Bold').fillColor('#D63031').text('PRINT INSTRUCTIONS');
    doc.moveDown(0.3);
    doc.fontSize(10).font('Helvetica').fillColor('#333333')
      .text('1. Use bracket.svg (vector) for production print')
      .text('2. RGB reference: print_ready_rgb.png (3600px, 300 DPI, 12 inches)')
      .text('3. CMYK print-shop file: print_ready_cmyk.pdf (CMYK, 300 DPI, 12-inch canvas)')
      .text('4. Print area: Full back, centered horizontally -- DTG only, NO front printing')
      .text(`5. Bracket palette: ${order.color && isColorDark(order.color) ? 'White/Gold on dark garment' : 'Dark/Navy on light garment'}`);
    doc.moveDown(1);

    // ── Footer ──────────────────────────────────────────
    doc.fontSize(8).font('Helvetica').fillColor('#999999')
      .text('BackMyBracket.com | Custom Bracket Merchandise', { align: 'center' })
      .text('Questions? Contact ahmad@backmybracket.com', { align: 'center' });

    doc.end();

    stream.on('finish', () => resolve(outputPath));
    stream.on('error', reject);
  });
}

function formatDate(dateStr) {
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString('en-US', {
      year: 'numeric', month: 'long', day: 'numeric',
    });
  } catch {
    return dateStr || 'N/A';
  }
}

function isColorDark(colorName) {
  const dark = ['black', 'navy', 'charcoal', 'graphite', 'dark', 'shadow', 'heather'];
  const lower = colorName.toLowerCase();
  return dark.some(d => lower.includes(d));
}

module.exports = { generatePackingSlip };
