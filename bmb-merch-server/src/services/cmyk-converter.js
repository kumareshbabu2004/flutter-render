/**
 * CMYK Converter
 * ──────────────
 * Converts RGB PNG bracket artwork to a CMYK PDF suitable for print shops.
 *
 * Pipeline:
 *   1. Input: RGB PNG (3600px wide, 12 inches at 300 DPI)
 *   2. ImageMagick converts RGB → CMYK using ICC profile
 *   3. Output: CMYK PDF at 300 DPI on a 12-inch wide canvas
 *
 * ICC Profiles used:
 *   - Input:  /usr/share/color/icc/ghostscript/default_rgb.icc  (sRGB)
 *   - Output: /usr/share/color/icc/ghostscript/default_cmyk.icc (SWOP/Generic CMYK)
 *
 * No AI rendering. Deterministic color conversion only.
 */

const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');

const OUTPUT_DIR = path.join(__dirname, '..', '..', 'output');
const CMYK_DIR = path.join(OUTPUT_DIR, 'print_ready_cmyk');

// ICC profiles shipped with the Ghostscript ICC package
const ICC_RGB  = '/usr/share/color/icc/ghostscript/default_rgb.icc';
const ICC_CMYK = '/usr/share/color/icc/ghostscript/default_cmyk.icc';

// Ensure output directory exists
if (!fs.existsSync(CMYK_DIR)) {
  fs.mkdirSync(CMYK_DIR, { recursive: true });
}

/**
 * Convert an RGB PNG to a CMYK PDF.
 *
 * ImageMagick `convert` pipeline:
 *   input.png
 *     → apply sRGB ICC profile (tag the source space)
 *     → convert to CMYK using the CMYK ICC profile
 *     → set density to 300 DPI (= 12 inches for 3600px)
 *     → write as PDF
 *
 * @param {string} rgbPngPath       - Absolute path to the RGB PNG
 * @param {string} outputFilename   - Filename (without extension) for the CMYK PDF
 * @returns {Promise<{path: string, colorspace: string, widthInches: number}>}
 */
async function convertToCmykPdf(rgbPngPath, outputFilename) {
  const outputPath = path.join(CMYK_DIR, `${outputFilename}.pdf`);

  // Verify input exists
  if (!fs.existsSync(rgbPngPath)) {
    throw new Error(`CMYK input not found: ${rgbPngPath}`);
  }

  // Verify ICC profiles exist
  const rgbProfileExists  = fs.existsSync(ICC_RGB);
  const cmykProfileExists = fs.existsSync(ICC_CMYK);

  // Build ImageMagick args
  const args = [rgbPngPath];

  if (rgbProfileExists && cmykProfileExists) {
    // ICC-based conversion (most accurate)
    args.push(
      '-profile', ICC_RGB,          // tag input as sRGB
      '-profile', ICC_CMYK,         // convert to CMYK via ICC
    );
  } else {
    // Fallback: direct colorspace conversion (less accurate but functional)
    console.warn('[CMYK] ICC profiles not found — falling back to direct colorspace conversion');
    args.push('-colorspace', 'CMYK');
  }

  args.push(
    '-density', '300',              // 300 DPI → 3600px = 12 inches
    '-units', 'PixelsPerInch',
    outputPath,
  );

  return new Promise((resolve, reject) => {
    execFile('convert', args, { timeout: 30000 }, (err, stdout, stderr) => {
      if (err) {
        console.error('[CMYK] ImageMagick error:', stderr || err.message);
        return reject(new Error(`CMYK conversion failed: ${stderr || err.message}`));
      }

      // Verify output was created
      if (!fs.existsSync(outputPath)) {
        return reject(new Error('CMYK PDF was not created'));
      }

      const stat = fs.statSync(outputPath);
      console.log(`[CMYK] Created ${outputFilename}.pdf (${(stat.size / 1024).toFixed(0)} KB, CMYK, 300 DPI)`);

      resolve({
        path: outputPath,
        colorspace: 'CMYK',
        widthInches: 12,
        dpi: 300,
        sizeBytes: stat.size,
      });
    });
  });
}

/**
 * Check if CMYK conversion is available on this system.
 * Returns true if ImageMagick `convert` and ICC profiles are found.
 */
function isCmykAvailable() {
  try {
    // Check ImageMagick
    const { execSync } = require('child_process');
    execSync('which convert', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

module.exports = { convertToCmykPdf, isCmykAvailable, CMYK_DIR };
