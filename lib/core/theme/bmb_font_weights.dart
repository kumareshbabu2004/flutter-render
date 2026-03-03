import 'dart:ui';

class BmbFontWeights {
  // FontVariation-based weights for ClashDisplay variable font
  static List<FontVariation> w100 = [const FontVariation('wght', 100)];
  static List<FontVariation> w200 = [const FontVariation('wght', 200)];
  static List<FontVariation> w300 = [const FontVariation('wght', 300)];
  static List<FontVariation> w400 = [const FontVariation('wght', 400)];
  static List<FontVariation> w500 = [const FontVariation('wght', 500)];
  static List<FontVariation> w600 = [const FontVariation('wght', 600)];
  static List<FontVariation> w700 = [const FontVariation('wght', 700)];

  // Named aliases for convenience
  static FontWeight get light => FontWeight.w300;
  static FontWeight get regular => FontWeight.w400;
  static FontWeight get medium => FontWeight.w500;
  static FontWeight get semiBold => FontWeight.w600;
  static FontWeight get bold => FontWeight.w700;
  static FontWeight get extraBold => FontWeight.w800;
}
