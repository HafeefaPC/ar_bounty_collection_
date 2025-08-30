import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/core/theme/app_theme.dart';

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

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _gradientController.forward();
    
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      context.go('/wallet/connect');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryColor.withValues(alpha: 0.1),
              AppTheme.secondaryColor.withValues(alpha: 0.1),
              AppTheme.accentColor.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Spacer
              SizedBox(height: screenHeight * 0.15),
              
              // Logo Animation
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: Curves.elasticOut.transform(_logoController.value),
                    child: Container(
                      width: screenWidth * 0.2,
                      height: screenWidth * 0.2,
                      constraints: const BoxConstraints(
                        maxWidth: 100,
                        maxHeight: 100,
                        minWidth: 70,
                        minHeight: 70,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 25,
                            spreadRadius: 8,
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: screenWidth * 0.12,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: screenHeight * 0.05),
              
              // App Name Animation
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _textController.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _textController.value)),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: Column(
                          children: [
                            Text(
                              'FaceReflector',
                              style: TextStyle(
                                fontSize: screenWidth * 0.065,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  Shadow(
                                    offset: const Offset(0, 2),
                                    blurRadius: 4,
                                    color: Colors.black.withValues(alpha: 0.3),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: screenHeight * 0.012),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'AR-Powered Event Goodies',
                                style: TextStyle(
                                  fontSize: screenWidth * 0.032,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              SizedBox(height: screenHeight * 0.06),
              
              // Loading Animation
              AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _gradientController.value,
                    child: Column(
                      children: [
                        Container(
                          width: screenWidth * 0.12,
                          height: screenWidth * 0.12,
                          constraints: const BoxConstraints(
                            maxWidth: 50,
                            maxHeight: 50,
                            minWidth: 35,
                            minHeight: 35,
                          ),
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.02),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            fontSize: screenWidth * 0.035,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              // Bottom Spacer
              SizedBox(height: screenHeight * 0.15),
            ],
          ),
        ),
      ),
    );
  }
}
