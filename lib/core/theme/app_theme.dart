import 'package:flutter/material.dart';

class AppTheme {
  // Cartoon-Related Children-Friendly Color Palette
  static const Color primaryColor = Color(0xFFFFECB3); // Light Yellow (like yellow-200)
  static const Color secondaryColor = Color(0xFFFDD835); // Sunny Yellow
  static const Color accentColor = Color(0xFF4FC3F7); // Sky Blue
  static const Color backgroundColor = Color(0xFFE0F2F7); // Very Light Blue/Pale Cyan
  static const Color surfaceColor = Color(0xFFFFFDE7); // Creamy White
  static const Color cardColor = Color(0xFFFFECB3); // Light Yellow (matching primary)
  static const Color textColor = Color(0xFF424242); // Dark Grey (for readability on light backgrounds)
  static const Color textSecondary = Color(0xFF757575); // Medium Grey
  static const Color successColor = Color(0xFF81C784); // Happy Green
  static const Color errorColor = Color(0xFFEF5350); // Friendly Red
  static const Color warningColor = Color(0xFFFFCA28); // Bright Orange
  static const Color infoColor = Color(0xFF64B5F6); // Soft Blue
  static const Color borderColor = Color(0xFFBBDEFB); // Light Blue Border

  // Cartoon-Friendly Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
       Color.fromARGB(255, 122, 185, 203), // Very Light Blue
      Color.fromARGB(255, 122, 185, 203),  // Light Blue
      Color.fromARGB(255, 122, 185, 203),  // Very Light Blue
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF81C784), // Happy Green
      Color(0xFF64B5F6), // Soft Blue
      Color(0xFFFFA000), // Deeper Orange
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFECB3), // Light Yellow
      Color(0xFFFFF9C4), // Very Light Yellow
    ],
    stops: [0.0, 1.0],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
       Color(0xFFFFECB3), // Very Light Blue
      Color(0xFFFFECB3), // Light Blue
      Color(0xFFFFECB3), // Very Light Blue
    
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // Cartoon-Friendly Text Styles (adjusted for readability on lighter backgrounds)
  // Using a more playful font if you have one, or a clean sans-serif.
  // I'll keep SF Pro Display/Text for now, but adjust colors.
  static const TextStyle modernTitle = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: Color.fromARGB(255, 96, 164, 113), // Darker text for readability
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
    color: textSecondary, // Medium grey for secondary text
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle modernButton = TextStyle(
    fontFamily: 'SF Pro Display',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textColor, // Darker text for buttons
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

  // Additional text styles for compatibility (colors adjusted)
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

  // Cartoon-Friendly Button Styles
  static ButtonStyle modernPrimaryButton = ElevatedButton.styleFrom(
    backgroundColor: const Color.fromARGB(255, 122, 185, 203), // Sunny Yellow
    foregroundColor: textColor, // Dark text
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    elevation: 4, // Add a bit of friendly elevation
    shadowColor: secondaryColor.withOpacity(0.4),
  );

  static ButtonStyle modernSecondaryButton = ElevatedButton.styleFrom(
    backgroundColor: surfaceColor, // Creamy White
    foregroundColor: textColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: accentColor, width: 2), // Sky Blue border
    ),
    elevation: 2,
    shadowColor: Colors.black.withOpacity(0.1),
  );

  static ButtonStyle modernOutlinedButton = OutlinedButton.styleFrom(
    foregroundColor: accentColor, // Sky Blue text
    side: const BorderSide(color: accentColor, width: 2),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static ButtonStyle modernTextButton = TextButton.styleFrom(
    foregroundColor: accentColor, // Sky Blue
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  );

  // Cartoon-Friendly Input Decoration
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
        borderSide: const BorderSide(color: borderColor), // Light blue border
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accentColor, width: 2), // Sky Blue focus
      ),
      filled: true,
      fillColor: surfaceColor, // Creamy white fill
      labelStyle: const TextStyle(color: textSecondary, fontFamily: 'SF Pro Text'),
      hintStyle: const TextStyle(color: textSecondary, fontFamily: 'SF Pro Text'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  // Cartoon-Friendly Card Decoration
  static BoxDecoration modernCardDecoration = BoxDecoration(
    gradient: cardGradient, // Light yellow gradient
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderColor, width: 1), // Light blue border
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1), // Softer shadow
        offset: const Offset(0, 8),
        blurRadius: 16,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        offset: const Offset(0, 2),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ],
  );

  // Cartoon-Friendly Container Decoration
  static BoxDecoration modernContainerDecoration = BoxDecoration(
    color: cardColor, // Light yellow color
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor, width: 1), // Light blue border
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1), // Softer shadow
        offset: const Offset(0, 4),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  // Modern Progress Indicator Style (color changed)
  static const double modernProgressHeight = 4.0;

  // Modern App Bar Theme (colors adjusted)
  static const AppBarTheme modernAppBarTheme = AppBarTheme(
    backgroundColor: primaryColor, // Use a solid color for app bar if desired
    foregroundColor: textColor,
    elevation: 2, // A little elevation for depth
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontFamily: 'SF Pro Display',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: textColor,
      letterSpacing: -0.3,
    ),
  );

  // Modern Scaffold Background (now a gradient of light blues)
  static const BoxDecoration modernScaffoldBackground = BoxDecoration(
    gradient: backgroundGradient,
  );

  // Modern Glow Effect (colors adjusted for brighter glow)
  static List<BoxShadow> modernGlow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.4), // Brighter glow
      offset: const Offset(0, 0),
      blurRadius: 20,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: color.withOpacity(0.2),
      offset: const Offset(0, 0),
      blurRadius: 40,
      spreadRadius: 0,
    ),
  ];

  // Modern Border (color changed)
  static BoxDecoration modernBorder(Color color) => BoxDecoration(
    border: Border.all(color: color, width: 2), // Slightly thicker border
    borderRadius: BorderRadius.circular(16),
  );

  // Modern Animated Container (colors adjusted)
  static BoxDecoration modernAnimatedContainer({
    required Color color,
    bool isGlowing = false,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor, width: 1), // Light blue border
      boxShadow: isGlowing ? modernGlow(color) : [
        BoxShadow(
          color: Colors.black.withOpacity(0.1), // Softer shadow
          offset: const Offset(0, 4),
          blurRadius: 8,
          spreadRadius: 0,
        ),
      ],
    );
  }

  // Modern Glass Effect (adjusted for brighter, cartoon look)
  static BoxDecoration modernGlassEffect = BoxDecoration(
    color: Colors.white.withOpacity(0.4), // More opaque for a visible "glass"
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withOpacity(0.6), width: 1), // More visible border
    boxShadow: [
      BoxShadow(
        color: Colors.blue.shade100.withOpacity(0.5), // Lighter, playful shadow
        offset: const Offset(0, 8),
        blurRadius: 24,
        spreadRadius: 0,
      ),
    ],
  );
}