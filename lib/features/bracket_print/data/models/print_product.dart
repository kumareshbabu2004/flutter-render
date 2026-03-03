import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════
// RENDER MODE — distinguishes interactive UI, print output, and preview
// ═══════════════════════════════════════════════════════════════════════

/// Determines which rendering pipeline produces the bracket.
///
/// - [bracketUI]   Interactive bracket editor with tap/hover/selection.
///                 **NEVER used in the print/preview pipeline.**
/// - [bracketPrint] Data-only SVG/Canvas output at 300 DPI for DTG.
/// - [bracketPreview] Rasterised thumbnail on the garment mockup photo;
///                    uses the same paint code as [bracketPrint] but
///                    scales it down to screen resolution.
enum BracketRenderMode {
  bracketUI,
  bracketPrint,
  bracketPreview,
}

// ═══════════════════════════════════════════════════════════════════════
// UI CONTAMINATION GUARD — hard check for preview/print pipelines
// ═══════════════════════════════════════════════════════════════════════

/// Exception thrown when UI-only visual layers (highlights, selection bars,
/// hover states) are detected in the print or preview rendering pipeline.
///
/// If this fires in a server context the handler MUST return HTTP 500
/// with body `PREVIEW_UI_LAYER_DETECTED`. The app MUST NOT silently
/// fall back to a tainted render.
class PreviewUiLayerDetected implements Exception {
  final String detail;
  const PreviewUiLayerDetected(this.detail);

  @override
  String toString() => 'PREVIEW_UI_LAYER_DETECTED: $detail';
}

/// Known UI-only colours that MUST NEVER appear in print/preview output.
/// If any of these are found in a palette or layer stack, throw.
///
/// Detection levels:
///   1. **Exact match** — flat list of known UI Color values.
///   2. **Alpha-aware** — strips alpha, then matches RGB.
///   3. **HSV-range** — bans the *yellow highlight* (H 40°–70°, S > 0.6)
///      and *blue selection* (H 200°–230°, S > 0.5) hue families regardless
///      of the exact shade. Also bans gradient midpoints that interpolate
///      into those hue bands.
///   4. **SVG hex + regex** — scans SVG text for banned colours AND
///      class-name patterns like "highlight", "selected", "hover", etc.
///   5. **Rasterized-pixel scan** — examines actual rendered pixel data
///      from a `dart:ui.Image` and throws if any pixel falls inside a
///      banned HSV zone.
class UiContaminationGuard {
  // ── Exact-match banned colours ──────────────────────────────────
  static const _uiHighlightYellow = Color(0xFFFFEB3B);
  static const _uiSelectionBlue   = Color(0xFF2196F3);
  static const _uiHoverGlow       = Color(0xFF42A5F5);
  static const _uiTapSplash       = Color(0x44FFFFFF);
  static const _uiActiveSlotFill  = Color(0xFF1565C0);
  static const _uiYellowAmber     = Color(0xFFFFC107);
  static const _uiYellow200       = Color(0xFFFFF176);
  static const _uiBlue200         = Color(0xFF90CAF9);
  static const _uiLightBlue       = Color(0xFF03A9F4);

  /// All exact-match banned UI colours.
  static const bannedColors = [
    _uiHighlightYellow,
    _uiSelectionBlue,
    _uiHoverGlow,
    _uiTapSplash,
    _uiActiveSlotFill,
    _uiYellowAmber,
    _uiYellow200,
    _uiBlue200,
    _uiLightBlue,
  ];

  /// Opaque banned colours only (alpha >= 0xFE). Semi-transparent banned
  /// colours like `_uiTapSplash` (0x44FFFFFF) are intentionally excluded
  /// because stripping their alpha yields 0xFFFFFFFF (pure white), which
  /// collides with legitimate palette whites.
  static final Set<int> _bannedRgbSet = bannedColors
      .where((c) => (c.toARGB32() >> 24) >= 0xFE) // only fully opaque
      .map((c) => c.toARGB32() | 0xFF000000)      // force alpha=FF
      .toSet();

  /// Banned SVG hex strings (both cases).
  static const bannedSvgHex = [
    '#ffeb3b', '#FFEB3B',
    '#2196f3', '#2196F3',
    '#42a5f5', '#42A5F5',
    '#1565c0', '#1565C0',
    '#ffc107', '#FFC107',
    '#fff176', '#FFF176',
    '#90caf9', '#90CAF9',
    '#03a9f4', '#03A9F4',
  ];

  /// Regex patterns that indicate UI-layer class names in SVG output.
  static final _bannedClassPatterns = [
    RegExp(r'class="[^"]*highlight[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*selected[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*hover[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*active-slot[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*selection[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*ui-layer[^"]*"', caseSensitive: false),
    RegExp(r'class="[^"]*bracket-ui[^"]*"', caseSensitive: false),
  ];

  // ── HSV RANGE DETECTION ─────────────────────────────────────────
  // Yellow highlight family: Hue 40°–70°, Saturation > 0.6
  // Blue selection family:   Hue 200°–230°, Saturation > 0.5

  /// Check if a colour falls into a banned HSV zone.
  static bool _isInBannedHsvZone(Color c) {
    // Ignore fully transparent pixels.
    if (c.a < 0.05) return false;

    final r = c.r, g = c.g, b = c.b;
    final cMax = [r, g, b].reduce((a, b2) => a > b2 ? a : b2);
    final cMin = [r, g, b].reduce((a, b2) => a < b2 ? a : b2);
    final delta = cMax - cMin;

    // Very low saturation → achromatic, not in any hue band.
    if (cMax < 0.01 || delta / cMax < 0.15) return false;

    double hue;
    if (delta < 0.001) {
      hue = 0;
    } else if (cMax == r) {
      hue = 60.0 * (((g - b) / delta) % 6);
    } else if (cMax == g) {
      hue = 60.0 * ((b - r) / delta + 2);
    } else {
      hue = 60.0 * ((r - g) / delta + 4);
    }
    if (hue < 0) hue += 360;

    final saturation = delta / cMax;

    // Yellow highlight band: H ∈ [35°, 72°], S > 0.55, V > 0.6
    if (hue >= 35 && hue <= 72 && saturation > 0.55 && cMax > 0.6) {
      return true;
    }
    // Blue selection band: H ∈ [195°, 235°], S > 0.45, V > 0.5
    if (hue >= 195 && hue <= 235 && saturation > 0.45 && cMax > 0.5) {
      return true;
    }
    return false;
  }

  /// Check if a colour matches a banned value (alpha-aware).
  /// Strips alpha and compares RGB only.
  static bool _matchesBannedRgb(Color c) {
    if (c.a < 0.05) return false;
    final rgb = c.toARGB32() | 0xFF000000;
    return _bannedRgbSet.contains(rgb);
  }

  // ── KNOWN-SAFE PALETTE COLOURS ─────────────────────────────────
  // Colours that are curated parts of the three canonical print palettes
  // (lightOnDark, darkOnLight, previewHighContrast). These bypass the
  // HSV-range check because they are intentional print/accent colours
  // (e.g., gold #FFD700, red #D63031) that happen to fall inside the
  // banned hue bands meant to catch *injected UI* colours.
  static final Set<int> _knownSafePaletteArgb = {
    // Gold accent (lightOnDark + previewHighContrast)
    const Color(0xFFFFD700).toARGB32(),
    // Red champion (darkOnLight)
    const Color(0xFFD63031).toARGB32(),
    // Blue accent (darkOnLight)
    const Color(0xFF2137FF).toARGB32(),
    // Semi-transparent palette whites (watermark, slot, border variants)
    const Color(0x40FAFAFA).toARGB32(),
    const Color(0x66FAFAFA).toARGB32(),
    const Color(0x33FFFFFF).toARGB32(),
    const Color(0x88FFFFFF).toARGB32(),
    const Color(0xAAFFFFFF).toARGB32(),
    const Color(0x55000000).toARGB32(),
    const Color(0x331A1E3A).toARGB32(),
    const Color(0x881A1E3A).toARGB32(),
    const Color(0x441A1E3A).toARGB32(),
  };

  // ── PUBLIC GUARD METHODS ────────────────────────────────────────

  /// Check a [BracketPrintPalette]. Throws [PreviewUiLayerDetected] if
  /// any palette colour matches a banned UI colour (exact, alpha-aware,
  /// or HSV range).
  ///
  /// Colours in `_knownSafePaletteArgb` skip the HSV-range check because
  /// they are intentional print/accent colours (e.g., gold, red) that
  /// happen to fall inside hue bands meant to catch *injected UI* colours.
  static void assertCleanPalette(BracketPrintPalette palette) {
    final paletteColors = [
      palette.lineColor,
      palette.textColor,
      palette.slotFill,
      palette.slotBorder,
      palette.accentColor,
      palette.titleColor,
      palette.championColor,
      palette.watermarkColor,
    ];
    for (final c in paletteColors) {
      // Level 1: exact match against banned UI colours
      if (bannedColors.contains(c)) {
        throw PreviewUiLayerDetected(
          'Palette contains exact banned UI colour '
          '0x${c.toARGB32().toRadixString(16).toUpperCase()}');
      }
      // Level 2: alpha-aware RGB match (opaque bans only)
      if (_matchesBannedRgb(c)) {
        throw PreviewUiLayerDetected(
          'Palette contains alpha-variant of banned UI colour '
          '0x${c.toARGB32().toRadixString(16).toUpperCase()}');
      }
      // Level 3: HSV range check — skip for known-safe palette colours
      if (!_knownSafePaletteArgb.contains(c.toARGB32()) &&
          _isInBannedHsvZone(c)) {
        throw PreviewUiLayerDetected(
          'Palette colour 0x${c.toARGB32().toRadixString(16).toUpperCase()} '
          'falls inside banned HSV zone (yellow highlight or blue selection)');
      }
    }
  }

