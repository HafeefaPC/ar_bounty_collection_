import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import '../../shared/widgets/tokon_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _gradientController;
  late AnimationController _scanlineController;

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _gradientController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scanlineController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 600));
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 400));
    _gradientController.forward();
    _scanlineController.repeat();
    
    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      // Always go to wallet connect first
      context.go('/wallet/connect');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _gradientController.dispose();
    _scanlineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple Logo
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: TokonLogo(
                size: 80,
                showText: true,
                coinColor: AppTheme.primaryColor,
                textColor: AppTheme.textColor,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Name
            Text(
              'TOKON',
              style: AppTheme.modernTitle.copyWith(
                fontSize: 32,
                color: AppTheme.textColor,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'AR-Powered Event Goodies',
              style: AppTheme.modernBodySecondary.copyWith(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            
            const SizedBox(height: 48),
            
            // Simple Loading
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              strokeWidth: 3,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Loading...',
              style: AppTheme.modernBody.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

