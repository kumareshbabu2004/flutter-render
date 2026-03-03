/**
 * Image Compositor
 * ----------------
 * Pure image compositing using Sharp.
 *
 * Outputs per order (controlled by OUTPUT_COLOR_MODES in config):
 *   1. bracket_<id>.svg           -- vector, transparent, 12-inch artboard
 *   2. print_ready_rgb_<id>.png   -- 3600px wide, RGB, 300 DPI equivalent
 *   3. print_ready_cmyk_<id>.pdf  -- 12-inch wide, CMYK, 300 DPI (via ImageMagick)
 *   4. preview_<id>.jpg           -- composite on hoodie mockup (for Flutter)
 *
 * No filters. No blending modes. No AI rendering.
 * Deterministic pixel placement only.
 */

const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const https = require('https');
const http = require('http');

const config = require('../config');
const { convertToCmykPdf } = require('./cmyk-converter');

const MOCKUPS_DIR = path.join(__dirname, '..', '..', 'assets', 'mockups');
const OUTPUT_DIR = path.join(__dirname, '..', '..', 'output');

/* ──────────────────────────────────────────────────────────
 * compositePreview()
 *   Called by POST /generate-preview
 *   Generates preview.jpg + all print-ready files.
 * ────────────────────────────────────────────────────────── */
async function compositePreview({
  svgString,
  mockupPath,
  outputFilename = 'preview',
  bracketWidthPct = 0.45,
  collarOffset = 500,
  format = 'jpeg',
}) {
  // Step 1: Load mockup image
  let mockupBuffer;
  if (mockupPath.startsWith('http')) {
    mockupBuffer = await fetchImage(mockupPath);
  } else {
    mockupBuffer = fs.readFileSync(mockupPath);
  }

  const mockupMeta = await sharp(mockupBuffer).metadata();
  const mockupW = mockupMeta.width;
  const mockupH = mockupMeta.height;

  // Step 2: Render SVG to PNG at 3600px wide (300 DPI = 12 inches)
  const svgBuffer = Buffer.from(svgString);
  const printReadyPng = await sharp(svgBuffer, { density: 300 })
    .resize(3600)
    .png()
    .toBuffer();

  // Step 3: Save RGB PNG (always generated -- needed for CMYK conversion + preview)
  const rgbFilename = `${outputFilename}_rgb`;
  const printReadyRgbPath = path.join(OUTPUT_DIR, 'print_ready', `${rgbFilename}.png`);
  fs.writeFileSync(printReadyRgbPath, printReadyPng);
  console.log(`[Compositor] RGB PNG: ${rgbFilename}.png (${(printReadyPng.length / 1024).toFixed(0)} KB)`);

  // Step 4: Generate CMYK PDF (if enabled)
  let printReadyCmykPath = null;
  if (config.cmykEnabled) {
    try {
      const cmykFilename = `${outputFilename}_cmyk`;
      const cmykResult = await convertToCmykPdf(printReadyRgbPath, cmykFilename);
      printReadyCmykPath = cmykResult.path;
      console.log(`[Compositor] CMYK PDF: ${cmykFilename}.pdf (${(cmykResult.sizeBytes / 1024).toFixed(0)} KB)`);
    } catch (err) {
      console.error(`[Compositor] CMYK conversion failed (non-fatal): ${err.message}`);
    }
  }

  // Step 5: Scale bracket to fit on mockup for preview
  const targetBracketW = Math.round(mockupW * bracketWidthPct);
  const bracketMeta = await sharp(printReadyPng).metadata();
  const aspectRatio = bracketMeta.height / bracketMeta.width;
  const targetBracketH = Math.round(targetBracketW * aspectRatio);

  const scaledBracket = await sharp(printReadyPng)
    .resize(targetBracketW, targetBracketH, { fit: 'inside' })
    .png()
    .toBuffer();

  const scaledMeta = await sharp(scaledBracket).metadata();

  // Step 6: Calculate position -- center horizontally, offset below collar
  const left = Math.round((mockupW - scaledMeta.width) / 2);
  const top = Math.min(collarOffset, mockupH - scaledMeta.height - 50);

  // Step 7: Composite preview
  let pipeline = sharp(mockupBuffer);
  if (format === 'jpeg') {
    pipeline = pipeline.composite([
      { input: scaledBracket, left, top },
    ]).jpeg({ quality: 90 });
  } else {
    pipeline = pipeline.composite([
      { input: scaledBracket, left, top },
    ]).png();
  }
  const composited = await pipeline.toBuffer();

  // Save preview
  const ext = format === 'jpeg' ? 'jpg' : 'png';
  const previewPath = path.join(OUTPUT_DIR, 'previews', `${outputFilename}.${ext}`);
  fs.writeFileSync(previewPath, composited);

  // Save SVG
  const svgPath = path.join(OUTPUT_DIR, 'svgs', `${outputFilename}.svg`);
  fs.writeFileSync(svgPath, svgString);

  return {
    previewPath,
    previewBuffer: composited,
    svgPath,
    printReadyRgbPath,
    printReadyCmykPath,        // null if CMYK disabled or conversion failed
    dimensions: {
      mockup: { width: mockupW, height: mockupH },
      bracket: { width: scaledMeta.width, height: scaledMeta.height },
      position: { left, top },
    },
  };
}

