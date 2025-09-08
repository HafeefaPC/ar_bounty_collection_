import 'package:flutter/material.dart';

class AppTheme {
  // Modern Color Palette inspired by Sinport design
  static const Color primaryColor = Color(0xFF6366F1); // Modern Indigo
  static const Color secondaryColor = Color(0xFF8B5CF6); // Modern Purple
  static const Color accentColor = Color(0xFF06B6D4); // Modern Cyan
  static const Color backgroundColor = Color(0xFF0F0F23); // Deep Dark Blue
  static const Color surfaceColor = Color(0xFF1E1E3F); // Dark Surface
  static const Color cardColor = Color(0xFF2A2A4A); // Card Background
  static const Color textColor = Color(0xFFFFFFFF); // White Text
  static const Color textSecondary = Color(0xFF94A3B8); // Secondary Text
  static const Color successColor = Color(0xFF10B981); // Modern Green
  static const Color errorColor = Color(0xFFEF4444); // Modern Red
  static const Color warningColor = Color(0xFFF59E0B); // Modern Amber
  static const Color infoColor = Color(0xFF3B82F6); // Modern Blue
  static const Color borderColor = Color(0xFF374151); // Border Color

  // Modern Gradients inspired by Sinport
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF8B5CF6),
      Color(0xFF06B6D4),
      Color(0xFF10B981),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2A2A4A),
      Color(0xFF1E1E3F),
    ],
    stops: [0.0, 1.0],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0F0F23),
      Color(0xFF1E1E3F),
      Color(0xFF0F0F23),
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Modern Text Styles inspired by Sinport
  static const TextStyle modernTitle = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: textColor,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle modernSubtitle = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textColor,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle modernBody = TextStyle(
    fontFamily: 'SF Pro Text',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textColor,
    letterSpacing: -0.2,
    height: 1.5,
  );

  static const TextStyle modernBodySecondary = TextStyle(
    fontFamily: 'SF Pro Text',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle modernButton = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textColor,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle modernCaption = TextStyle(
    fontFamily: 'SF Pro Text',
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.0,
    height: 1.3,
  );

  // Additional text styles for compatibility
  static const TextStyle modernHeadlineSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textColor,
    fontFamily: 'SF Pro Text',
    letterSpacing: 0.15,
  );

  static const TextStyle modernBodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: textColor,
    fontFamily: 'SF Pro Text',
    letterSpacing: 0.5,
  );

  static const TextStyle modernBodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textColor,
    fontFamily: 'SF Pro Text',
    letterSpacing: 0.25,
  );

  static const TextStyle modernBodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary,
    fontFamily: 'SF Pro Text',
    letterSpacing: 0.4,
  );

  static const TextStyle modernLabelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textColor,
    fontFamily: 'SF Pro Text',
    letterSpacing: 0.1,
  );

  // Modern Button Styles inspired by Sinport
  static ButtonStyle modernPrimaryButton = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: textColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 0,
    shadowColor: Colors.transparent,
  );

  static ButtonStyle modernSecondaryButton = ElevatedButton.styleFrom(
    backgroundColor: cardColor,
    foregroundColor: textColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: primaryColor, width: 1),
    ),
    elevation: 0,
    shadowColor: Colors.transparent,
  );

  static ButtonStyle modernOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: textColor,
    side: const BorderSide(color: primaryColor, width: 1),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static ButtonStyle modernTextButton = TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Modern Input Decoration inspired by Sinport
  static InputDecoration modernInputDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: textSecondary, size: 20) : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      filled: true,
      fillColor: cardColor,
      labelStyle: const TextStyle(color: textSecondary, fontFamily: 'SF Pro Text'),
      hintStyle: const TextStyle(color: textSecondary, fontFamily: 'SF Pro Text'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // Modern Card Decoration inspired by Sinport
  static BoxDecoration modernCardDecoration = BoxDecoration(
    gradient: cardGradient,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        offset: const Offset(0, 2),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  // Modern Container Decoration
  static BoxDecoration modernContainerDecoration = BoxDecoration(
    color: cardColor,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        offset: const Offset(0, 4),
        blurRadius: 12,
        spreadRadius: 0,
      ),
    ],
  );

  // Modern Progress Indicator Style
  static const double modernProgressHeight = 4.0;

  // Modern App Bar Theme
  static const AppBarTheme modernAppBarTheme = AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: textColor,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'SF Pro Display',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textColor,
      letterSpacing: -0.3,
    ),
  );

  // Modern Scaffold Background
  static const BoxDecoration modernScaffoldBackground = BoxDecoration(
    gradient: backgroundGradient,
  );

  // Modern Glow Effect
  static List<BoxShadow> modernGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.3),
      offset: const Offset(0, 0),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: color.withOpacity(0.1),
      offset: const Offset(0, 0),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  // Modern Border
  static BoxDecoration modernBorder(Color color) => BoxDecoration(
    border: Border.all(color: color, width: 1),
    borderRadius: BorderRadius.circular(16),
  );

  // Modern Animated Container
  static BoxDecoration modernAnimatedContainer({
    required Color color,
    bool isGlowing = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      boxShadow: isGlowing ? modernGlow(color) : [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Modern Glass Effect
  static BoxDecoration modernGlassEffect = BoxDecoration(
    color: Colors.white.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        offset: const Offset(0, 8),
        blurRadius: 32,
        spreadRadius: 0,
      ),
    ],
  );
}
