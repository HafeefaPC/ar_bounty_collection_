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
    await Future.delayed(const Duration(milliseconds: 500));
    _logoController.forward();
    
    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();
    
    await Future.delayed(const Duration(milliseconds: 500));
    _gradientController.forward();
    _scanlineController.repeat();
    
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
        decoration: const BoxDecoration(
          gradient: AppTheme.darkGradient,
        ),
        child: Stack(
          children: [
            // Retro Scanlines Effect
            AnimatedBuilder(
              animation: _scanlineController,
              builder: (context, child) {
                return CustomPaint(
                  painter: RetroScanlinesPainter(
                    progress: _scanlineController.value,
                  ),
                  size: Size.infinite,
                );
              },
            ),
            
            SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Top Spacer
                  SizedBox(height: screenHeight * 0.15),
                  
                  // Retro Logo Animation
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: Curves.elasticOut.transform(_logoController.value),
                        child: Container(
                          width: screenWidth * 0.25,
                          height: screenWidth * 0.25,
                          constraints: const BoxConstraints(
                            maxWidth: 120,
                            maxHeight: 120,
                            minWidth: 80,
                            minHeight: 80,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.retroGradient,
                            borderRadius: BorderRadius.circular(0), // Pixelated corners
                            border: Border.all(
                              color: AppTheme.textColor,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.6),
                                offset: const Offset(6, 6),
                                blurRadius: 0,
                              ),
                              BoxShadow(
                                color: AppTheme.secondaryColor.withOpacity(0.4),
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: screenWidth * 0.12,
                            color: AppTheme.backgroundColor,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  SizedBox(height: screenHeight * 0.05),
                  
                  // Retro App Name Animation
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
                                  style: AppTheme.retroTitle.copyWith(
                                    fontSize: screenWidth * 0.065,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(3, 3),
                                        blurRadius: 0,
                                        color: AppTheme.primaryColor,
                                      ),
                                      Shadow(
                                        offset: const Offset(6, 6),
                                        blurRadius: 0,
                                        color: AppTheme.secondaryColor,
                                      ),
                                    ],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: screenHeight * 0.012),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(0), // Pixelated
                                    border: Border.all(
                                      color: AppTheme.secondaryColor,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.secondaryColor.withOpacity(0.4),
                                        offset: const Offset(3, 3),
                                        blurRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'AR-Powered Event Goodies',
                                    style: AppTheme.retroSubtitle.copyWith(
                                      fontSize: screenWidth * 0.032,
                                      color: AppTheme.textColor,
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
                  
                  // Retro Loading Animation
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
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(0), // Pixelated
                                border: Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(0), // Pixelated
                                child: LinearProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.primaryColor,
                                  ),
                                  backgroundColor: AppTheme.surfaceColor,
                                ),
                              ),
                            ),
                            SizedBox(height: screenHeight * 0.02),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(0), // Pixelated
                                border: Border.all(
                                  color: AppTheme.accentColor,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'LOADING...',
                                style: AppTheme.retroButton.copyWith(
                                  fontSize: screenWidth * 0.035,
                                  color: AppTheme.accentColor,
                                ),
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
          ],
        ),
      ),
    );
  }
}

// Custom painter for retro scanlines effect
class RetroScanlinesPainter extends CustomPainter {
  final double progress;

  RetroScanlinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.1)
      ..strokeWidth = 1.0;

    final lineSpacing = 4.0;
    final totalLines = (size.height / lineSpacing).ceil();

    for (int i = 0; i < totalLines; i++) {
      final y = i * lineSpacing;
      final opacity = (0.1 + 0.05 * (i % 3)) * progress;
      
      paint.color = AppTheme.primaryColor.withOpacity(opacity);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
