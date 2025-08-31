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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Decorative top border
                    Container(
                      width: screenWidth * 0.6,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.3),
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(0),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: screenHeight * 0.05),
                    
                    // TOKON Logo Animation with Pulse Effect
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: Curves.elasticOut.transform(_logoController.value),
                          child: AnimatedBuilder(
                            animation: _scanlineController,
                            builder: (context, child) {
                              final pulseScale = 1.0 + (0.02 * (1 - _scanlineController.value));
                              return Transform.scale(
                                scale: pulseScale,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(0), // Pixelated corners
                                    border: Border.all(
                                      color: AppTheme.primaryColor.withOpacity(0.3 + (0.2 * _scanlineController.value)),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.2 + (0.1 * _scanlineController.value)),
                                        offset: const Offset(8, 8),
                                        blurRadius: 0,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: TokonLogo(
                                    size: screenWidth * 0.2,
                                    showText: true,
                                    coinColor: AppTheme.primaryColor,
                                    textColor: AppTheme.primaryColor,
                                  ),
                                ),
                              );
                            },
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
                                    'TOKON',
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
                    
                    // Enhanced Loading Animation
                    AnimatedBuilder(
                      animation: _gradientController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _gradientController.value,
                          child: Column(
                            children: [
                              // Animated Loading Spinner
                              Container(
                                width: screenWidth * 0.15,
                                height: screenWidth * 0.15,
                                constraints: const BoxConstraints(
                                  maxWidth: 60,
                                  maxHeight: 60,
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(0), // Pixelated
                                  border: Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withOpacity(0.4),
                                      offset: const Offset(4, 4),
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(0), // Pixelated
                                  child: Stack(
                                    children: [
                                      // Background progress
                                      LinearProgressIndicator(
                                        value: 0.8,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppTheme.surfaceColor.withOpacity(0.3),
                                        ),
                                        backgroundColor: AppTheme.surfaceColor.withOpacity(0.1),
                                      ),
                                      // Animated progress bar
                                      AnimatedBuilder(
                                        animation: _scanlineController,
                                        builder: (context, child) {
                                          return LinearProgressIndicator(
                                            value: (_scanlineController.value * 0.6) + 0.2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              AppTheme.primaryColor,
                                            ),
                                            backgroundColor: Colors.transparent,
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.025),
                              
                              // Loading Text with Animation
                              AnimatedBuilder(
                                animation: _scanlineController,
                                builder: (context, child) {
                                  final dots = '...'.substring(0, ((_scanlineController.value * 3).floor() + 1).clamp(0, 3));
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(0), // Pixelated
                                      border: Border.all(
                                        color: AppTheme.accentColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentColor.withOpacity(0.3),
                                          offset: const Offset(3, 3),
                                          blurRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      'LOADING$dots',
                                      style: AppTheme.retroButton.copyWith(
                                        fontSize: screenWidth * 0.035,
                                        color: AppTheme.accentColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              SizedBox(height: screenHeight * 0.02),
                              
                              // Subtitle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(0), // Pixelated
                                  border: Border.all(
                                    color: AppTheme.textColor.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Preparing your AR experience...',
                                  style: AppTheme.retroBody.copyWith(
                                    fontSize: screenWidth * 0.028,
                                    color: AppTheme.textColor.withOpacity(0.8),
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
                    
                    // Decorative bottom border
                    Container(
                      width: screenWidth * 0.6,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.3),
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(0),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            offset: const Offset(0, -2),
                            blurRadius: 0,
                          ),
                        ],
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

// Enhanced custom painter for retro scanlines effect
class RetroScanlinesPainter extends CustomPainter {
  final double progress;

  RetroScanlinesPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Create a gradient background effect
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppTheme.primaryColor.withOpacity(0.05),
        AppTheme.primaryColor.withOpacity(0.02),
        AppTheme.primaryColor.withOpacity(0.05),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
    
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Enhanced scanlines with varying opacity and thickness
    final lineSpacing = 3.0;
    final totalLines = (size.height / lineSpacing).ceil();

    for (int i = 0; i < totalLines; i++) {
      final y = i * lineSpacing;
      final baseOpacity = 0.08 + 0.04 * (i % 4);
      final animatedOpacity = baseOpacity * progress;
      
      // Vary line thickness based on position
      final lineThickness = (i % 3 == 0) ? 1.5 : 1.0;
      
      final linePaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(animatedOpacity)
        ..strokeWidth = lineThickness;

      // Add some variation to line positions for more organic feel
      final offset = (i % 5 == 0) ? 2.0 : 0.0;
      
      canvas.drawLine(
        Offset(offset, y),
        Offset(size.width - offset, y),
        linePaint,
      );
    }

    // Add subtle corner effects
    final cornerPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.1 * progress)
      ..strokeWidth = 2.0;

    final cornerSize = 20.0;
    
    // Top-left corner
    canvas.drawLine(Offset(0, cornerSize), Offset(cornerSize, cornerSize), cornerPaint);
    canvas.drawLine(Offset(cornerSize, 0), Offset(cornerSize, cornerSize), cornerPaint);
    
    // Top-right corner
    canvas.drawLine(Offset(size.width - cornerSize, 0), Offset(size.width - cornerSize, cornerSize), cornerPaint);
    canvas.drawLine(Offset(size.width - cornerSize, cornerSize), Offset(size.width, cornerSize), cornerPaint);
    
    // Bottom-left corner
    canvas.drawLine(Offset(0, size.height - cornerSize), Offset(cornerSize, size.height - cornerSize), cornerPaint);
    canvas.drawLine(Offset(cornerSize, size.height - cornerSize), Offset(cornerSize, size.height), cornerPaint);
    
    // Bottom-right corner
    canvas.drawLine(Offset(size.width - cornerSize, size.height - cornerSize), Offset(size.width, size.height - cornerSize), cornerPaint);
    canvas.drawLine(Offset(size.width - cornerSize, size.height - cornerSize), Offset(size.width - cornerSize, size.height), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
