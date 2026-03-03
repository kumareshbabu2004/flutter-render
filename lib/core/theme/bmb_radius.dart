import 'package:flutter/material.dart';

/// Standardized border radius values for the entire app.
/// Replaces the 10 different circular() values with 4 consistent tiers.
class BmbRadius {
  BmbRadius._();

  // ─── Raw values ───────────────────────────────────────────────────────
  static const double smallValue = 8.0;
  static const double mediumValue = 12.0;
  static const double largeValue = 16.0;
  static const double xlValue = 20.0;

  // ─── BorderRadius shortcuts ───────────────────────────────────────────
  static BorderRadius get small => BorderRadius.circular(smallValue);
  static BorderRadius get medium => BorderRadius.circular(mediumValue);
  static BorderRadius get large => BorderRadius.circular(largeValue);
  static BorderRadius get xl => BorderRadius.circular(xlValue);
}
