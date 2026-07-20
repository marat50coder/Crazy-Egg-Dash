import 'package:flutter/material.dart';

/// Bright, cartoon-styled palette that matches the app icon: warm sky blues,
/// sunny yellows and playful reds.
class AppColors {
  AppColors._();

  static const Color skyTop = Color(0xFF2FA8F7);
  static const Color skyBottom = Color(0xFF9BE0FF);
  static const Color sunYellow = Color(0xFFFFC627);
  static const Color sunYellowDark = Color(0xFFF5A623);
  static const Color eggWhite = Color(0xFFFFF8E7);
  static const Color combRed = Color(0xFFE8412E);
  static const Color grassGreen = Color(0xFF6BBF3A);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panelShadow = Color(0x33003A66);
  static const Color textDark = Color(0xFF3A2A16);
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color coinGold = Color(0xFFFFC627);
  static const Color featherTeal = Color(0xFF37C7B8);
  static const Color crystalPurple = Color(0xFF9B6BF0);
  static const Color danger = Color(0xFFE8412E);
  static const Color locked = Color(0xFFBFC7CE);

  // Warm "paper" tones for cards/panels — gives a richer, storybook feel.
  static const Color paper = Color(0xFFFFFDF6);
  static const Color paperDeep = Color(0xFFF6E7C8);
  static const Color paperEdge = Color(0xFFE7CF9E);
  static const Color ink = Color(0xFF3A2A16);
}

/// A few shared gradients reused across screens for a cohesive look.
class AppGradients {
  AppGradients._();

  static const LinearGradient sky = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.skyTop, AppColors.skyBottom],
  );

  static const LinearGradient sunButton = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.sunYellow, AppColors.sunYellowDark],
  );

  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.paper, AppColors.paperDeep],
  );

  static const LinearGradient header = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD34D), AppColors.sunYellowDark],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.sunYellow,
      scaffoldBackgroundColor: AppColors.skyBottom,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.textDark,
      ),
    );
  }
}

/// Text style helpers that give headings the chunky, outlined cartoon feel.
class AppText {
  AppText._();

  static TextStyle title(double size, {Color color = AppColors.textLight}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.5,
      height: 1.05,
      shadows: const [
        Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4),
      ],
    );
  }

  static TextStyle body(double size, {Color color = AppColors.textDark}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color,
    );
  }
}
