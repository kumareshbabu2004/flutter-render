import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';

/// Named text styles for consistent typography across the app.
/// Eliminates the 15 different ad-hoc font size combinations.
class BmbTextStyles {
  BmbTextStyles._();

  // ─── DISPLAY / HEADLINES (ClashDisplay font) ──────────────────────────

  static TextStyle headline1 = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 24,
    fontWeight: BmbFontWeights.bold,
    fontFamily: 'ClashDisplay',
  );

  static TextStyle headline2 = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 20,
    fontWeight: BmbFontWeights.bold,
    fontFamily: 'ClashDisplay',
  );

  static TextStyle headline3 = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 18,
    fontWeight: BmbFontWeights.bold,
    fontFamily: 'ClashDisplay',
  );

  // ─── SUBTITLES ────────────────────────────────────────────────────────

  static TextStyle subtitle1 = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 16,
    fontWeight: BmbFontWeights.semiBold,
  );

  static TextStyle subtitle2 = TextStyle(
    color: BmbColors.textSecondary,
    fontSize: 14,
    fontWeight: BmbFontWeights.semiBold,
  );

  // ─── BODY TEXT ────────────────────────────────────────────────────────

  static TextStyle bodyLarge = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 14,
    fontWeight: BmbFontWeights.regular,
  );

  static TextStyle body = TextStyle(
    color: BmbColors.textPrimary,
    fontSize: 13,
    fontWeight: BmbFontWeights.regular,
  );

  static TextStyle bodySecondary = TextStyle(
    color: BmbColors.textSecondary,
    fontSize: 13,
    fontWeight: BmbFontWeights.regular,
  );

  static TextStyle bodySmall = TextStyle(
    color: BmbColors.textSecondary,
    fontSize: 12,
    fontWeight: BmbFontWeights.regular,
  );

  // ─── CAPTIONS / LABELS ────────────────────────────────────────────────

  static TextStyle caption = TextStyle(
    color: BmbColors.textTertiary,
    fontSize: 11,
    fontWeight: BmbFontWeights.regular,
  );

  static TextStyle captionBold = TextStyle(
    color: BmbColors.textTertiary,
    fontSize: 11,
    fontWeight: BmbFontWeights.bold,
  );

  static TextStyle label = TextStyle(
    color: BmbColors.textSecondary,
    fontSize: 13,
    fontWeight: BmbFontWeights.semiBold,
  );

  // ─── BUTTON TEXT ──────────────────────────────────────────────────────

  static TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: BmbFontWeights.bold,
  );

  static TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: BmbFontWeights.semiBold,
  );

  // ─── UTILITY ──────────────────────────────────────────────────────────

  /// Create a copy of any style with a different color.
  static TextStyle withColor(TextStyle style, Color color) =>
      style.copyWith(color: color);
}
