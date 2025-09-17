import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:face_reflector/core/theme/app_theme.dart'; // No longer needed for this simplified UI
import 'package:face_reflector/shared/providers/reown_provider.dart';
// import '../../shared/widgets/tokon_logo.dart'; // No longer needed, we'll use Image.asset directly

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  // Removed all AnimationControllers as they are no longer needed for the simplified UI

  @override
  void initState() {
    super.initState();
    _startNavigationTimer(); // Renamed for clarity, focuses on navigation
  }

  void _startNavigationTimer() async {
    // Keep the navigation delay, adjust as needed if the animation was part of the delay feel
    await Future.delayed(const Duration(milliseconds: 2500)); // Adjusted delay as animations are gone

    if (mounted) {
      // Check wallet connection status and navigate accordingly
      final walletState = ref.read(walletConnectionProvider);
      if (walletState.isConnected) {
        context.go('/wallet/options');
      } else {
        context.go('/wallet/connect');
      }
    }
  }

  @override
  void dispose() {
    // No controllers to dispose of
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.yellow.shade200, // Set background to yellow-200
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Display the new logo from assets
            Image.asset(
              'assets/icons/icons.png', // Your new logo path
              width: screenWidth * 0.4, // Adjust size as needed
              height: screenWidth * 0.4, // Adjust size as needed
            ),
            const SizedBox(height: 24), // Spacing between logo and text
            // Display the app name "TOKON"
            Text(
              'TOKON',
              style: TextStyle(
                fontSize: screenWidth * 0.08,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800, // A darker color for text on yellow
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// The ModernBackgroundPainter class is no longer needed and can be removed
// as the background is now a simple solid color.
// If you remove it, also remove the import statement for app_theme.dart
// and any references to AppTheme.modernScaffoldBackground.