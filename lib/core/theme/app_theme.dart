import 'package:flutter/material.dart';

class AppTheme {
  // Retro Color Palette inspired by RetroUI
  static const Color primaryColor = Color(0xFF00FF41); // Matrix Green
  static const Color secondaryColor = Color(0xFFFF6B35); // Retro Orange
  static const Color accentColor = Color(0xFF4ECDC4); // Retro Teal
  static const Color backgroundColor = Color(0xFF1A1A1A); // Dark Background
  static const Color surfaceColor = Color(0xFF2D2D2D); // Dark Surface
  static const Color textColor = Color(0xFFFFFFFF); // White Text
  static const Color successColor = Color(0xFF00FF88); // Bright Green
  static const Color errorColor = Color(0xFFFF4757); // Retro Red
  static const Color warningColor = Color(0xFFFFA502); // Retro Yellow
  static const Color infoColor = Color(0xFF3742FA); // Retro Blue

  // Retro Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF41),
      Color(0xFF00CC33),
      Color(0xFF009926),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF6B35),
      Color(0xFFFF8C42),
      Color(0xFFFFA500),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient retroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF00FF41),
      Color(0xFF4ECDC4),
      Color(0xFFFF6B35),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1A1A1A),
      Color(0xFF2D2D2D),
      Color(0xFF000000),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Retro Text Styles
  static const TextStyle retroTitle = TextStyle(
    fontFamily: 'Courier',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textColor,
    letterSpacing: 2.0,
    shadows: [
      Shadow(
        offset: Offset(2, 2),
        blurRadius: 0,
        color: primaryColor,
      ),
    ],
  );

  static const TextStyle retroSubtitle = TextStyle(
    fontFamily: 'Courier',
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textColor,
    letterSpacing: 1.0,
  );

  static const TextStyle retroBody = TextStyle(
    fontFamily: 'Courier',
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textColor,
    letterSpacing: 0.5,
  );

  static const TextStyle retroButton = TextStyle(
    fontFamily: 'Courier',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: textColor,
    letterSpacing: 1.0,
  );

  // Retro Button Styles
  static ButtonStyle retroPrimaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: backgroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: textColor, width: 2),
    ),
    elevation: 8,
    shadowColor: primaryColor.withOpacity(0.5),
  );

  static ButtonStyle retroSecondaryButton = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: backgroundColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: textColor, width: 2),
    ),
    elevation: 8,
    shadowColor: secondaryColor.withOpacity(0.5),
  );

  static ButtonStyle retroOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: textColor,
    side: const BorderSide(color: primaryColor, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  // Retro Input Decoration
  static InputDecoration retroInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: primaryColor) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: accentColor, width: 3),
      ),
      filled: true,
      fillColor: surfaceColor,
      labelStyle: const TextStyle(color: primaryColor, fontFamily: 'Courier'),
      hintStyle: TextStyle(color: textColor.withOpacity(0.5), fontFamily: 'Courier'),
    );
  }

  // Retro Card Decoration
  static BoxDecoration retroCardDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: primaryColor, width: 2),
    boxShadow: [
      BoxShadow(
        color: primaryColor.withOpacity(0.3),
        offset: const Offset(4, 4),
        blurRadius: 0,
      ),
    ],
  );

  // Retro Container Decoration
  static BoxDecoration retroContainerDecoration = BoxDecoration(
    color: surfaceColor,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: secondaryColor, width: 2),
    boxShadow: [
      BoxShadow(
        color: secondaryColor.withOpacity(0.3),
        offset: const Offset(3, 3),
        blurRadius: 0,
      ),
    ],
  );

  // Retro Progress Indicator Style
  static const double retroProgressHeight = 8.0;

  // Retro App Bar Theme
  static const AppBarTheme retroAppBarTheme = AppBarTheme(
    backgroundColor: backgroundColor,
    foregroundColor: textColor,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'Courier',
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: textColor,
      letterSpacing: 1.0,
    ),
  );

  // Retro Scaffold Background
  static const BoxDecoration retroScaffoldBackground = BoxDecoration(
    gradient: darkGradient,
  );

  // Retro Glow Effect
  static List<BoxShadow> retroGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.5),
      offset: const Offset(0, 0),
      blurRadius: 20,
      spreadRadius: 2,
    ),
    BoxShadow(
      color: color.withOpacity(0.3),
      offset: const Offset(0, 0),
      blurRadius: 40,
      spreadRadius: 4,
    ),
  ];

  // Retro Pixel Border
  static BoxDecoration retroPixelBorder(Color color) => BoxDecoration(
    border: Border.all(color: color, width: 2),
    borderRadius: BorderRadius.circular(0), // Sharp corners for pixelated look
  );

  // Retro Animated Container
  static BoxDecoration retroAnimatedContainer({
    required Color color,
    bool isGlowing = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: textColor, width: 2),
      boxShadow: isGlowing ? retroGlow(color) : [
        BoxShadow(
          color: color.withOpacity(0.3),
          offset: const Offset(3, 3),
          blurRadius: 0,
        ),
      ],
    );
  }
}