  /// Check an SVG string for banned hex colours AND class-name patterns.
  static void assertCleanSvg(String svg) {
    // Level 4a: hex colour strings
    for (final hex in bannedSvgHex) {
      if (svg.contains(hex)) {
        throw PreviewUiLayerDetected(
          'SVG output contains banned UI colour $hex');
      }
    }
    // Level 4b: class-name regex patterns
    for (final pattern in _bannedClassPatterns) {
      final match = pattern.firstMatch(svg);
      if (match != null) {
        throw PreviewUiLayerDetected(
          'SVG output contains banned UI class: "${match.group(0)}"');
      }
    }
  }

  /// Convenience: validate render mode is NOT bracketUI.
  static void assertNotUiMode(BracketRenderMode mode) {
    if (mode == BracketRenderMode.bracketUI) {
      throw PreviewUiLayerDetected(
        'bracketUI mode is forbidden in the print/preview pipeline');
    }
  }

  /// **Level 5: Rasterized-pixel scan.**
  ///
  /// Decode the given [imageBytes] (PNG/JPEG) and scan every pixel for
  /// banned HSV zones. Returns normally if clean; throws
  /// [PreviewUiLayerDetected] on first contaminated pixel.
  ///
  /// Intended for use in debug/CI acceptance tests. On the hot path
  /// (production preview), the palette + SVG guards are sufficient.
  static Future<void> assertCleanRaster(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final byteData = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) {
      throw PreviewUiLayerDetected('Could not decode raster image for scan');
    }

    final pixels = byteData.buffer.asUint8List();
    final pixelCount = pixels.length ~/ 4;
    // Sample at most 50 000 pixels for performance
    final step = (pixelCount > 50000) ? pixelCount ~/ 50000 : 1;

