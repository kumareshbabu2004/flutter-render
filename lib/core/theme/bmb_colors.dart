import 'package:flutter/material.dart';

class BmbColors {
  BmbColors._();

  // Brand Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color darkBlue = Color(0xFF0D1454);
  static const Color blue = Color(0xFF2137FF);
  static const Color ddBlue = Color(0xFF010433);
  static const Color greyBlue = Color(0xFF3D4376);
  static const Color yellow = Color(0xFFF8E11A);
  static const Color bluish = Color(0xFF999BCD);

  // Enhanced Theme Colors
  static const Color deepNavy = Color(0xFF0A0E27);
  static const Color midNavy = Color(0xFF141B3D);
  static const Color lightNavy = Color(0xFF1E2651);
  static const Color cardGradientStart = Color(0xFF1A2244);
  static const Color cardGradientEnd = Color(0xFF252D5A);
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFE44D);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color buttonPrimary = Color(0xFF36B37E);
  static const Color buttonGlow = Color(0xFF2D9A6B);
  static const Color errorRed = Color(0xFFE53935);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8D4);
  static const Color textTertiary = Color(0xFF7A82A1);
  static const Color borderColor = Color(0xFF2A3260);
  static const Color cardDark = Color(0xFF252949);

  // VIP Colors
  static const Color vipPurple = Color(0xFF9B59FF);
  static const Color vipPurpleLight = Color(0xFFB57FFF);
  static const Color vipPurpleDark = Color(0xFF7B3FDF);

  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepNavy, midNavy, lightNavy],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardGradientStart, cardGradientEnd],
  );
}
