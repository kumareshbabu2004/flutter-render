import 'package:flutter/material.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';

/// Renders a garment mockup image with correct colour matching.
///
/// Consumes a [ResolvedColorImage] (produced by
/// [PrintProduct.resolveColorImage]) and displays it as either:
///   - A direct network/asset image (exactMockup strategy, or tintBase
///     where the selected colour IS the base colour).
///   - A base image with an HSL tint overlay (tintBase strategy, selected
///     colour differs from base colour).
///
/// The compositor **never** shows the wrong colour: it either loads the
/// exact CDN photo or recolours the base photo to match the selected
/// garment colour.
///
/// When [isFlipped] is true the image is horizontally mirrored (used to
/// synthesise a back view from a front-only mockup photo).
class ColorMatchedImage extends StatelessWidget {
  /// The resolved colour image to display.
  final ResolvedColorImage resolved;

  /// How the image fits inside its layout box.
  final BoxFit fit;

  /// Whether to horizontally flip the image (back view from front photo).
  final bool isFlipped;

  /// Fallback widget when the image fails to load.
  final Color fallbackColor;

  const ColorMatchedImage({
    super.key,
    required this.resolved,
    this.fit = BoxFit.contain,
    this.isFlipped = false,
    this.fallbackColor = const Color(0xFF1A1A1A),
  });

  @override
  Widget build(BuildContext context) {
    // Build the raw image widget.
    Widget imageWidget = _buildRawImage();

    // Apply HSL tint overlay if the resolver says so.
    if (resolved.needsTint) {
      imageWidget = _applyTint(imageWidget, resolved.tintColor!);
    }

    // Flip horizontally for back-view-from-front.
    if (isFlipped || resolved.isFlippedFront) {
      imageWidget = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Build the base image widget (network or asset).
  Widget _buildRawImage() {
    if (resolved.localAsset != null) {
      return Image.asset(
        resolved.localAsset!,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: fallbackColor),
      );
    }
    if (resolved.networkUrl != null) {
      return Image.network(
        resolved.networkUrl!,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(color: fallbackColor),
      );
    }
    return Container(color: fallbackColor);
  }

  /// Apply an HSL tint that recolours the garment fabric while
  /// preserving the luminance channel (folds, stitching, shadows).
  ///
  /// Technique: Paint the tint colour with [BlendMode.color] on top of
  /// the base image.  `BlendMode.color` replaces hue + saturation of
  /// the destination (base photo) with the source (tint), keeping the
  /// luminance from the photo.  This preserves fabric detail.
  ///
  /// Alpha is sourced from [ResolvedColorImage.tintAlpha] which
  /// defaults to [kTintBaseAlpha] (0.72) but can be overridden
  /// per-product via [PrintProduct.tintAlpha].
  Widget _applyTint(Widget baseImage, Color tint) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        tint.withValues(alpha: resolved.tintAlpha),
        BlendMode.color,
      ),
      child: baseImage,
    );
  }
}

/// Builds a [Positioned.fill] garment image using the colour-matching
/// system.
///
/// This is a convenience function for the preview compositors. It:
///   1. Calls [product.resolveColorImage] (or falls back to legacy).
///   2. Wraps the result in a [ColorMatchedImage].
///   3. Returns a [Positioned.fill] widget ready for the Stack.
///
/// If [product] is null, falls back to [legacyUrl] with no tinting.
Widget buildColorMatchedGarmentLayer({
  required PrintProduct? product,
  required String view,
  required GarmentColor garmentColor,
  // Legacy fallbacks (used when product is null).
  String? legacyFrontUrl,
  String? legacyBackAsset,
  String? legacyFrontImageUrl,
}) {
  if (product != null) {
    final resolved = product.resolveColorImage(
      colorName: garmentColor.name,
      view: view,
      garmentColor: garmentColor,
    );

    if (resolved.bestSource == null &&
        resolved.networkUrl == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: ColorMatchedImage(
        resolved: resolved,
        fallbackColor: garmentColor.color,
      ),
    );
  }

  // Legacy path: no product object.
  if (legacyFrontUrl != null) {
    final isFront = view == 'front';
    Widget child = Image.network(
      legacyFrontUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Container(color: garmentColor.color),
    );
    if (!isFront) {
      child = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
        child: child,
      );
    }
    return Positioned.fill(child: child);
  }

  if (legacyBackAsset != null && view == 'back') {
    return Positioned.fill(
      child: Image.asset(
        legacyBackAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Container(color: garmentColor.color),
      ),
    );
  }

  return const SizedBox.shrink();
}