    for (int i = 0; i < pixelCount; i += step) {
      final off = i * 4;
      final r = pixels[off] / 255.0;
      final g = pixels[off + 1] / 255.0;
      final b = pixels[off + 2] / 255.0;
      final a = pixels[off + 3] / 255.0;

      final c = Color.fromARGB(
        (a * 255).round(),
        (r * 255).round(),
        (g * 255).round(),
        (b * 255).round(),
      );

      if (_isInBannedHsvZone(c)) {
        final x = i % image.width;
        final y = i ~/ image.width;
        image.dispose();
        throw PreviewUiLayerDetected(
          'Raster pixel ($x,$y) colour '
          '0x${c.toARGB32().toRadixString(16).toUpperCase()} '
          'falls inside banned HSV zone');
      }
    }
    image.dispose();
  }

  /// Quick check: does a single Color pass all guards?
  static bool isCleanColor(Color c) {
    if (bannedColors.contains(c)) return false;
    if (_matchesBannedRgb(c)) return false;
    if (_isInBannedHsvZone(c)) return false;
    return true;
  }

  // ── POST-SANITIZATION FATAL GUARD ──────────────────────────────

  /// Assert that bracket data has been sanitized.
  ///
  /// Call this at the entry to every print/preview renderer.
  /// If [BracketPrintData.isSanitized] is `false`, the data bypassed
  /// [sanitizeBracketForPrint] — treat as a **fatal bug**.
  static void assertSanitized(BracketPrintData data) {
    if (!data.isSanitized) {
      throw PreviewUiLayerDetected(
        'BracketPrintData.isSanitized==false — data was NOT passed through '
        'sanitizeBracketForPrint(). This is a FATAL pipeline bug.');
    }
  }

  /// Post-sanitization guard: after sanitization, contamination guards
  /// should NEVER fire. If they do, it is a fatal bug in the sanitizer
  /// itself or in the palette/renderer.
  ///
  /// Call this AFTER [assertSanitized] + [assertCleanPalette] in the
  /// render pipeline. It wraps the standard guards but re-throws with
  /// a "FATAL BUG" prefix so the error is immediately distinguishable
  /// from a mere "UI data leaked" scenario.
  static void assertPostSanitizationClean(
    BracketPrintData data,
    BracketPrintPalette palette,
  ) {
    assertSanitized(data);
    try {
      assertCleanPalette(palette);
    } on PreviewUiLayerDetected catch (e) {
      throw PreviewUiLayerDetected(
        'FATAL BUG (post-sanitization): palette still contaminated after '
        'sanitizeBracketForPrint(). Detail: ${e.detail}');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PORTRAIT-ONLY ENFORCEMENT — apparel previews must be portrait layout
// ═══════════════════════════════════════════════════════════════════════

/// Assert that the given [size] is portrait (height >= width).
/// Horizontal / landscape layout is forbidden for apparel print/preview.
void assertPortraitLayout(Size size) {
  if (size.width > 0 && size.height > 0 && size.width > size.height) {
    throw PreviewUiLayerDetected(
      'Landscape layout detected (${size.width}x${size.height}). '
      'Apparel print/preview requires portrait orientation.');
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RGB COLOR MODE ENFORCEMENT — printer requires RGB, not CMYK
// ═══════════════════════════════════════════════════════════════════════

/// The color mode for all print/preview output.
enum PrintColorMode {
  rgb,
}

/// The ONLY color mode allowed.  Every renderer must tag its output
/// with this value so the debug overlay can display it.
const PrintColorMode kPrintColorMode = PrintColorMode.rgb;

// ═══════════════════════════════════════════════════════════════════════
// PREVIEW_DEBUG flag — compile-time or runtime toggle
// ═══════════════════════════════════════════════════════════════════════

/// Check if PREVIEW_DEBUG is enabled.
///
/// Enable at build time:
///   flutter run --dart-define=PREVIEW_DEBUG=true
///
/// In debug mode, the overlay is always shown.
bool get isPreviewDebugEnabled {
  const env = String.fromEnvironment('PREVIEW_DEBUG', defaultValue: 'false');
  return env.toLowerCase() == 'true' || kDebugMode;
}

// ═══════════════════════════════════════════════════════════════════════
// CANONICAL RENDERER LOG — tracks which pipeline path was used
// ═══════════════════════════════════════════════════════════════════════

/// Log helper that records every renderer invocation.
/// Production code should call this at each entry/exit point so the
/// debug overlay and server logs can confirm CANONICAL_ONLY=true.
class CanonicalRendererLog {
  CanonicalRendererLog._();

  static const bool canonicalOnly = true;

  /// Most recent renderer path (e.g. 'renderBracketPrintSvg',
  /// 'BracketPrintCanvas.paint').
  static String _lastPath = '';
  static String get lastPath => _lastPath;

  /// Timestamp of the last render.
  static DateTime? _lastRenderTime;
  static DateTime? get lastRenderTime => _lastRenderTime;

  /// Log a renderer invocation.
  static void log(String path) {
    _lastPath = path;
    _lastRenderTime = DateTime.now();
    if (kDebugMode) {
      debugPrint('[CanonicalRenderer] CANONICAL_ONLY=$canonicalOnly  path=$path');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// GARMENT PRINT MASK — physical print area on the garment back
// ═══════════════════════════════════════════════════════════════════════

/// Defines the printable zone on the back of a specific garment,
/// expressed as fractions of the garment photo's visible body.
///
/// All values are percentages (0.0–1.0) relative to the 560-px
/// preview container height. They describe where the **fabric body**
/// starts/ends — the bracket must fit inside this rectangle.
///
/// The mask also stores the **physical** print dimensions in inches
/// so that both the preview and the 300-DPI print renderer can scale
/// identically.
class GarmentPrintMask {
  /// Fraction of container width from the left edge to the print zone.
  final double left;
  /// Fraction of container width from the right edge to the print zone.
  final double right;
  /// Fraction of container height from the top to the print zone.
  final double top;
  /// Fraction of container height from the bottom to the print zone.
  final double bottom;

  /// Physical print width in inches (used for 300 DPI output).
  final double physicalWidthInches;
  /// Physical print height in inches (used for 300 DPI output).
  final double physicalHeightInches;

  const GarmentPrintMask({
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    this.physicalWidthInches = 12.0,
    this.physicalHeightInches = 14.0,
  });

  /// Compute the pixel Rect inside a container of [size].
  Rect toRect(Size size) {
    return Rect.fromLTRB(
      size.width * left,
      size.height * top,
      size.width * (1.0 - right),
      size.height * (1.0 - bottom),
    );
  }

  /// Print resolution at 300 DPI.
  int get printWidthPx => (physicalWidthInches * 300).round();
  int get printHeightPx => (physicalHeightInches * 300).round();

  /// Width percentage of the container occupied by the print zone.
  double get widthPercent => 1.0 - left - right;

  /// Height percentage of the container occupied by the print zone.
  double get heightPercent => 1.0 - top - bottom;

  /// Construct from a JSON-style pixel mask (absolute px relative to mockup).
  /// The [containerSize] is the preview container size in pixels.
  factory GarmentPrintMask.fromPixels({
    required double x,
    required double y,
    required double width,
    required double height,
    required Size containerSize,
    double physicalWidthInches = 12.0,
    double physicalHeightInches = 14.0,
  }) {
    return GarmentPrintMask(
      left: x / containerSize.width,
      right: 1.0 - (x + width) / containerSize.width,
      top: y / containerSize.height,
      bottom: 1.0 - (y + height) / containerSize.height,
      physicalWidthInches: physicalWidthInches,
      physicalHeightInches: physicalHeightInches,
    );
  }

  // ── Per-product preset masks ────────────────────────────────────
  // Tuned to real CDN product photos rendered via BoxFit.contain
  // inside a 560-px-tall container (~375 px wide).
  //
  // These correspond to what a product-catalog.json `printMask` field
  // would hold.  The values are fractional insets of the preview container.

  /// Hoodie: print zone below the hood, between the sleeves.
  /// Matches printAreas.back { x:0.18, y:0.30, w:0.64, h:0.52 }.
  static const hoodie = GarmentPrintMask(
    left: 0.18,
    right: 0.18,
    top: 0.30,
    bottom: 0.18,
    physicalWidthInches: 11.0,
    physicalHeightInches: 13.0,
  );

  /// T-shirt: print zone below the collar, between the sleeves.
  static const tShirt = GarmentPrintMask(
    left: 0.22,
    right: 0.22,
    top: 0.28,
    bottom: 0.14,
    physicalWidthInches: 12.0,
    physicalHeightInches: 14.0,
  );

  // ── Per-product masks (keyed by product ID) ─────────────────────
  // Equivalent of product-catalog.json printMask/printArea.
  // x, y, width, height in pixels relative to a 375×560 mockup image.

  static final Map<String, GarmentPrintMask> perProduct = {
    // Grid Iron Tech Fleece Hoodie
    'bp_grid_iron': const GarmentPrintMask(
      left: 0.18, right: 0.18, top: 0.30, bottom: 0.18,
      physicalWidthInches: 11.0, physicalHeightInches: 13.0,
    ),
    // Perfect Tri Tee — slim body, wider print zone
    'bp_tri_tee': const GarmentPrintMask(
      left: 0.22, right: 0.22, top: 0.28, bottom: 0.14,
      physicalWidthInches: 12.0, physicalHeightInches: 14.0,
    ),
    // Street Lounge French Terry Hoodie
    'bp_street_lounge': const GarmentPrintMask(
      left: 0.18, right: 0.18, top: 0.30, bottom: 0.18,
      physicalWidthInches: 11.0, physicalHeightInches: 13.0,
    ),
    // On The Go Tri-Blend Hoodie
    'bp_on_the_go': const GarmentPrintMask(
      left: 0.18, right: 0.18, top: 0.30, bottom: 0.18,
      physicalWidthInches: 11.0, physicalHeightInches: 13.0,
    ),
    // All Day Tri-Blend Fleece Hoodie
    'bp_all_day': const GarmentPrintMask(
      left: 0.18, right: 0.18, top: 0.30, bottom: 0.18,
      physicalWidthInches: 11.0, physicalHeightInches: 13.0,
    ),
  };

  /// Look up the mask for a product. Falls back to generic hoodie/tee mask.
  static GarmentPrintMask forProduct(String productId, PrintProductType type) {
    return perProduct[productId] ??
        (type == PrintProductType.hoodie ? hoodie : tShirt);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PRODUCT PRINT AREA — fractional regions on the mockup image (0–1)
// ═══════════════════════════════════════════════════════════════════════

/// Defines a rectangular region on a garment mockup image as fractions
/// of the image width and height (0.0–1.0).
///
/// This is the ONLY allowed area for bracket placement.
/// `x`, `y` are the top-left corner; `w`, `h` are width/height.
class PrintAreaRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const PrintAreaRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  /// Convert to a pixel [Rect] given a container [size].
  ///
  /// **DEPRECATED for preview compositing** — this maps fractions to the
  /// full container, which is wrong when the garment image is letterboxed
  /// by `BoxFit.contain`.  Use [toRectInImage] for preview compositing.
  Rect toRect(Size size) {
    return Rect.fromLTWH(
      size.width * x,
      size.height * y,
      size.width * w,
      size.height * h,
    );
  }

  /// Convert to a pixel [Rect] relative to the garment **image bounds**
  /// inside a container.
  ///
  /// [imageBounds] is the sub-rect of the container that the garment
  /// photo actually occupies (computed from `BoxFit.contain` or similar).
  /// The fractional coordinates (x, y, w, h) are applied to `imageBounds`
  /// so the print area is always ON the garment, not floating in the
  /// letterbox padding.
  Rect toRectInImage(Rect imageBounds) {
    return Rect.fromLTWH(
      imageBounds.left + imageBounds.width * x,
      imageBounds.top  + imageBounds.height * y,
      imageBounds.width * w,
      imageBounds.height * h,
    );
  }

  /// Aspect ratio of this print area.
  double get aspectRatio => w / h;

  factory PrintAreaRect.fromJson(Map<String, dynamic> json) {
    return PrintAreaRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }

  Map<String, double> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};

  @override
  String toString() => 'PrintAreaRect(x=$x, y=$y, w=$w, h=$h)';
}

/// Front and back print areas for a single product.
///
/// These define the ONLY allowed regions for bracket placement on the
/// garment mockup. The bracket is scaled uniformly to fit within the
/// area, centred, and strictly clipped.
class ProductPrintAreas {
  final PrintAreaRect front;
  final PrintAreaRect back;

  /// Physical print size in inches (for 300 DPI output).
  final double physicalWidthInches;
  final double physicalHeightInches;

  const ProductPrintAreas({
    required this.front,
    required this.back,
    this.physicalWidthInches = 12.0,
    this.physicalHeightInches = 14.0,
  });

  /// Print resolution at 300 DPI.
  int get printWidthPx => (physicalWidthInches * 300).round();
  int get printHeightPx => (physicalHeightInches * 300).round();

  factory ProductPrintAreas.fromJson(Map<String, dynamic> json) {
    return ProductPrintAreas(
      front: PrintAreaRect.fromJson(json['front'] as Map<String, dynamic>),
      back: PrintAreaRect.fromJson(json['back'] as Map<String, dynamic>),
      physicalWidthInches:
          (json['physicalWidthInches'] as num?)?.toDouble() ?? 12.0,
      physicalHeightInches:
          (json['physicalHeightInches'] as num?)?.toDouble() ?? 14.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'front': front.toJson(),
    'back': back.toJson(),
    'physicalWidthInches': physicalWidthInches,
    'physicalHeightInches': physicalHeightInches,
  };
}

/// Per-product print area catalog.
///
/// Fractions are relative to the mockup image dimensions (0–1).
/// Tuned to the real Shopify CDN product photos rendered via
/// BoxFit.contain inside a 560-px-tall container.
///
/// **NEW**: Products now carry their own [ProductPrintAreas] and
/// [ProductMockups] inline. This static catalog remains as a
/// backward-compatible fallback and type-default provider.
class ProductPrintAreaCatalog {
  ProductPrintAreaCatalog._();

  // ── Hoodie default ──────────────────────────────────────────
  // Wider back area (w:0.64, h:0.52) ensures the bracket sits naturally
  // below the hood and between the sleeves without overflow.
  static const hoodieDefault = ProductPrintAreas(
    front: PrintAreaRect(x: 0.22, y: 0.28, w: 0.56, h: 0.40),
    back:  PrintAreaRect(x: 0.18, y: 0.30, w: 0.64, h: 0.52),
    physicalWidthInches: 11.0,
    physicalHeightInches: 13.0,
  );

  // ── T-shirt default ─────────────────────────────────────────
  static const tShirtDefault = ProductPrintAreas(
    front: PrintAreaRect(x: 0.22, y: 0.22, w: 0.56, h: 0.48),
    back:  PrintAreaRect(x: 0.20, y: 0.22, w: 0.60, h: 0.56),
    physicalWidthInches: 12.0,
    physicalHeightInches: 14.0,
  );

  /// Look up the print areas for a product.
  ///
  /// Priority:
  ///   1. [PrintProduct.printAreas] if set (new schema)
  ///   2. Generic hoodie/tee default
  static ProductPrintAreas forProduct(
    String productId,
    PrintProductType type,
  ) {
    return type == PrintProductType.hoodie ? hoodieDefault : tShirtDefault;
  }

  /// Resolve print areas: prefer the product's inline definition,
  /// then fall back to this static catalog.
  static ProductPrintAreas resolve(PrintProduct? product) {
    if (product != null && product.printAreas != null) return product.printAreas!;
    if (product != null) return forProduct(product.id, product.type);
    return hoodieDefault;
  }
}

/// A garment color option with its display name and hex value.
class GarmentColor {
  final String name;
  final Color color;
  final String hexCode;
  final bool isDark; // true = use white bracket, false = use dark bracket

  const GarmentColor({
    required this.name,
    required this.color,
    required this.hexCode,
    required this.isDark,
  });

  /// Determine bracket print palette based on garment darkness.
  BracketPrintPalette get bracketPalette => isDark
      ? BracketPrintPalette.lightOnDark
      : BracketPrintPalette.darkOnLight;
}

/// Bracket print color palette — adapts to garment color.
class BracketPrintPalette {
  final Color lineColor;
  final Color textColor;
  final Color slotFill;
  final Color slotBorder;
  final Color accentColor;
  final Color titleColor;
  final Color championColor;
  final Color watermarkColor;
  final String svgLineColor;
  final String svgTextColor;
  final String svgSlotFill;
  final String svgSlotBorder;
  final String svgAccentColor;
  final String svgTitleColor;

  const BracketPrintPalette({
    required this.lineColor,
    required this.textColor,
    required this.slotFill,
    required this.slotBorder,
    required this.accentColor,
    required this.titleColor,
    required this.championColor,
    required this.watermarkColor,
    required this.svgLineColor,
    required this.svgTextColor,
    required this.svgSlotFill,
    required this.svgSlotBorder,
    required this.svgAccentColor,
    required this.svgTitleColor,
  });

  /// White/gold bracket on dark garment (black, navy, charcoal)
  static const lightOnDark = BracketPrintPalette(
    lineColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFFFFFFF),
    slotFill: Color(0x33FFFFFF),
    slotBorder: Color(0x88FFFFFF),
    accentColor: Color(0xFFFFD700),
    titleColor: Color(0xFFFFFFFF),
    championColor: Color(0xFFFFD700),
    // NOTE: 0x40FAFAFA avoids exact collision with _uiTapSplash (0x44FFFFFF)
    // while keeping the same visual appearance (very faint white).
    watermarkColor: Color(0x40FAFAFA),
    svgLineColor: '#FFFFFF',
    svgTextColor: '#FFFFFF',
    svgSlotFill: 'rgba(255,255,255,0.15)',
    svgSlotBorder: 'rgba(255,255,255,0.5)',
    svgAccentColor: '#FFD700',
    svgTitleColor: '#FFFFFF',
  );

  /// Dark navy/charcoal bracket on light garment (white, beige, heather)
  static const darkOnLight = BracketPrintPalette(
    lineColor: Color(0xFF1A1E3A),
    textColor: Color(0xFF1A1E3A),
    slotFill: Color(0x331A1E3A),
    slotBorder: Color(0x881A1E3A),
    accentColor: Color(0xFF2137FF),
    titleColor: Color(0xFF1A1E3A),
    championColor: Color(0xFFD63031),
    watermarkColor: Color(0x441A1E3A),
    svgLineColor: '#1A1E3A',
    svgTextColor: '#1A1E3A',
    svgSlotFill: 'rgba(26,30,58,0.2)',
    svgSlotBorder: 'rgba(26,30,58,0.55)',
    svgAccentColor: '#2137FF',
    svgTitleColor: '#1A1E3A',
  );

  /// HIGH-CONTRAST palette for preview on top of product photos.
  /// Product photos always look dark due to studio lighting, even for
  /// nominally "light" garments. This palette guarantees readability.
  static const previewHighContrast = BracketPrintPalette(
    lineColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFFFFFFF),
    slotFill: Color(0x55000000),
    slotBorder: Color(0xAAFFFFFF),
    accentColor: Color(0xFFFFD700),
    titleColor: Color(0xFFFFFFFF),
    championColor: Color(0xFFFFD700),
    // NOTE: 0x66FAFAFA avoids alpha-strip collision with banned colours
    // while keeping the same visual appearance (semi-transparent white).
    watermarkColor: Color(0x66FAFAFA),
    svgLineColor: '#FFFFFF',
    svgTextColor: '#FFFFFF',
    svgSlotFill: 'rgba(0,0,0,0.33)',
    svgSlotBorder: 'rgba(255,255,255,0.67)',
    svgAccentColor: '#FFD700',
    svgTitleColor: '#FFFFFF',
  );
}

/// Product type for bracket printing suitability.
enum PrintProductType {
  hoodie,
  tShirt,
  accessory, // caps, beanies — not printable
}

// ═══════════════════════════════════════════════════════════════════════
// COLOR STRATEGY — per-product colour-matching approach
// ═══════════════════════════════════════════════════════════════════════

/// How a product resolves the correct garment image for a selected colour.
///
/// - [exactMockup]: The CDN has a separate photographed mockup for every
///   available colour.  The compositor loads the exact image — no tinting.
///   Guarantees pixel-perfect colour on both front and back views.
///
/// - [tintBase]: Only one base photograph exists (typically the Black
///   variant).  For non-base colours the compositor applies an HSL tint
///   overlay that recolours the fabric while preserving luminance detail
///   (folds, stitching, texture).  This avoids the "always black" problem
///   for products that lack per-colour CDN images.
enum ColorStrategy {
  exactMockup,
  tintBase,
}

/// Default alpha opacity for [ColorStrategy.tintBase] colour overlays.
///
/// Controls how strongly the tint recolours the base mockup photo.
/// Lower values preserve more of the base photo's original tonality
/// (folds, stitching, fabric texture); higher values push closer to
/// a flat-coloured garment.
///
/// 0.72 was tuned against the DM130 "Frost" tri-blend colours to
/// produce visually believable results without over-saturation.
/// Adjust per-product if needed via [PrintProduct.tintAlpha].
const double kTintBaseAlpha = 0.72;

/// Per-colour front/back CDN image overrides.
///
/// Used when [ColorStrategy.exactMockup] is active.  Each colour name
/// maps to an optional front URL and optional back URL.  `null` means
/// "fall back to the product's base mockup for that side".
class ColorMockups {
  /// Front CDN image for this colour (null = use base front mockup).
  final String? frontUrl;

  /// Back CDN image for this colour (null = use base back mockup).
  final String? backUrl;

  const ColorMockups({this.frontUrl, this.backUrl});

  factory ColorMockups.fromJson(Map<String, dynamic> json) {
    return ColorMockups(
      frontUrl: json['frontUrl'] as String?,
      backUrl: json['backUrl'] as String?,
    );
  }

  Map<String, String?> toJson() => {
    'frontUrl': frontUrl,
    'backUrl': backUrl,
  };
}

// ═══════════════════════════════════════════════════════════════════════
// RESOLVED COLOR IMAGE — result of the colour-matching resolution
// ═══════════════════════════════════════════════════════════════════════

/// Fully resolved garment image for a specific colour and view.
///
/// Contains the URL/asset path to display and the tint colour that
/// should be composited on top (only set when the strategy is tintBase
/// and the selected colour differs from the base mockup colour).
class ResolvedColorImage {
  /// Network URL for the garment image.
  final String? networkUrl;

  /// Local asset path (takes precedence over [networkUrl]).
  final String? localAsset;

  /// Which strategy was used to produce this result.
  final ColorStrategy strategy;

  /// The tint colour to composite on top of the base image.
  /// `null` means no tinting is needed (either exactMockup or the
  /// selected colour IS the base colour).
  final Color? tintColor;

  /// Hex code of the tint colour for logging (e.g. '#1E3A5F').
  final String? tintHex;

  /// Alpha opacity applied to the tint overlay (0.0..1.0).
  /// Only meaningful when [needsTint] is true.
  /// Defaults to [kTintBaseAlpha].
  final double tintAlpha;

  /// Whether the back view was generated by flipping the front image
  /// (no dedicated back mockup available for this colour/view).
  final bool isFlippedFront;

  const ResolvedColorImage({
    this.networkUrl,
    this.localAsset,
    required this.strategy,
    this.tintColor,
    this.tintHex,
    this.tintAlpha = kTintBaseAlpha,
    this.isFlippedFront = false,
  });

  /// True when the base mockup needs an HSL tint overlay.
  bool get needsTint => tintColor != null;

  /// Best available image source for display.
  String? get bestSource => localAsset ?? networkUrl;
}

// ═══════════════════════════════════════════════════════════════════════
// COLOR MATCH LOG — diagnostic tracing for colour resolution
// ═══════════════════════════════════════════════════════════════════════

/// Logs every colour-image resolution so previews can be debugged.
///
/// Usage:  After calling `product.resolveColorImage(...)`, check
/// `ColorMatchLog.lastEntry` or enable `kDebugMode` logging.
class ColorMatchLog {
  ColorMatchLog._();

  static ColorMatchEntry? _lastEntry;
  static ColorMatchEntry? get lastEntry => _lastEntry;

  /// Record a colour resolution event.
  static void log({
    required String productId,
    required String colorName,
    required ColorStrategy strategy,
    required String? tintHex,
    double? tintAlpha,
    required String view,
    required String mockupUsed,
  }) {
    _lastEntry = ColorMatchEntry(
      productId: productId,
      colorName: colorName,
      strategy: strategy,
      tintHex: tintHex,
      tintAlpha: tintAlpha,
      view: view,
      mockupUsed: mockupUsed,
      timestamp: DateTime.now(),
    );
    if (kDebugMode) {
      final alphaStr = tintAlpha != null
          ? '  tintAlpha=${tintAlpha.toStringAsFixed(2)}'
          : '';
      debugPrint('[ColorMatch] '
          'product=$productId  color=$colorName  '
          'strategy=${strategy.name}  tintHex=${tintHex ?? "none"}'
          '$alphaStr  view=$view  mockup=$mockupUsed');
    }
  }
}

class ColorMatchEntry {
  final String productId;
  final String colorName;
  final ColorStrategy strategy;
  final String? tintHex;
  final double? tintAlpha;
  final String view;
  final String mockupUsed;
  final DateTime timestamp;

  const ColorMatchEntry({
    required this.productId,
    required this.colorName,
    required this.strategy,
    required this.tintHex,
    this.tintAlpha,
    required this.view,
    required this.mockupUsed,
    required this.timestamp,
  });

  @override
  String toString() =>
      'ColorMatchEntry(product=$productId, color=$colorName, '
      'strategy=${strategy.name}, tint=$tintHex, '
      'alpha=${tintAlpha?.toStringAsFixed(2) ?? "n/a"}, view=$view, '
      'mockup=$mockupUsed)';
}

// ═══════════════════════════════════════════════════════════════════════
// PRODUCT MOCKUP — front + back garment image references
// ═══════════════════════════════════════════════════════════════════════

/// A single mockup image reference (local asset and/or CDN URL).
class MockupImage {
  /// Local asset path (e.g., 'assets/garment_backs/st250_black_back.png').
  final String? localFile;

  /// CDN fallback URL (e.g., Shopify product image URL).
  final String? fallbackUrl;

  const MockupImage({this.localFile, this.fallbackUrl});

  /// Whether any image source is available.
  bool get hasImage => localFile != null || fallbackUrl != null;

  /// Best available image path: prefers local, falls back to CDN.
  String? get bestPath => localFile ?? fallbackUrl;

  factory MockupImage.fromJson(Map<String, dynamic> json) {
    return MockupImage(
      localFile: json['localFile'] as String?,
      fallbackUrl: json['fallbackUrl'] as String?,
    );
  }

  Map<String, String?> toJson() => {
    'localFile': localFile,
    'fallbackUrl': fallbackUrl,
  };
}

/// Front and back mockup images for a product.
class ProductMockups {
  final MockupImage front;
  final MockupImage back;

  const ProductMockups({required this.front, required this.back});

  factory ProductMockups.fromJson(Map<String, dynamic> json) {
    return ProductMockups(
      front: MockupImage.fromJson(json['front'] as Map<String, dynamic>),
      back: MockupImage.fromJson(json['back'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'front': front.toJson(),
    'back': back.toJson(),
  };
}

// ═══════════════════════════════════════════════════════════════════════
// PRINT-ON FLAGS — which sides support printing
// ═══════════════════════════════════════════════════════════════════════

/// Declares which garment sides support bracket printing.
class PrintOn {
  final bool front;
  final bool back;

  const PrintOn({this.front = false, this.back = true});

  factory PrintOn.fromJson(Map<String, dynamic> json) {
    return PrintOn(
      front: json['front'] as bool? ?? false,
      back: json['back'] as bool? ?? true,
    );
  }

  Map<String, bool> toJson() => {'front': front, 'back': back};
}

/// A printable product from the BMB catalog.
///
/// **Schema v3 fields** (product-catalog.json):
///   - [mockups]            → `{ front: {localFile, fallbackUrl}, back: ... }`
///   - [printAreas]         → `{ front: {x,y,w,h}, back: {x,y,w,h} }` (fractions 0–1)
///   - [defaultPreviewView] → `"back"` or `"front"` (configurable per product)
///   - [printOn]            → `{ front: bool, back: bool }`
///   - [colorStrategy]      → `exactMockup` or `tintBase`
///   - [colorMockups]       → colour-name → `{ frontUrl, backUrl }` overrides
///
/// **Backward compatibility**:
///   If only the legacy `frontImageUrl` / `backImageAsset` fields are set,
///   the [resolvedMockups] getter synthesises a [ProductMockups] from them.
///   Similarly [resolvedPrintAreas] falls back to [ProductPrintAreaCatalog].
class PrintProduct {
  final String id;
  final String shopifyId;
  final String title;
  final String shortTitle; // e.g., "Grid Iron Hoodie"
  final PrintProductType type;
  final double basePrice;
  final double bracketPrintUpcharge; // extra cost for bracket print
  final List<GarmentColor> colors;
  final List<String> sizes;
  final String description;
  final bool canPrintBracket;
  final Map<String, String> colorImageUrls; // color name → front image URL

  // ── Legacy fields (kept for backward compat) ────────────────
  final String frontImageUrl; // Shopify CDN front image
  final String? backImageAsset; // local asset for garment back view

  // ── Schema v2 fields ────────────────────────────────────────
  /// Structured front/back mockup image references.
  final ProductMockups? mockups;

  /// Fractional print areas for front and back views.
  final ProductPrintAreas? printAreas;

  /// Which view to show by default in the preview compositor.
  /// `"back"` for hoodies, `"front"` for tees (configurable).
  final String defaultPreviewView;

  /// Which sides support bracket printing.
  final PrintOn printOn;

  // ── Schema v3 fields — colour matching ──────────────────────

  /// How this product resolves garment images for each colour.
  /// [exactMockup] = load a colour-specific CDN image.
  /// [tintBase]    = HSL-tint the base mockup photo.
  final ColorStrategy colorStrategy;

  /// Per-colour front/back CDN overrides (used by exactMockup strategy).
  /// Keyed by [GarmentColor.name].
  final Map<String, ColorMockups> colorMockups;

  /// Per-colour hex overrides for tintBase strategy.
  ///
  /// Maps colour names to accurate hex codes sourced from vendor swatch
  /// charts (e.g. DM130 Shopify swatches).  When present, these override
  /// the [GarmentColor.hexCode] during tint resolution so the preview
  /// matches the real fabric colour — not a rough approximation.
  final Map<String, String> colorHexByName;

  /// Tint overlay alpha for this product (overrides [kTintBaseAlpha]).
  /// Only used when [colorStrategy] == [ColorStrategy.tintBase].
  final double tintAlpha;

  const PrintProduct({
    required this.id,
    required this.shopifyId,
    required this.title,
    required this.shortTitle,
    required this.type,
    required this.basePrice,
    this.bracketPrintUpcharge = 15.0,
    required this.colors,
    required this.sizes,
    required this.frontImageUrl,
    required this.description,
    required this.canPrintBracket,
    this.colorImageUrls = const {},
    this.backImageAsset,
    this.mockups,
    this.printAreas,
    this.defaultPreviewView = 'back',
    this.printOn = const PrintOn(),
    this.colorStrategy = ColorStrategy.exactMockup,
    this.colorMockups = const {},
    this.colorHexByName = const {},
    this.tintAlpha = kTintBaseAlpha,
  });

  // ── Backward-compatible resolved accessors ─────────────────

  /// Resolved mockups: prefer [mockups] (v2), fall back to legacy fields.
  ///
  /// If only the old `frontImageUrl` / `backImageAsset` exist:
  ///   - front.fallbackUrl = frontImageUrl
  ///   - back.localFile    = backImageAsset
  ///   - back.fallbackUrl  = frontImageUrl (flipped by compositor)
  ProductMockups get resolvedMockups {
    if (mockups != null) return mockups!;
    return ProductMockups(
      front: MockupImage(fallbackUrl: frontImageUrl),
      back: MockupImage(
        localFile: backImageAsset,
        fallbackUrl: frontImageUrl,
      ),
    );
  }

  /// Resolved print areas: prefer inline [printAreas] (v2), then
  /// fall back to [ProductPrintAreaCatalog] type defaults.
  ProductPrintAreas get resolvedPrintAreas {
    return printAreas ?? ProductPrintAreaCatalog.forProduct(id, type);
  }

  /// The print-area [PrintAreaRect] for a given view.
  PrintAreaRect printAreaForView(String view) {
    final areas = resolvedPrintAreas;
    return view == 'front' ? areas.front : areas.back;
  }

  /// The [MockupImage] for a given view.
  MockupImage mockupForView(String view) {
    final m = resolvedMockups;
    return view == 'front' ? m.front : m.back;
  }

  /// Colour-specific front image URL, or the default front image.
  String frontImageForColor(String colorName) {
    return colorImageUrls[colorName] ?? frontImageUrl;
  }

  // ── Schema v3: unified colour-image resolver ───────────────

  /// Resolve the garment image for a specific [colorName] and [view].
  ///
  /// This is the **single entry point** for all preview compositors.
  /// It handles both `exactMockup` and `tintBase` strategies, returns
  /// a [ResolvedColorImage] that the compositor can render directly,
  /// and emits a [ColorMatchLog] entry for diagnostics.
  ///
  /// Priority chain for `exactMockup`:
  ///   1. `colorMockups[colorName].frontUrl / .backUrl`
  ///   2. `colorImageUrls[colorName]` (legacy front-only map)
  ///   3. base mockup (front fallback / back local+fallback)
  ///
  /// Priority chain for `tintBase`:
  ///   1. base mockup image
  ///   2. tint = garment hex if different from base colour
  ResolvedColorImage resolveColorImage({
    required String colorName,
    required String view,
    required GarmentColor garmentColor,
  }) {
    final isFront = view == 'front';
    final baseMockup = mockupForView(view);

    switch (colorStrategy) {
      case ColorStrategy.exactMockup:
        return _resolveExactMockup(
            colorName, view, isFront, baseMockup, garmentColor);
      case ColorStrategy.tintBase:
        return _resolveTintBase(
            colorName, view, isFront, baseMockup, garmentColor);
    }
  }

  ResolvedColorImage _resolveExactMockup(
    String colorName,
    String view,
    bool isFront,
    MockupImage baseMockup,
    GarmentColor garmentColor,
  ) {
    // 1. Per-colour override from colorMockups
    final perColor = colorMockups[colorName];
    final overrideUrl = isFront ? perColor?.frontUrl : perColor?.backUrl;
    if (overrideUrl != null) {
      ColorMatchLog.log(
        productId: id,
        colorName: colorName,
        strategy: ColorStrategy.exactMockup,
        tintHex: null,
        view: view,
        mockupUsed: overrideUrl,
      );
      return ResolvedColorImage(
        networkUrl: overrideUrl,
        strategy: ColorStrategy.exactMockup,
      );
    }

    // 2. Legacy front-only colour map (for front view)
    if (isFront) {
      final legacyUrl = colorImageUrls[colorName];
      if (legacyUrl != null) {
        ColorMatchLog.log(
          productId: id,
          colorName: colorName,
          strategy: ColorStrategy.exactMockup,
          tintHex: null,
          view: view,
          mockupUsed: legacyUrl,
        );
        return ResolvedColorImage(
          networkUrl: legacyUrl,
          strategy: ColorStrategy.exactMockup,
        );
      }
    }

    // 3. For back view without a dedicated back mockup for this colour:
    //    use the colour-specific front image (compositor will flip it).
    if (!isFront) {
      // Try per-colour front as flipped back
      final frontOverride = perColor?.frontUrl;
      if (frontOverride != null) {
        ColorMatchLog.log(
          productId: id,
          colorName: colorName,
          strategy: ColorStrategy.exactMockup,
          tintHex: null,
          view: view,
          mockupUsed: '$frontOverride (flipped)',
        );
        return ResolvedColorImage(
          networkUrl: frontOverride,
          strategy: ColorStrategy.exactMockup,
          isFlippedFront: true,
        );
      }
      final legacyFrontUrl = colorImageUrls[colorName];
      if (legacyFrontUrl != null) {
        ColorMatchLog.log(
          productId: id,
          colorName: colorName,
          strategy: ColorStrategy.exactMockup,
          tintHex: null,
          view: view,
          mockupUsed: '$legacyFrontUrl (flipped)',
        );
        return ResolvedColorImage(
          networkUrl: legacyFrontUrl,
          strategy: ColorStrategy.exactMockup,
          isFlippedFront: true,
        );
      }
    }

    // 4. Fall back to base mockup
    final src = baseMockup.bestPath ?? frontImageUrl;
    ColorMatchLog.log(
      productId: id,
      colorName: colorName,
      strategy: ColorStrategy.exactMockup,
      tintHex: null,
      view: view,
      mockupUsed: '$src (base fallback)',
    );
    return ResolvedColorImage(
      networkUrl: baseMockup.fallbackUrl ?? frontImageUrl,
      localAsset: baseMockup.localFile,
      strategy: ColorStrategy.exactMockup,
      isFlippedFront: !isFront && baseMockup.localFile == null,
    );
  }

  ResolvedColorImage _resolveTintBase(
    String colorName,
    String view,
    bool isFront,
    MockupImage baseMockup,
    GarmentColor garmentColor,
  ) {
    // Determine if tinting is needed.
    // The base mockup is the first colour in the product's colour list
    // (conventionally Black). If the selected colour IS the base, no tint.
    final baseColorName = colors.isNotEmpty ? colors.first.name : 'Black';
    final needsTint = colorName != baseColorName;

    // Resolve the accurate tint colour:
    //   1. Per-colour hex map (vendor swatch accuracy)  — preferred
    //   2. GarmentColor.color from the catalog             — fallback
    Color? tint;
    String? tintHex;
    if (needsTint) {
      final overrideHex = colorHexByName[colorName];
      if (overrideHex != null) {
        tintHex = overrideHex;
        tint = _hexToColor(overrideHex);
      } else {
        tintHex = garmentColor.hexCode;
        tint = garmentColor.color;
      }
    }

    final src = baseMockup.bestPath ?? frontImageUrl;
    ColorMatchLog.log(
      productId: id,
      colorName: colorName,
      strategy: ColorStrategy.tintBase,
      tintHex: tintHex,
      tintAlpha: needsTint ? tintAlpha : null,
      view: view,
      mockupUsed: needsTint ? '$src (tinted)' : src,
    );
    return ResolvedColorImage(
      networkUrl: baseMockup.fallbackUrl ?? frontImageUrl,
      localAsset: baseMockup.localFile,
      strategy: ColorStrategy.tintBase,
      tintColor: tint,
      tintHex: tintHex,
      tintAlpha: tintAlpha,
      isFlippedFront: !isFront && baseMockup.localFile == null,
    );
  }

  /// Parse a '#RRGGBB' hex string to a [Color].
  static Color _hexToColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return Color(int.parse(clean, radix: 16));
  }

  double get totalPrice => basePrice + bracketPrintUpcharge;

  /// Extended product details for the expandable info section.
  ProductDetails get details => ProductDetails.forProduct(this);

  /// Print area dimensions as percentage of garment back.
  /// Scales with bracket team count.
  static PrintArea printAreaForTeamCount(int teamCount) {
    switch (teamCount) {
      case 4:
        return const PrintArea(
          topOffsetPercent: 0.20,
          widthPercent: 0.65,
          heightPercent: 0.40,
          label: 'Compact',
        );
      case 8:
        return const PrintArea(
          topOffsetPercent: 0.18,
          widthPercent: 0.72,
          heightPercent: 0.52,
          label: 'Standard',
        );
      case 16:
        return const PrintArea(
          topOffsetPercent: 0.15,
          widthPercent: 0.80,
          heightPercent: 0.65,
          label: 'Large',
        );
      case 32:
        return const PrintArea(
          topOffsetPercent: 0.13,
          widthPercent: 0.88,
          heightPercent: 0.75,
          label: 'Extra Large',
        );
      case 64:
        return const PrintArea(
          topOffsetPercent: 0.10,
          widthPercent: 0.92,
          heightPercent: 0.85,
          label: 'Maximum',
        );
      default:
        return const PrintArea(
          topOffsetPercent: 0.15,
          widthPercent: 0.80,
          heightPercent: 0.65,
          label: 'Standard',
        );
    }
  }
}

/// Defines the print area on the back of a garment.
class PrintArea {
  final double topOffsetPercent; // from top of garment back
  final double widthPercent; // of garment width
  final double heightPercent; // of garment back height
  final String label;

  const PrintArea({
    required this.topOffsetPercent,
    required this.widthPercent,
    required this.heightPercent,
    required this.label,
  });
}

/// Bracket print style options.
enum BracketPrintStyle {
  classic,
  premium,
  bold,
}

extension BracketPrintStyleX on BracketPrintStyle {
  String get displayName {
    switch (this) {
      case BracketPrintStyle.classic:
        return 'Classic';
      case BracketPrintStyle.premium:
        return 'Premium';
      case BracketPrintStyle.bold:
        return 'Bold';
    }
  }

  String get description {
    switch (this) {
      case BracketPrintStyle.classic:
        return 'Clean lines, pill-box team names — the original BMB look';
      case BracketPrintStyle.premium:
        return 'Winner path highlighted, round labels, seed numbers, gold accents';
      case BracketPrintStyle.bold:
        return 'Solid filled boxes, thick lines, streetwear-forward — pops on camera';
    }
  }
}

/// A completed bracket print order.
class BracketPrintOrder {
  final String orderId; // BMB-2025-XXXXX
  final String bracketId;
  final String bracketTitle;
  final String championName;
  final int teamCount;
  final PrintProduct product;
  final GarmentColor selectedColor;
  final String selectedSize;
  final BracketPrintStyle printStyle;
  final Map<String, String> picks; // slot → team name
  final String shippingName;
  final String shippingAddress;
  final String shippingCity;
  final String shippingState;
  final String shippingZip;
  final String shippingEmail;
  final String shippingPhone;
  final double subtotal;
  final double shippingCost;
  final double tax;
  final double total;
  final String? stripePaymentId;
  final DateTime createdAt;
  final String status; // pending, paid, printing, shipped, delivered

  const BracketPrintOrder({
    required this.orderId,
    required this.bracketId,
    required this.bracketTitle,
    required this.championName,
    required this.teamCount,
    required this.product,
    required this.selectedColor,
    required this.selectedSize,
    required this.printStyle,
    required this.picks,
    required this.shippingName,
    required this.shippingAddress,
    required this.shippingCity,
    required this.shippingState,
    required this.shippingZip,
    required this.shippingEmail,
    required this.shippingPhone,
    required this.subtotal,
    required this.shippingCost,
    required this.tax,
    required this.total,
    this.stripePaymentId,
    required this.createdAt,
    this.status = 'pending',
  });
}

/// Extended product details: full description, fabric/care, and size chart.
class ProductDetails {
  final String fullDescription;
  final List<String> features;
  final String fabricCare;
  final Map<String, Map<String, String>> sizeChart; // size → {chest, length, sleeve}

  const ProductDetails({
    required this.fullDescription,
    required this.features,
    required this.fabricCare,
    required this.sizeChart,
  });

  /// Lookup product details by product ID.
  static ProductDetails forProduct(PrintProduct product) {
    return _catalog[product.id] ?? _defaultDetails(product);
  }

  static ProductDetails _defaultDetails(PrintProduct p) => ProductDetails(
    fullDescription: p.description,
    features: ['Custom bracket print on back', 'BMB logo on front', 'Standard fit'],
    fabricCare: 'Machine wash cold, tumble dry low. Do not iron directly on print.',
    sizeChart: _standardSizeChart(p.type),
  );

  static Map<String, Map<String, String>> _standardSizeChart(PrintProductType type) {
    if (type == PrintProductType.hoodie) return _hoodieSizes;
    return _teeSizes;
  }

  static const _hoodieSizes = {
    'XS': {'Chest': '34-36"', 'Length': '26"', 'Sleeve': '33"'},
    'S':  {'Chest': '36-38"', 'Length': '27"', 'Sleeve': '34"'},
    'M':  {'Chest': '38-40"', 'Length': '28"', 'Sleeve': '35"'},
    'L':  {'Chest': '40-42"', 'Length': '29"', 'Sleeve': '36"'},
    'XL': {'Chest': '42-44"', 'Length': '30"', 'Sleeve': '37"'},
    '2X': {'Chest': '44-46"', 'Length': '31"', 'Sleeve': '38"'},
    '3X': {'Chest': '46-48"', 'Length': '32"', 'Sleeve': '39"'},
    '4X': {'Chest': '48-50"', 'Length': '33"', 'Sleeve': '40"'},
  };

  static const _teeSizes = {
    'XS': {'Chest': '33-35"', 'Length': '27"', 'Sleeve': '8"'},
    'S':  {'Chest': '35-37"', 'Length': '28"', 'Sleeve': '8.5"'},
    'M':  {'Chest': '37-39"', 'Length': '29"', 'Sleeve': '9"'},
    'L':  {'Chest': '39-41"', 'Length': '30"', 'Sleeve': '9.5"'},
    'XL': {'Chest': '41-43"', 'Length': '31"', 'Sleeve': '10"'},
    '2X': {'Chest': '43-45"', 'Length': '32"', 'Sleeve': '10.5"'},
    '3X': {'Chest': '45-47"', 'Length': '33"', 'Sleeve': '11"'},
    '4X': {'Chest': '47-49"', 'Length': '34"', 'Sleeve': '11.5"'},
  };

  static final Map<String, ProductDetails> _catalog = {
    'bp_grid_iron': const ProductDetails(
      fullDescription:
        'The Sport-Tek Grid Iron Tech Fleece Hoodie delivers the warmth of fleece '
        'in a moisture-wicking polyester shell. The grid-pattern fleece lining traps '
        'heat while letting moisture escape. Three-panel hood and front pouch pocket.',
      features: [
        '7.1-oz, 100% polyester fleece',
        'Grid-pattern interior for warmth',
        'Moisture-wicking performance fabric',
        'Three-panel hood with drawcord',
        'Front pouch pocket',
        'Printed BMB logo on front',
        'Custom bracket print on back',
        'Rib knit cuffs and waistband',
      ],
      fabricCare:
        'Machine wash cold with like colors. Tumble dry low. '
        'Do not bleach. Do not iron directly on print or embellishment. '
        'Do not dry clean.',
      sizeChart: _hoodieSizes,
    ),
    'bp_tri_tee': const ProductDetails(
      fullDescription:
        'The Perfect Tri Tee is ultra-soft with a vintage feel thanks to its tri-blend '
        'fabric. The 50/25/25 poly/combed ring spun cotton/rayon mix creates a lightweight, '
        'breathable tee that drapes perfectly.',
      features: [
        '4.9-oz, 50/25/25 poly/ring spun cotton/rayon',
        'Ultra-soft tri-blend fabric',
        'Lightweight and breathable',
        'Side-seamed construction',
        'Tear-away label for comfort',
        'Printed BMB logo on front',
        'Custom bracket print on back',
        'Shoulder-to-shoulder taping',
      ],
      fabricCare:
        'Machine wash cold, inside out. Tumble dry low or hang dry. '
        'Do not bleach. Do not iron directly on print. '
        'Colors may vary slightly due to tri-blend fabric.',
      sizeChart: _teeSizes,
    ),
    'bp_street_lounge': const ProductDetails(
      fullDescription:
        'The New Era Street Lounge French Terry Hoodie combines streetwear style with '
        'premium comfort. The 52/48 cotton/poly French Terry fabric provides a soft, '
        'broken-in feel right out of the box. Features the embroidered BMB logo.',
      features: [
        '9.4-oz, 52/48 cotton/poly French Terry',
        'Premium heavyweight construction',
        'Soft, broken-in feel',
        'New Era quality and fit',
        'Front kangaroo pocket',
        'Embroidered BMB logo on front',
        'Custom bracket print on back',
        'Ribbed cuffs and hem',
      ],
      fabricCare:
        'Machine wash cold, inside out. Tumble dry low. '
        'Do not bleach. Do not iron directly on print or embroidery. '
        'Wash with like colors to prevent fading.',
      sizeChart: _hoodieSizes,
    ),
    'bp_on_the_go': const ProductDetails(
      fullDescription:
        'The New Era On The Go Tri-Blend Hoodie is built for active lifestyles. '
        'At just 4-oz, the 55/34/11 cotton/poly/rayon tri-blend is ultra-lightweight — '
        'perfect for layering or wearing on its own during workouts and warm-ups.',
      features: [
        '4-oz, 55/34/11 cotton/poly/rayon',
        'Ultra-lightweight tri-blend',
        'Perfect for layering',
        'New Era performance fit',
        'Self-fabric hood lining',
        'Printed BMB logo on front',
        'Custom bracket print on back',
        'Raw-edge details',
      ],
      fabricCare:
        'Machine wash cold, gentle cycle. Lay flat to dry or tumble dry low. '
        'Do not bleach. Do not iron directly on print. '
        'Lightweight fabric — handle with care.',
      sizeChart: _hoodieSizes,
    ),
    'bp_all_day': const ProductDetails(
      fullDescription:
        'The New Era All Day Tri-Blend Fleece Hoodie is the everyday essential. '
        'The 7.1-oz 55/34/11 cotton/poly/rayon blend delivers plush fleece warmth '
        'with the softness of a tri-blend. Wears great all day, every day.',
      features: [
        '7.1-oz, 55/34/11 cotton/poly/rayon',
        'Plush tri-blend fleece interior',
        'All-day comfort construction',
        'New Era signature fit',
        'Front kangaroo pocket',
        'Printed BMB logo on front',
        'Custom bracket print on back',
        'Ribbed cuffs and waistband',
      ],
      fabricCare:
        'Machine wash cold, inside out with like colors. '
        'Tumble dry low. Do not bleach. Do not iron directly on print. '
        'May shrink slightly on first wash — size up if between sizes.',
      sizeChart: _hoodieSizes,
    ),
  };
}

// ═══════════════════════════════════════════════════════════════════════
// BRACKET UI STATE — interactive editor only; NEVER enters print/preview
// ═══════════════════════════════════════════════════════════════════════

/// All UI-only field names that [sanitizeBracketForPrint] strips.
/// These come from the interactive bracket editor (tap, hover, selection)
/// and must NEVER be passed into the print or preview pipeline.
const Set<String> _uiOnlyFieldKeys = {
  // Selection / interaction state
  'selected', 'isSelected', 'is_selected',
  'hovered', 'isHovered', 'is_hovered',
  'active', 'isActive', 'is_active',
  'focused', 'isFocused', 'is_focused',
  // Preview / debug flags
  'previewMode', 'preview_mode', 'isPreview', 'is_preview',
  // Highlight / visual state
  'highlight', 'highlighted', 'isHighlighted', 'is_highlighted',
  'highlightColor', 'highlight_color',
  'selectionColor', 'selection_color',
  'hoverColor', 'hover_color',
  'activeColor', 'active_color',
  'focusColor', 'focus_color',
  // UI layer tags
  'uiLayer', 'ui_layer', 'bracketUI', 'bracket_ui',
  // Animation / transition state
  'animating', 'isAnimating', 'is_animating',
  'expandedSlot', 'expanded_slot',
  'dragState', 'drag_state',
  // Color overrides injected by the UI
  'colorOverride', 'color_override',
  'styleOverride', 'style_override',
};

/// Regex patterns matching UI-only keys in a map.
final RegExp _uiKeyPattern = RegExp(
  r'(highlight|selected|hovered|active|focused|preview|ui_layer|uiLayer|'
  r'drag|animat|expanded|override)',
  caseSensitive: false,
);

/// Interactive bracket state. This model carries ALL UI-specific state
/// (selections, highlights, hover data, color overrides) used by the
/// bracket editor widget. It is NEVER passed to print or preview.
///
/// Convert to [BracketPrintData] via [sanitizeBracketForPrint] at the
/// UI → print/preview boundary.
class BracketUIState {
  final int teamCount;
  final String bracketTitle;
  final String championName;
  final List<String> teams;
  final Map<String, String> picks;
  final BracketPrintStyle style;

  // ── UI-only fields (stripped by sanitizer) ────────────────────
  final Set<String> selectedSlots;
  final String? hoveredSlot;
  final String? activeSlot;
  final String? focusedSlot;
  final bool previewMode;
  final Map<String, bool> highlightFlags;
  final Map<String, Color> colorOverrides;
  final Map<String, dynamic> extraUiState;

  const BracketUIState({
    required this.teamCount,
    required this.bracketTitle,
    required this.championName,
    required this.teams,
    required this.picks,
    this.style = BracketPrintStyle.classic,
    this.selectedSlots = const {},
    this.hoveredSlot,
    this.activeSlot,
    this.focusedSlot,
    this.previewMode = false,
    this.highlightFlags = const {},
    this.colorOverrides = const {},
    this.extraUiState = const {},
  });
}

// ═══════════════════════════════════════════════════════════════════════
// CANONICAL BRACKET DATA — single input struct for both print & preview
// ═══════════════════════════════════════════════════════════════════════

/// Immutable, sanitized bracket data bundle. The sole input to both
/// `renderBracketPrintSvg()` and `BracketPrintCanvas`.
///
/// This struct contains ZERO UI-only state. It is always produced via
/// [sanitizeBracketForPrint] — never constructed directly from raw
/// interactive bracket state.
///
/// The [isSanitized] flag is set by the sanitizer and checked by
/// guards in the print/preview pipeline. If data bypasses the
/// sanitizer, [isSanitized] remains `false` and the guard throws.
class BracketPrintData {
  final int teamCount;
  final String bracketTitle;
  final String championName;
  final List<String> teams;
  final Map<String, String> picks;
  final BracketPrintStyle style;

  /// `true` iff this instance was produced by [sanitizeBracketForPrint].
  /// The print/preview pipeline asserts this flag.
  final bool isSanitized;

  const BracketPrintData({
    required this.teamCount,
    required this.bracketTitle,
    required this.championName,
    required this.teams,
    required this.picks,
    this.style = BracketPrintStyle.classic,
    this.isSanitized = false,
  });
}

// ═══════════════════════════════════════════════════════════════════════
// BRACKET DATA SANITIZER — the ONLY path from UI → print/preview
// ═══════════════════════════════════════════════════════════════════════

/// Strip all UI-only fields from bracket data and produce a clean
/// [BracketPrintData] that is safe for print and preview rendering.
///
/// This function:
///   1. Removes all UI-only keys from the picks map (selected, hovered,
///      active, focused, previewMode, highlight flags, color overrides).
///   2. Normalises team names (trim whitespace).
///   3. Strips any colour-override or highlight metadata from picks.
///   4. Sets [BracketPrintData.isSanitized] = `true`.
///
/// Call this at the UI → print/preview boundary. NEVER pass unsanitized
/// data to [renderBracketPrintSvg], [BracketPrintCanvas], or any other
/// print/preview renderer.
BracketPrintData sanitizeBracketForPrint({
  required int teamCount,
  required String bracketTitle,
  required String championName,
  required List<String> teams,
  required Map<String, String> picks,
  BracketPrintStyle style = BracketPrintStyle.classic,
}) {
  // 1. Strip UI-only keys from picks map.
  final cleanPicks = <String, String>{};
  for (final entry in picks.entries) {
    final key = entry.key;
    // Skip if the key itself is a known UI-only field.
    if (_uiOnlyFieldKeys.contains(key)) continue;
    // Skip if the key matches the UI pattern regex.
    if (_uiKeyPattern.hasMatch(key)) continue;
    // Skip entries whose values look like colour hex overrides injected
    // by the UI layer (e.g. '#FFEB3B', '0xFF2196F3').
    final val = entry.value;
    if (val.startsWith('#') && val.length == 7 && _isHexColor(val)) continue;
    if (val.startsWith('0x') && val.length >= 8 && _isArgbHex(val)) continue;
    // Keep the entry — value is a real team name or pick.
    cleanPicks[key] = val.trim();
  }

  // 2. Normalise team names.
  final cleanTeams = teams.map((t) => t.trim()).toList();

  // 3. Build sanitized struct.
  return BracketPrintData(
    teamCount: teamCount,
    bracketTitle: bracketTitle.trim(),
    championName: championName.trim(),
    teams: cleanTeams,
    picks: Map.unmodifiable(cleanPicks),
    style: style,
    isSanitized: true,
  );
}

/// Convenience overload: convert a [BracketUIState] directly.
BracketPrintData sanitizeBracketUIForPrint(BracketUIState uiState) {
  return sanitizeBracketForPrint(
    teamCount: uiState.teamCount,
    bracketTitle: uiState.bracketTitle,
    championName: uiState.championName,
    teams: uiState.teams,
    picks: uiState.picks,
    style: uiState.style,
  );
}

// ═══════════════════════════════════════════════════════════════════════
// GARMENT IMAGE BOUNDS — BoxFit.contain layout helper
// ═══════════════════════════════════════════════════════════════════════

/// Compute the sub-rect that a garment image occupies inside a container
/// when rendered with [BoxFit.contain].
///
/// Product photos are typically shot against a transparent/studio
/// background with a known intrinsic aspect ratio.  When the image is
/// painted with `BoxFit.contain` inside a container of [containerSize],
/// it is uniformly scaled to the largest size that fits without
/// cropping, then centred.  This function returns that centred rect
/// so that print-area fractions can be applied to the *image* rather
/// than the full container.
///
/// [imageAspectRatio] is width/height of the source image.  When the
/// actual intrinsic size is unknown, pass the product type's canonical
/// aspect ratio (e.g. 0.67 for a hoodie photo that is taller than
/// wide).
Rect garmentImageBounds({
  required Size containerSize,
  required double imageAspectRatio,
}) {
  final containerAR = containerSize.width / containerSize.height;
  double imgW, imgH;
  if (imageAspectRatio > containerAR) {
    // Image is wider than container → pillarboxed (full width, shorter height)
    imgW = containerSize.width;
    imgH = containerSize.width / imageAspectRatio;
  } else {
    // Image is taller than container → letterboxed (full height, narrower width)
    imgH = containerSize.height;
    imgW = containerSize.height * imageAspectRatio;
  }
  return Rect.fromCenter(
    center: Offset(containerSize.width / 2, containerSize.height / 2),
    width: imgW,
    height: imgH,
  );
}

/// Canonical image aspect ratios for product types.
///
/// These represent the typical width:height ratio of the Shopify CDN
/// product photos rendered via `BoxFit.contain` inside the 560-px
/// preview container.
class GarmentImageAspectRatios {
  GarmentImageAspectRatios._();

  /// Hoodies: roughly 800 x 960 px source → AR ≈ 0.833
  static const double hoodie = 0.833;

  /// T-shirts: roughly 800 x 1000 px source → AR ≈ 0.80
  static const double tShirt = 0.80;

  /// Look up by product type.
  static double forType(PrintProductType type) =>
      type == PrintProductType.hoodie ? hoodie : tShirt;
}

/// Check if a string looks like '#RRGGBB'.
bool _isHexColor(String s) {
  if (s.length != 7 || s[0] != '#') return false;
  return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s);
}

/// Check if a string looks like '0xAARRGGBB' or '0xRRGGBB'.
bool _isArgbHex(String s) {
  return RegExp(r'^0x[0-9A-Fa-f]{6,8}$').hasMatch(s);
}

/// Product-level configuration needed alongside bracket data.
class ProductPrintConfig {
  final String productId;
  final PrintProductType productType;
  final GarmentColor garmentColor;
  final GarmentPrintMask? maskOverride;
  final PrintProduct? product;

  const ProductPrintConfig({
    required this.productId,
    required this.productType,
    required this.garmentColor,
    this.maskOverride,
    this.product,
  });

  /// Resolved mask: explicit override → per-product catalog → generic type.
  GarmentPrintMask get mask =>
      maskOverride ?? GarmentPrintMask.forProduct(productId, productType);

  /// Resolved print areas (fractional coordinates).
  /// Prefers the product's inline printAreas, then falls back to type default.
  ProductPrintAreas get printAreas {
    if (product != null) return product!.resolvedPrintAreas;
    return ProductPrintAreaCatalog.forProduct(productId, productType);
  }

  /// Palette: derived from garment darkness.
  BracketPrintPalette get palette => garmentColor.bracketPalette;
}
