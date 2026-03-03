import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:bmb_mobile/core/config/app_config.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/merch_preview_service.dart';
import 'package:bmb_mobile/features/bracket_print/data/services/bracket_print_renderer.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/bracket_print_canvas.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/color_matched_image.dart';

/// Print-safe apparel preview widget.
///
/// Architecture — CANONICAL ONLY:
///   The bracket art is produced exclusively by [renderBracketPrintSvg]
///   (SVG string) and [BracketPrintCanvas] (Canvas/Paint calls).
///
///   ZERO interactive layers (no tap, hover, selection).
///   ZERO Flutter widget-tree bracket elements.
///   ZERO UI colours (yellow highlight, blue selection, hover glow).
///
///   All incoming bracket data is **sanitized** via
///   [sanitizeBracketForPrint] before it reaches any renderer.
///   After sanitization, [PREVIEW_UI_LAYER_DETECTED] should NEVER
///   fire — if it does, it is treated as a **fatal bug**.
///
/// Print-area compositing:
///   - The bracket is placed INSIDE the garment print area, not the
///     full UI canvas.
///   - [ProductPrintAreaCatalog] provides per-product fractional
///     {x, y, w, h} regions for front and back views.
///   - The bracket is uniformly scaled to fit within the print area
///     (preserving aspect ratio), centred, and strictly clipped.
///   - The bracket overlay is drawn ON TOP of the garment image layer.
///
/// Debug overlay (PREVIEW_DEBUG=true or [showDebugOverlay]):
///   - Cyan: print-area rectangle
///   - Magenta: bracket bounding box (after scale)
///   - Labels: view, productId, printArea, computedScale
class BracketCompositePreview extends StatefulWidget {
  final String productId;
  final GarmentColor garmentColor;
  final PrintProductType productType;
  final int teamCount;
  final String bracketTitle;
  final String championName;
  final List<String> teams;
  final Map<String, String> picks;
  final BracketPrintStyle printStyle;
  final String? garmentImageUrl;   // Shopify CDN front image (colour-correct)
  final String? backImageAsset;    // local asset for back view
  final GarmentPrintMask? printMask; // legacy override (ignored by new system)

  /// The full product object. If non-null, the widget reads mockups,
  /// printAreas, and defaultPreviewView from it (schema v2).
  /// If null, falls back to legacy fields + [ProductPrintAreaCatalog].
  final PrintProduct? product;

  /// Called when the server returns an artifactId for this preview.
  final void Function(String artifactId, String? previewUrl)? onArtifactReady;

  /// Show debug overlay (mask outline, bounding box, render mode label).
  /// Also enabled globally by PREVIEW_DEBUG=true compile-time flag.
  final bool showDebugOverlay;

  /// Which view to show: 'front' or 'back'.
  /// If not set explicitly and [product] is provided, uses
  /// [product.defaultPreviewView].
  final String? view;

  const BracketCompositePreview({
    super.key,
    required this.productId,
    required this.garmentColor,
    required this.productType,
    required this.teamCount,
    required this.bracketTitle,
    required this.championName,
    required this.teams,
    required this.picks,
    this.printStyle = BracketPrintStyle.classic,
    this.garmentImageUrl,
    this.backImageAsset,
    this.printMask,
    this.product,
    this.onArtifactReady,
    this.showDebugOverlay = false,
    this.view,
  });

  @override
  State<BracketCompositePreview> createState() =>
      _BracketCompositePreviewState();
}

class _BracketCompositePreviewState extends State<BracketCompositePreview> {
  /// If non-null, a contamination guard threw and we display the error.
  String? _contaminationError;

  /// RepaintBoundary key for debug artifact capture.
  final GlobalKey _repaintKey = GlobalKey();

  /// Sanitized bracket data — built once in [_runPreflightGuards] and
  /// reused by the widget tree. NEVER passes raw widget.* fields to
  /// renderers.
  late BracketPrintData _sanitizedData;

  @override
  void initState() {
    super.initState();
    _runPreflightGuards();
    _prefetchArtifactId();
  }

