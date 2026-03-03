/**
 * Artifact Store
 * ──────────────
 * Persists generated print files (SVG, RGB PNG, CMYK PDF, preview JPEG)
 * under a unique artifactId, and provides lookup for the webhook.
 *
 * Storage: local disk + JSON manifest
 *   output/artifacts/<artifactId>/
 *     manifest.json          ← metadata + file list
 *     bracket.svg
 *     print_ready_rgb.png
 *     print_ready_cmyk.pdf   (if CMYK enabled)
 *     preview.jpg
 *
 * artifactId format: 16-char hex (crypto.randomBytes(8))
 *
 * Designed for fast-launch: file-based, no external DB dependency.
 * Can be swapped for S3 / GCS later by replacing copyToArtifact / loadArtifact.
 */

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const ARTIFACTS_DIR = path.join(__dirname, '..', '..', 'output', 'artifacts');

// Ensure base dir exists
if (!fs.existsSync(ARTIFACTS_DIR)) {
  fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
}

/**
 * Generate a unique artifact ID.
 * @returns {string} 16-char hex string
 */
function generateArtifactId() {
  return crypto.randomBytes(8).toString('hex');
}

/**
 * Persist generated files into the artifact store.
 *
 * @param {Object} params
 * @param {string} params.artifactId       - Unique ID (from generateArtifactId)
 * @param {string} params.previewPath      - Path to preview JPEG
 * @param {string} params.svgPath          - Path to bracket SVG
 * @param {string} params.printReadyRgbPath - Path to RGB PNG
 * @param {string|null} params.printReadyCmykPath - Path to CMYK PDF (null if disabled)
 * @param {Object} params.metadata         - Extra metadata to store
 * @returns {{ artifactId: string, dir: string, files: string[] }}
 */
function saveArtifact({
  artifactId,
  previewPath,
  svgPath,
  printReadyRgbPath,
  printReadyCmykPath = null,
  metadata = {},
}) {
  const dir = path.join(ARTIFACTS_DIR, artifactId);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  const files = [];

  // Copy each file into the artifact directory with canonical names
  const copies = [
    { src: previewPath, dest: 'preview.jpg' },
    { src: svgPath, dest: 'bracket.svg' },
    { src: printReadyRgbPath, dest: 'print_ready_rgb.png' },
  ];
  if (printReadyCmykPath) {
    copies.push({ src: printReadyCmykPath, dest: 'print_ready_cmyk.pdf' });
  }

  for (const { src, dest } of copies) {
    if (src && fs.existsSync(src)) {
      const destPath = path.join(dir, dest);
      fs.copyFileSync(src, destPath);
      files.push(dest);
    }
  }

  // Write manifest
  const manifest = {
    artifactId,
    createdAt: new Date().toISOString(),
    files,
    metadata,
  };
  fs.writeFileSync(path.join(dir, 'manifest.json'), JSON.stringify(manifest, null, 2));

  console.log(`[ArtifactStore] Saved artifact ${artifactId} (${files.length} files)`);
  return { artifactId, dir, files };
}

/**
 * Load an artifact by ID.
 *
 * @param {string} artifactId
 * @returns {{ artifactId, dir, manifest, files: { name, path, exists }[] } | null}
 */
function loadArtifact(artifactId) {
  if (!artifactId) return null;

  const dir = path.join(ARTIFACTS_DIR, artifactId);
  const manifestPath = path.join(dir, 'manifest.json');

  if (!fs.existsSync(manifestPath)) {
    console.warn(`[ArtifactStore] Artifact not found: ${artifactId}`);
    return null;
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  // Map canonical names to full paths
  const fileMap = {
    'preview.jpg': path.join(dir, 'preview.jpg'),
    'bracket.svg': path.join(dir, 'bracket.svg'),
    'print_ready_rgb.png': path.join(dir, 'print_ready_rgb.png'),
    'print_ready_cmyk.pdf': path.join(dir, 'print_ready_cmyk.pdf'),
  };

  const files = Object.entries(fileMap).map(([name, filePath]) => ({
    name,
    path: filePath,
    exists: fs.existsSync(filePath),
  }));

  return { artifactId, dir, manifest, files };
}

/**
 * Get the resolved file paths for a stored artifact.
 * Returns paths in the format expected by email-service / webhook.
 *
 * @param {string} artifactId
 * @returns {{ svgPath, printReadyRgbPath, printReadyCmykPath, packingSlipPath, previewPath } | null}
 */
function getArtifactPaths(artifactId) {
  const artifact = loadArtifact(artifactId);
  if (!artifact) return null;

  const dir = artifact.dir;
  const svgPath = path.join(dir, 'bracket.svg');
  const printReadyRgbPath = path.join(dir, 'print_ready_rgb.png');
  const printReadyCmykPath = path.join(dir, 'print_ready_cmyk.pdf');
  const previewPath = path.join(dir, 'preview.jpg');

  return {
    svgPath: fs.existsSync(svgPath) ? svgPath : null,
    printReadyRgbPath: fs.existsSync(printReadyRgbPath) ? printReadyRgbPath : null,
    printReadyCmykPath: fs.existsSync(printReadyCmykPath) ? printReadyCmykPath : null,
    previewPath: fs.existsSync(previewPath) ? previewPath : null,
  };
}

/**
 * Add a packing slip to an existing artifact.
 *
 * @param {string} artifactId
 * @param {string} packingSlipPath - Source packing slip PDF path
 * @returns {boolean} success
 */
function addPackingSlip(artifactId, packingSlipPath) {
  if (!artifactId || !packingSlipPath) return false;

  const dir = path.join(ARTIFACTS_DIR, artifactId);
  if (!fs.existsSync(dir)) return false;

  const dest = path.join(dir, 'packing_slip.pdf');
  if (fs.existsSync(packingSlipPath)) {
    fs.copyFileSync(packingSlipPath, dest);

    // Update manifest
    const manifestPath = path.join(dir, 'manifest.json');
    if (fs.existsSync(manifestPath)) {
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      if (!manifest.files.includes('packing_slip.pdf')) {
        manifest.files.push('packing_slip.pdf');
        fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
      }
    }
    return true;
  }
  return false;
}

/**
 * List all artifacts (for admin/debugging).
 * @returns {Object[]} Array of manifest objects
 */
function listArtifacts() {
  if (!fs.existsSync(ARTIFACTS_DIR)) return [];

  return fs.readdirSync(ARTIFACTS_DIR)
    .filter(d => fs.existsSync(path.join(ARTIFACTS_DIR, d, 'manifest.json')))
    .map(d => {
      const manifest = JSON.parse(fs.readFileSync(path.join(ARTIFACTS_DIR, d, 'manifest.json'), 'utf8'));
      return manifest;
    })
    .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
}

module.exports = {
  generateArtifactId,
  saveArtifact,
  loadArtifact,
  getArtifactPaths,
  addPackingSlip,
  listArtifacts,
  ARTIFACTS_DIR,
};
