import 'package:flutter/material.dart';
import 'package:bmb_mobile/core/theme/bmb_colors.dart';
import 'package:bmb_mobile/core/theme/bmb_font_weights.dart';
import 'package:bmb_mobile/core/theme/bmb_radius.dart';

/// Standardized button styles for consistent UI.
///
/// Hierarchy:
/// - **primary** (Blue)       → Main CTA / action
/// - **premium** (Gold)       → BMB+, VIP, or premium actions
/// - **success** (Green)      → Confirm, submit, go-live
/// - **danger**  (Red)        → Delete, destructive
/// - **surface** (MidNavy)    → Secondary / card-level actions
class BmbButtonStyles {
  BmbButtonStyles._();

  // ─── ELEVATED (filled) ────────────────────────────────────────────────

  static ButtonStyle primary = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.blue,
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  );

  static ButtonStyle primarySmall = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.blue,
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.semiBold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  );

  static ButtonStyle premium = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.gold,
    foregroundColor: Colors.black,
    textStyle: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  );

  static ButtonStyle success = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.successGreen,
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  );

  static ButtonStyle danger = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.errorRed,
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontSize: 16, fontWeight: BmbFontWeights.bold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  );

  static ButtonStyle surface = ElevatedButton.styleFrom(
    backgroundColor: BmbColors.midNavy,
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontSize: 14, fontWeight: BmbFontWeights.semiBold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  // ─── OUTLINED ─────────────────────────────────────────────────────────

  static ButtonStyle outlinedPrimary = OutlinedButton.styleFrom(
    foregroundColor: BmbColors.blue,
    side: BorderSide(color: BmbColors.blue.withValues(alpha: 0.5)),
    textStyle: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.semiBold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  static ButtonStyle outlinedDanger = OutlinedButton.styleFrom(
    foregroundColor: BmbColors.errorRed,
    side: BorderSide(color: BmbColors.errorRed.withValues(alpha: 0.5)),
    textStyle: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.semiBold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  static ButtonStyle outlinedGold = OutlinedButton.styleFrom(
    foregroundColor: BmbColors.gold,
    side: BorderSide(color: BmbColors.gold.withValues(alpha: 0.4)),
    textStyle: TextStyle(fontSize: 13, fontWeight: BmbFontWeights.semiBold),
    shape: RoundedRectangleBorder(borderRadius: BmbRadius.medium),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );
}