  @override
  void didUpdateWidget(covariant BracketCompositePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.productId != widget.productId ||
        oldWidget.garmentColor.name != widget.garmentColor.name ||
        oldWidget.printStyle != widget.printStyle ||
        oldWidget.view != widget.view) {
      _runPreflightGuards();
      _prefetchArtifactId();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PRE-FLIGHT GUARDS
  // ═══════════════════════════════════════════════════════════════

  void _runPreflightGuards() {
    try {
      // 0. SANITIZE: strip all UI-only state at the boundary
      _sanitizedData = sanitizeBracketForPrint(
        teamCount: widget.teamCount,
        bracketTitle: widget.bracketTitle,
        championName: widget.championName,
        teams: widget.teams,
        picks: widget.picks,
        style: widget.printStyle,
      );

      // 1. Mode guard
      UiContaminationGuard.assertNotUiMode(BracketRenderMode.bracketPreview);

      // 2. Post-sanitization guard (sanitized + palette clean)
      UiContaminationGuard.assertPostSanitizationClean(
        _sanitizedData, _palette);

      // 3. Canonical SVG guard — render and validate the SVG
      final svg = renderBracketPrintSvg(
        _sanitizedData,
        ProductPrintConfig(
          productId: widget.productId,
          productType: widget.productType,
          garmentColor: widget.garmentColor,
          maskOverride: widget.printMask,
        ),
      );
      if (kDebugMode) {
        debugPrint('[CompositePreview] Preflight OK  '
            'CANONICAL_ONLY=${CanonicalRendererLog.canonicalOnly}  '
            'svgLen=${svg.length}  sanitized=${_sanitizedData.isSanitized}');
      }
      if (mounted) {
        setState(() => _contaminationError = null);
      }
    } on PreviewUiLayerDetected catch (e) {
      if (kDebugMode) {
        debugPrint('[CompositePreview] PREFLIGHT FAILED: $e');
      }
      if (mounted) {
        setState(() => _contaminationError = e.detail);
      }
    }
  }

  Future<void> _prefetchArtifactId() async {
    if (kDebugMode) {
      debugPrint('[CompositePreview] Background artifactId fetch from '
          '${AppConfig.merchServerBaseUrl}');
    }
    try {
      final result = await MerchPreviewService.fetchPreviewImageWithMeta(
        bracketTitle: widget.bracketTitle,
        championName: widget.championName,
        teamCount: widget.teamCount,
        teams: widget.teams,
        picks: widget.picks,
        style: widget.printStyle.name,
        productId: widget.productId,
        colorName: widget.garmentColor.name,
        isDarkGarment: widget.garmentColor.isDark,
      );
      if (mounted && result != null && result.artifactId != null) {
        if (kDebugMode) {
          debugPrint('[CompositePreview] Got artifactId=${result.artifactId}');
        }
        widget.onArtifactReady?.call(result.artifactId!, null);
      }
    } catch (_) {
      if (kDebugMode) {
        debugPrint('[CompositePreview] Server unreachable');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PALETTE SELECTION
  // ═══════════════════════════════════════════════════════════════

  BracketPrintPalette get _palette =>
      BracketPrintPalette.previewHighContrast;

  // ═══════════════════════════════════════════════════════════════
  // PRINT AREA LOOKUP
  // ═══════════════════════════════════════════════════════════════

  /// Resolved view: explicit [widget.view] > product.defaultPreviewView > 'back'.
  String get _resolvedView =>
      widget.view ??
      widget.product?.defaultPreviewView ??
      'back';

  /// Resolved print areas: product inline > type default.
  ProductPrintAreas get _printAreas {
    if (widget.product != null) return widget.product!.resolvedPrintAreas;
    return ProductPrintAreaCatalog.forProduct(
        widget.productId, widget.productType);
  }

  /// The active print-area rect for the current view.
  PrintAreaRect get _activePrintArea =>
      _resolvedView == 'front' ? _printAreas.front : _printAreas.back;

  // ═══════════════════════════════════════════════════════════════
  // SHOULD SHOW DEBUG?
  // ═══════════════════════════════════════════════════════════════

  bool get _showDebug => widget.showDebugOverlay || isPreviewDebugEnabled;

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    if (_contaminationError != null) {
      return _buildContaminationError();
    }

    return RepaintBoundary(
      key: _repaintKey,
      child: Container(
        width: double.infinity,
        height: 560,
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final containerSize = Size(
                constraints.maxWidth, constraints.maxHeight);

              // ── IMAGE-SPACE compositing ─────────────────────────
              // The garment image is painted with BoxFit.contain inside
              // the container.  Compute the sub-rect the image actually
              // occupies, then apply print-area fractions to THAT rect
              // so the bracket sits ON the garment, not in screen-space
              // letterbox padding.
              final imageAR = widget.product != null
                  ? GarmentImageAspectRatios.forType(widget.product!.type)
                  : GarmentImageAspectRatios.forType(widget.productType);
              final imageBounds = garmentImageBounds(
                containerSize: containerSize,
                imageAspectRatio: imageAR,
              );
              final printAreaRect = _activePrintArea.toRectInImage(imageBounds);

              final currentView = _resolvedView;

              return Stack(
                children: [
                  // LAYER 1: Background
                  _buildBackground(),

                  // LAYER 2: Garment image
                  _buildGarmentImage(),

                  // LAYER 2b: Logo cover overlay for back view
                  // When showing the back view from a flipped front
                  // photo, mask the front BMB logo with a garment-
                  // coloured overlay. We use a solid fill over the
                  // logo area and a soft fade at edges to seamlessly
                  // blend with the garment image.
                  if (currentView == 'back')
                    Positioned.fill(
                      child: Stack(
                        children: [
                          // Primary: solid garment-color fill to hide front logo
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: const Alignment(0.0, -0.20),
                                  radius: 0.55,
                                  colors: [
                                    widget.garmentColor.color,
                                    widget.garmentColor.color.withValues(alpha: 0.98),
                                    widget.garmentColor.color.withValues(alpha: 0.90),
                                    widget.garmentColor.color.withValues(alpha: 0.50),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.25, 0.45, 0.65, 0.85],
                                ),
                              ),
                            ),
                          ),
                          // Secondary: top-to-bottom fade for natural garment look
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: const Alignment(0.0, -0.2),
                                  colors: [
                                    widget.garmentColor.color.withValues(alpha: 0.95),
                                    widget.garmentColor.color.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.15, 0.35],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // LAYER 3: Subtle fabric texture
                  _buildFabricOverlay(),

                  // LAYER 4: BRACKET — composited ON TOP of garment,
                  //          clipped STRICTLY to printArea bounds.
                  _buildBracketOverlay(printAreaRect),

                  // LAYER 5: View badge (always visible)
                  Positioned(
                    bottom: 10,
                    right: 14,
                    child: _badge(
                      currentView == 'front' ? 'FRONT VIEW' : 'BACK VIEW',
                      Colors.black.withValues(alpha: 0.55),
                    ),
                  ),

                  // LAYER 6: Debug-only badges (PREVIEW MODE + CANONICAL)
                  if (_showDebug) ...[                  
                    Positioned(
                      top: 12,
                      left: 14,
                      child: _badge('PREVIEW MODE', Colors.orange),
                    ),
                    Positioned(
                      top: 12,
                      right: 14,
                      child: _badge(
                        'CANONICAL',
                        Colors.green.withValues(alpha: 0.7),
                      ),
                    ),
                  ],

                  // LAYER 7: Debug overlay (print-area rects + labels)
                  if (_showDebug)
                    _buildDebugOverlay(
                        containerSize, printAreaRect, imageBounds,
                        _bracketBoundsInPrintArea(printAreaRect)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BRACKET OVERLAY — uniformly scaled, centred, clipped to printArea
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBracketOverlay(Rect printAreaRect) {
    // The bracket has an intrinsic aspect ratio derived from the
    // product's physical print dimensions (e.g. 11x13" for hoodies,
    // 12x14" for tees).  We uniform-scale the bracket to FIT inside
    // the print area while preserving that ratio, centre it, and
    // clip strictly so no bracket element touches sleeves/hood/pocket.
    final physW = _printAreas.physicalWidthInches;
    final physH = _printAreas.physicalHeightInches;
    final bracketAR = physW / physH; // e.g. 11/13 ≈ 0.846

    final areaW = printAreaRect.width;
    final areaH = printAreaRect.height;
    final areaAR = areaW / areaH;

    // Uniform scale: fit the bracket's AR inside the area's AR.
    double bracketW, bracketH;
    if (bracketAR > areaAR) {
      // Bracket is wider than area → constrained by width.
      bracketW = areaW;
      bracketH = areaW / bracketAR;
    } else {
      // Bracket is taller than area → constrained by height.
      bracketH = areaH;
      bracketW = areaH * bracketAR;
    }

    return Positioned(
      left: printAreaRect.left,
      top: printAreaRect.top,
      width: areaW,
      height: areaH,
      // Clip strictly to the print area bounds — nothing overflows
      // into sleeves, hood, or pocket seam.
      child: ClipRect(
        child: Center(
          child: SizedBox(
            width: bracketW,
            height: bracketH,
            child: CustomPaint(
              size: Size(bracketW, bracketH),
              painter: BracketPrintCanvas(
                bracketTitle: _sanitizedData.bracketTitle,
                championName: _sanitizedData.championName,
                teamCount: _sanitizedData.teamCount,
                teams: _sanitizedData.teams,
                picks: _sanitizedData.picks,
                palette: _palette,
                renderMode: BracketRenderMode.bracketPreview,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compute the bracket bounding box after uniform scaling.
  /// Used by the debug overlay to draw the magenta bracket bbox.
  Rect _bracketBoundsInPrintArea(Rect printAreaRect) {
    final physW = _printAreas.physicalWidthInches;
    final physH = _printAreas.physicalHeightInches;
    final bracketAR = physW / physH;

    final areaW = printAreaRect.width;
    final areaH = printAreaRect.height;
    final areaAR = areaW / areaH;

    double bW, bH;
    if (bracketAR > areaAR) {
      bW = areaW;
      bH = areaW / bracketAR;
    } else {
      bH = areaH;
      bW = areaH * bracketAR;
    }

    final x = printAreaRect.left + (areaW - bW) / 2;
    final y = printAreaRect.top + (areaH - bH) / 2;
    return Rect.fromLTWH(x, y, bW, bH);
  }

  // ═══════════════════════════════════════════════════════════════
  // CONTAMINATION ERROR CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildContaminationError() {
    return Container(
      width: double.infinity,
      height: 560,
      decoration: BoxDecoration(
        color: const Color(0xFF1A0000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.6), width: 2),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                'PREVIEW_UI_LAYER_DETECTED',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Preview error: UI highlight detected. Please retry.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _contaminationError ?? '',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () {
                  _runPreflightGuards();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LAYER BUILDERS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBackground() {
    // Dark neutral background behind the garment photo. The garment
    // image (from colour matching) sits on top.
    return Positioned.fill(
      child: Container(color: const Color(0xFF1A1A1A)),
    );
  }

  Widget _buildGarmentImage() {
    // Unified colour-matched garment layer.
    // Handles both exactMockup and tintBase strategies for all views.
    return buildColorMatchedGarmentLayer(
      product: widget.product,
      view: _resolvedView,
      garmentColor: widget.garmentColor,
      legacyFrontUrl: widget.garmentImageUrl,
      legacyBackAsset: widget.backImageAsset,
      legacyFrontImageUrl: widget.product?.frontImageUrl,
    );
  }

  Widget _buildFabricOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.06),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(
              alpha: label.contains('VIEW') ? 0.5 : 1.0),
          fontSize: label.contains('VIEW') ? 8 : 10,
          fontWeight: FontWeight.w700,
          letterSpacing: label.contains('VIEW') ? 1.0 : 0.5,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DEBUG OVERLAY
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDebugOverlay(
      Size containerSize, Rect printAreaRect, Rect imageBounds,
      Rect bracketBounds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captureDebugArtifacts();
    });

    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _PrintAreaDebugPainter(
            printAreaRect: printAreaRect,
            bracketBounds: bracketBounds,
            containerSize: containerSize,
            imageBounds: imageBounds,
            view: _resolvedView,
            productId: widget.productId,
            printArea: _activePrintArea,
            printAreas: _printAreas,
            renderMode: BracketRenderMode.bracketPreview,
            defaultPreviewView:
                widget.product?.defaultPreviewView ?? 'back',
            printOn: widget.product?.printOn ?? const PrintOn(),
            productType: widget.product?.type ?? widget.productType,
          ),
        ),
      ),
    );
  }

  Future<void> _captureDebugArtifacts() async {
    if (!_showDebug) return;
    try {
      final boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return;

      // FIX #5: Removed dart:io — web-safe. Debug info logged to console.
      final mockupBytes = byteData.buffer.asUint8List();
      if (kDebugMode) {
        debugPrint('[DebugArtifact] Mockup captured '
            '(${mockupBytes.length} bytes)');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DebugArtifact] Capture failed: $e');
      }
    }
  }
}

/// Debug overlay painter for print-area compositing.
///
/// Draws:
///   1. Print-area rectangle (cyan)
///   2. Bracket bounding box (magenta, inset)
///   3. Corner markers
///   4. Labels: view, productId, printArea fractions, computedScale
class _PrintAreaDebugPainter extends CustomPainter {
  final Rect printAreaRect;
  final Rect bracketBounds;
  final Size containerSize;
  final Rect imageBounds;
  final String view;
  final String productId;
  final PrintAreaRect printArea;
  final ProductPrintAreas printAreas;
  final BracketRenderMode renderMode;
  final String defaultPreviewView;
  final PrintOn printOn;
  final PrintProductType productType;

  _PrintAreaDebugPainter({
    required this.printAreaRect,
    required this.bracketBounds,
    required this.containerSize,
    required this.imageBounds,
    required this.view,
    required this.productId,
    required this.printArea,
    required this.printAreas,
    required this.renderMode,
    this.defaultPreviewView = 'back',
    this.printOn = const PrintOn(),
    this.productType = PrintProductType.hoodie,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Image bounds outline (green, dashed feel via thin stroke)
    final imgBoundsPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(imageBounds, imgBoundsPaint);

    // Print area outline (cyan)
    final areaPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(printAreaRect, areaPaint);

    // Bracket bounding box (magenta) — shows actual uniform-fit size,
    // which may be smaller than the print area if aspect ratios differ.
    final bracketPaint = Paint()
      ..color = Colors.pinkAccent.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(bracketBounds, bracketPaint);

    // Corner markers on print area
    const markerLen = 12.0;
    final markerPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    void drawCorner(Offset corner, double dx, double dy) {
      canvas.drawLine(corner, corner + Offset(dx, 0), markerPaint);
      canvas.drawLine(corner, corner + Offset(0, dy), markerPaint);
    }

    drawCorner(printAreaRect.topLeft, markerLen, markerLen);
    drawCorner(printAreaRect.topRight, -markerLen, markerLen);
    drawCorner(printAreaRect.bottomLeft, markerLen, -markerLen);
    drawCorner(printAreaRect.bottomRight, -markerLen, -markerLen);

    // Compute effective scale for label
    final scaleX = printAreaRect.width / containerSize.width;
    final scaleY = printAreaRect.height / containerSize.height;

    // 300 DPI final pixel size
    final dpiW = printAreas.printWidthPx;
    final dpiH = printAreas.printHeightPx;

    final lines = [
      'view: ${view.toUpperCase()}',
      'productId: $productId',
      'type: ${productType.name}',
      'printArea: x=${printArea.x.toStringAsFixed(2)} '
          'y=${printArea.y.toStringAsFixed(2)} '
          'w=${printArea.w.toStringAsFixed(2)} '
          'h=${printArea.h.toStringAsFixed(2)}',
      'imageBounds: ${imageBounds.left.toStringAsFixed(0)},'
          '${imageBounds.top.toStringAsFixed(0)} '
          '${imageBounds.width.toStringAsFixed(0)}x'
          '${imageBounds.height.toStringAsFixed(0)}',
      'bracketBox: ${bracketBounds.width.toStringAsFixed(0)}x'
          '${bracketBounds.height.toStringAsFixed(0)} px '
          '(uniform-fit)',
      'printSize: ${dpiW}x$dpiH @ 300 DPI '
          '(${printAreas.physicalWidthInches}x'
          '${printAreas.physicalHeightInches} in)',
      'computedScale: ${scaleX.toStringAsFixed(3)}x'
          '${scaleY.toStringAsFixed(3)}',
      'compositing: IMAGE-SPACE',
      'colorStrategy: ${ColorMatchLog.lastEntry?.strategy.name ?? 'n/a'}',
      'colorTint: ${ColorMatchLog.lastEntry?.tintHex ?? 'none'}'
          '${ColorMatchLog.lastEntry?.tintAlpha != null ? ' @${ColorMatchLog.lastEntry!.tintAlpha!.toStringAsFixed(2)}' : ''}',
      'defaultPreviewView: $defaultPreviewView',
      'printOn: front=${printOn.front} back=${printOn.back}',
      'renderMode: ${renderMode.name.toUpperCase()}',
      'CANONICAL_ONLY: ${CanonicalRendererLog.canonicalOnly}',
      'rendererPath: ${CanonicalRendererLog.lastPath}',
      'colorMode: ${kPrintColorMode.name.toUpperCase()}',
    ];

    final tp = TextPainter(
      text: TextSpan(
        text: lines.join('\n'),
        style: TextStyle(
          color: Colors.cyan.withValues(alpha: 0.85),
          fontSize: 8,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position label just above the print area
    final labelY = (printAreaRect.top - tp.height - 8).clamp(0.0, size.height);
    final bg = Rect.fromLTWH(
      printAreaRect.left, labelY,
      tp.width + 10, tp.height + 6,
    );
    canvas.drawRect(
      bg,
      Paint()..color = Colors.black.withValues(alpha: 0.75),
    );
    tp.paint(canvas, Offset(bg.left + 5, bg.top + 3));
  }

  @override
  bool shouldRepaint(covariant _PrintAreaDebugPainter old) =>
      printAreaRect != old.printAreaRect ||
      bracketBounds != old.bracketBounds ||
      imageBounds != old.imageBounds ||
      view != old.view ||
      productId != old.productId;
}
