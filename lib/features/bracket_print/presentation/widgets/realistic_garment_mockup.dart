import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/bracket_print_canvas.dart';
import 'package:bmb_mobile/features/bracket_print/presentation/widgets/color_matched_image.dart';

/// Photorealistic garment mockup — canonical rendering pipeline ONLY.
///
///   Layer 1 — Solid garment-color base
///   Layer 2 — Real Shopify product photo, flipped horizontally = back view
///   Layer 3 — Solid garment-color fill to fully cover front logo
///   Layer 4 — Light/shadow gradient for realism
///   Layer 5 — Bracket print via [BracketPrintCanvas] (pure CustomPainter),
///             **placed INSIDE the garment print area** using fractional
///             coordinates from [ProductPrintAreaCatalog].
///             NO widget-tree bracket layers. NO interactive components.
///   Layer 6 — "BACK VIEW" badge
///
/// Architecture:
///   - ZERO widget-tree bracket elements.
///   - Single [CustomPaint] backed by [BracketPrintCanvas].
///   - All bracket data is **sanitized** via [sanitizeBracketForPrint]
///     before reaching the painter.
///   - All colours from [BracketPrintPalette] — no UI highlight/selection.
///   - CANONICAL_ONLY=true logged at construction time.
///   - Bracket is strictly clipped to the product's print area.
///
/// If contamination is detected post-sanitization, the widget renders
/// an error indicator instead of the bracket overlay.
class RealisticGarmentMockup extends StatelessWidget {
  final String imageUrl;
  final GarmentColor garmentColor;
  final PrintProductType productType;
  final int teamCount;
  final String bracketTitle;
  final String championName;
  final List<String> teams;
  final Map<String, String> picks;
  final BracketPrintStyle printStyle;
  final String productId;

  /// Full product object (schema v2). If provided, the widget reads
  /// mockups, printAreas, and defaultPreviewView from it.
  final PrintProduct? product;

  /// Which view to render. Falls back to product.defaultPreviewView
  /// then 'back' if not specified.
  final String? view;

  const RealisticGarmentMockup({
    super.key,
    required this.imageUrl,
    required this.garmentColor,
    required this.productType,
    required this.teamCount,
    required this.bracketTitle,
    required this.championName,
    required this.teams,
    required this.picks,
    required this.printStyle,
    this.productId = 'bp_grid_iron',
    this.product,
    this.view,
  });

  @override
  Widget build(BuildContext context) {
    // Log canonical path
    CanonicalRendererLog.log('RealisticGarmentMockup.build');

    // SANITIZE: strip all UI-only state at the boundary
    final sanitized = sanitizeBracketForPrint(
      teamCount: teamCount,
      bracketTitle: bracketTitle,
      championName: championName,
      teams: teams,
      picks: picks,
      style: printStyle,
    );

    final pal = garmentColor.bracketPalette;

    // Resolve view.
    final currentView = view ?? product?.defaultPreviewView ?? 'back';

    // Look up the product's print area for the current view.
    final resolvedAreas = product?.resolvedPrintAreas ??
        ProductPrintAreaCatalog.forProduct(productId, productType);
    final activeArea = currentView == 'front'
        ? resolvedAreas.front
        : resolvedAreas.back;

    // Post-sanitization guard (FATAL if fires)
    bool contaminated = false;
    try {
      UiContaminationGuard.assertPostSanitizationClean(sanitized, pal);
    } on PreviewUiLayerDetected catch (e) {
      contaminated = true;
      if (kDebugMode) {
        debugPrint(
            '[RealisticGarmentMockup] FATAL POST-SANITIZATION: ${e.detail}');
      }
    }

    return Container(
      width: double.infinity,
      height: 560,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BmbColors.borderColor, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final containerSize = Size(
              constraints.maxWidth, constraints.maxHeight);

            // ── IMAGE-SPACE compositing ─────────────────────────────
            // Compute the sub-rect that the garment photo occupies
            // inside the container (BoxFit.contain letterbox), then
            // apply print-area fractions to THAT rect so the bracket
            // is placed ON the garment, not floating in screen-space.
            final imageAR = product != null
                ? GarmentImageAspectRatios.forType(product!.type)
                : GarmentImageAspectRatios.forType(productType);
            final imageBounds = garmentImageBounds(
              containerSize: containerSize,
              imageAspectRatio: imageAR,
            );
            final printRect = activeArea.toRectInImage(imageBounds);

            return Stack(
              children: [
                // LAYER 1: Solid garment color base
                Positioned.fill(
                  child: Container(color: garmentColor.color),
                ),

                // LAYER 2: Colour-matched garment photo
                //          Uses resolveColorImage for correct colour on
                //          both front and back views (no "always black").
                buildColorMatchedGarmentLayer(
                  product: product,
                  view: currentView,
                  garmentColor: garmentColor,
                  legacyFrontUrl: imageUrl,
                ),

                // LAYER 3: Color overlay to erase front logo
                //          (only needed when showing a flipped-front image
                //          as the back view, to mask the front BMB logo)
                //          Centre is offset upward (-0.15) to target the
                //          chest-area logo placement on hoodies/tees.
                if (currentView == 'back')
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.15),
                          radius: 0.40,
                          colors: [
                            garmentColor.color.withValues(alpha: 0.97),
                            garmentColor.color.withValues(alpha: 0.92),
                            garmentColor.color.withValues(alpha: 0.70),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.30, 0.50, 0.80],
                        ),
                      ),
                    ),
                  ),

                // LAYER 4: Light/shadow for fabric realism
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.02),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.04),
                        ],
                      ),
                    ),
                  ),
                ),

                // LAYER 5: THE BRACKET PRINT — inside printArea
                //          Uniformly scaled to fit, centred, clipped.
                if (contaminated)
                  Positioned(
                    left: printRect.left,
                    top: printRect.top,
                    width: printRect.width,
                    height: printRect.height,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'PREVIEW_UI_LAYER_DETECTED',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  _buildUniformBracketOverlay(
                    printRect: printRect,
                    sanitized: sanitized,
                    palette: pal,
                    physW: resolvedAreas.physicalWidthInches,
                    physH: resolvedAreas.physicalHeightInches,
                  ),

                // LAYER 6: View badge
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentView == 'front' ? 'FRONT VIEW' : 'BACK VIEW',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Build the bracket overlay uniformly scaled to fit inside [printRect],
  /// preserving the bracket's intrinsic aspect ratio (physical inches),
  /// centred, and strictly clipped so nothing overflows into sleeves/hood.
  static Widget _buildUniformBracketOverlay({
    required Rect printRect,
    required BracketPrintData sanitized,
    required BracketPrintPalette palette,
    required double physW,
    required double physH,
  }) {
    final bracketAR = physW / physH;
    final areaW = printRect.width;
    final areaH = printRect.height;
    final areaAR = areaW / areaH;

    double bW, bH;
    if (bracketAR > areaAR) {
      bW = areaW;
      bH = areaW / bracketAR;
    } else {
      bH = areaH;
      bW = areaH * bracketAR;
    }

    return Positioned(
      left: printRect.left,
      top: printRect.top,
      width: areaW,
      height: areaH,
      child: ClipRect(
        child: Center(
          child: SizedBox(
            width: bW,
            height: bH,
            child: CustomPaint(
              size: Size(bW, bH),
              painter: BracketPrintCanvas(
                bracketTitle: sanitized.bracketTitle,
                championName: sanitized.championName,
                teamCount: sanitized.teamCount,
                teams: sanitized.teams,
                picks: sanitized.picks,
                palette: palette,
                renderMode: BracketRenderMode.bracketPreview,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
