import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:face_reflector/core/theme/app_theme.dart';
import 'package:face_reflector/shared/providers/reown_provider.dart';
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
    _logoController.dispose();
    _textController.dispose();
    _gradientController.dispose();
    _scanlineController.dispose();
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
        decoration: AppTheme.modernScaffoldBackground,
        child: Stack(
          children: [
            // Modern Background Pattern
            AnimatedBuilder(
              animation: _scanlineController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ModernBackgroundPainter(
                    progress: _scanlineController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
            
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Modern decorative element
                    Container(
                      width: screenWidth * 0.4,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.05),
                    
                    // Modern TOKON Logo Animation
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: Curves.elasticOut.transform(_logoController.value),
                          child: AnimatedBuilder(
                            animation: _scanlineController,
                            builder: (context, child) {
                              final pulseScale = 1.0 + (0.05 * (1 - _scanlineController.value));
                              return Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: AppTheme.modernGlassEffect.copyWith(
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        offset: const Offset(0, 0),
                                        blurRadius: 40,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: TokonLogo(
                                    size: screenWidth * 0.25,
                                    showText: true,
                                    coinColor: AppTheme.primaryColor,
                                    textColor: AppTheme.textColor,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: screenHeight * 0.05),
                    
                    // Modern App Name Animation
                    AnimatedBuilder(
                      animation: _textController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textController.value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _textController.value)),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                              child: Column(
                                children: [
                                  Text(
                                    'TOKON',
                                    style: AppTheme.modernTitle.copyWith(
                                      fontSize: screenWidth * 0.08,
                                      color: AppTheme.textColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: screenHeight * 0.02),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: AppTheme.modernContainerDecoration,
                                    child: Text(
                                      'AR-Powered Event Goodies',
                                      style: AppTheme.modernBodySecondary.copyWith(
                                        fontSize: screenWidth * 0.04,
                                        color: AppTheme.textSecondary,
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
                    
                    // Modern Loading Animation
                    AnimatedBuilder(
                      animation: _gradientController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _gradientController.value,
                          child: Column(
                            children: [
                              // Modern Loading Spinner
                              Container(
                                width: screenWidth * 0.2,
                                height: screenWidth * 0.2,
                                constraints: const BoxConstraints(
                                  maxWidth: 80,
                                  maxHeight: 80,
                                  minWidth: 60,
                                  minHeight: 60,
                                ),
                                decoration: AppTheme.modernGlassEffect,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: AnimatedBuilder(
                                    animation: _scanlineController,
                                    builder: (context, child) {
                                      return CircularProgressIndicator(
                                        value: (_scanlineController.value * 0.6) + 0.2,
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textColor),
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.03),
                              
                              // Loading Text with Animation
                              AnimatedBuilder(
                                animation: _scanlineController,
                                builder: (context, child) {
                                  final dots = '...'.substring(0, ((_scanlineController.value * 3).floor() + 1).clamp(0, 3));
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    decoration: AppTheme.modernContainerDecoration,
                                    child: Text(
                                      'Loading$dots',
                                      style: AppTheme.modernButton.copyWith(
                                        fontSize: screenWidth * 0.04,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              SizedBox(height: screenHeight * 0.02),
                              
                              // Subtitle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: AppTheme.modernContainerDecoration.copyWith(
                                  color: AppTheme.cardColor.withOpacity(0.5),
                                ),
                                child: Text(
                                  'Preparing your AR experience...',
                                  style: AppTheme.modernBodySecondary.copyWith(
                                    fontSize: screenWidth * 0.035,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    
                    SizedBox(height: screenHeight * 0.05),
                    
                    // Modern decorative element
                    Container(
                      width: screenWidth * 0.4,
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Modern background painter with subtle effects
class ModernBackgroundPainter extends CustomPainter {
  final double progress;

  ModernBackgroundPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a subtle gradient background
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.primaryColor.withOpacity(0.03),
        AppTheme.secondaryColor.withOpacity(0.02),
        AppTheme.accentColor.withOpacity(0.03),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Add subtle animated particles
    final particleCount = 20;
    for (int i = 0; i < particleCount; i++) {
      final x = (i * size.width / particleCount) + (progress * 50);
      final y = (i * size.height / particleCount) + (progress * 30);
      final opacity = (0.1 + 0.05 * (i % 3)) * progress;
      
      final particlePaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(x % size.width, y % size.height),
        2.0 + (i % 3),
        particlePaint,
      );
    }

    // Add subtle grid pattern
    final gridSpacing = 50.0;
    final gridPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.02 * progress)
      ..strokeWidth = 0.5;

    // Vertical lines
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
