import 'package:flutter/material.dart';

class RetroTheme {
  // Retro green color palette for pixelated UI
  static const Color darkGreen = Color(0xFF0F3A0F);      // Dark background
  static const Color primaryGreen = Color(0xFF1E5A1E);   // Primary interface
  static const Color brightGreen = Color(0xFF2EFF2E);    // Bright accent
  static const Color lightGreen = Color(0xFF5AFF5A);     // Light accent
  
  // Additional retro colors for variety
  static const Color retroAmber = Color(0xFFFFB000);     // Warning/attention
  static const Color retroRed = Color(0xFFFF2E2E);       // Error/danger
  static const Color retroBlue = Color(0xFF2E2EFF);      // Info/neutral
  
  // Black and white for contrast
  static const Color pixelBlack = Color(0xFF000000);
  static const Color pixelWhite = Color(0xFFFFFFFF);
  static const Color pixelGray = Color(0xFF808080);
  
  // Text styles with pixelated font
  static const String pixelFont = 'Courier'; // Monospace font for retro feel
  
  static TextStyle pixelText({
    Color color = brightGreen,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return TextStyle(
      fontFamily: pixelFont,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
    );
  }
  
  static TextStyle pixelHeading({
    Color color = brightGreen,
    double fontSize = 16,
  }) {
    return TextStyle(
      fontFamily: pixelFont,
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
  }
  
  // Retro button decoration
  static BoxDecoration retroButton({
    Color backgroundColor = primaryGreen,
    Color borderColor = brightGreen,
    double borderWidth = 2,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }
  
  // Retro container decoration
  static BoxDecoration retroContainer({
    Color backgroundColor = darkGreen,
    Color borderColor = primaryGreen,
    double borderWidth = 2,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }
  
  // Pixelated shadow effect
  static List<BoxShadow> pixelShadow({
    Color color = darkGreen,
    double blurRadius = 0,
    Offset offset = const Offset(2, 2),
  }) {
    return [
      BoxShadow(
        color: color,
        blurRadius: blurRadius,
        offset: offset,
      ),
    ];
  }
  
  // Scanline effect decoration
  static Decoration scanlineDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          brightGreen.withOpacity(0.1),
          Colors.transparent,
          brightGreen.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ),
    );
  }
}