/* ──────────────────────────────────────────────────────────
 * generatePrintReady()
 *   Called by the Shopify webhook route.
 *   Produces the actual files sent to the printer:
 *     - SVG  (saved by caller)
 *     - RGB PNG  (always)
 *     - CMYK PDF (if enabled)
 * ────────────────────────────────────────────────────────── */
async function generatePrintReady(svgString, outputFilename) {
  // RGB PNG at 3600px (12 inches @ 300 DPI)
  const svgBuffer = Buffer.from(svgString);
  const pngBuffer = await sharp(svgBuffer, { density: 300 })
    .resize(3600)
    .png()
    .toBuffer();

  const rgbPath = path.join(OUTPUT_DIR, 'print_ready', `${outputFilename}.png`);
  fs.writeFileSync(rgbPath, pngBuffer);
  console.log(`[PrintReady] RGB PNG: ${outputFilename}.png (${(pngBuffer.length / 1024).toFixed(0)} KB)`);

  // CMYK PDF
  let cmykPath = null;
  if (config.cmykEnabled) {
    try {
      const cmykResult = await convertToCmykPdf(rgbPath, outputFilename.replace('_rgb', '_cmyk'));
      cmykPath = cmykResult.path;
      console.log(`[PrintReady] CMYK PDF: ${path.basename(cmykPath)} (${(cmykResult.sizeBytes / 1024).toFixed(0)} KB)`);
    } catch (err) {
      console.error(`[PrintReady] CMYK conversion failed (non-fatal): ${err.message}`);
    }
  }

  return {
    rgbPath,
    rgbBuffer: pngBuffer,
    cmykPath,
  };
}

/* ──────────────────────────────────────────────────────────
 * fetchImage()
 *   Download an image from a URL and return as Buffer.
 * ────────────────────────────────────────────────────────── */
function fetchImage(url) {
  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;
    protocol.get(url, (res) => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        return fetchImage(res.headers.location).then(resolve).catch(reject);
      }
      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to fetch image: HTTP ${res.statusCode}`));
      }
      const chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

/* ──────────────────────────────────────────────────────────
 * Product mockup helpers
 * ────────────────────────────────────────────────────────── */
const PRODUCT_MOCKUP_MAP = {
  bp_grid_iron: 'st250_black_back.png',
  bp_tri_tee: 'dm130_black_back.png',
  bp_street_lounge: 'nea500_black_back.png',
  bp_on_the_go: 'nea137_black_back.png',
  bp_all_day: 'nea510_blackheather_back.png',
};

function getMockupPath(productId, colorName) {
  const candidates = [
    `${productId}_${colorName.toLowerCase().replace(/\s+/g, '_')}_back.png`,
    PRODUCT_MOCKUP_MAP[productId],
    `${productId}_back.png`,
    'default_hoodie_back.jpg',
  ].filter(Boolean);

  for (const file of candidates) {
    const fullPath = path.join(MOCKUPS_DIR, file);
    if (fs.existsSync(fullPath)) return fullPath;
  }
  return null;
}

module.exports = { compositePreview, generatePrintReady, fetchImage, getMockupPath };
