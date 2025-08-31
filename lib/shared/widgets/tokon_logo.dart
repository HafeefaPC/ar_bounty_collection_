import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A widget that displays the TOKON logo in pixel art style
class TokonLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? coinColor;
  final Color? textColor;

  const TokonLogo({
    super.key,
    this.size = 120.0,
    this.showText = true,
    this.coinColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final coinSize = size * 0.6;
    final textSize = size * 0.4;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Golden Coin with "T"
        Container(
          width: coinSize,
          height: coinSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                coinColor ?? const Color(0xFFFFD700), // Golden yellow
                coinColor?.withOpacity(0.8) ?? const Color(0xFFFFB347), // Darker gold
                coinColor?.withOpacity(0.6) ?? const Color(0xFFDAA520), // Goldenrod
              ],
              stops: const [0.0, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(4, 4),
                blurRadius: 0,
                spreadRadius: 0,
              ),
              BoxShadow(
                color: (coinColor ?? const Color(0xFFFFD700)).withOpacity(0.6),
                offset: const Offset(2, 2),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: coinSize * 0.4,
              height: coinSize * 0.6,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: Colors.brown.shade800,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  'T',
                  style: TextStyle(
                    color: Colors.brown.shade800,
                    fontSize: coinSize * 0.3,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Courier',
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        if (showText) ...[
          SizedBox(height: size * 0.1),
          
          // TOKON Text
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: size * 0.05,
              vertical: size * 0.02,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: textColor ?? const Color(0xFFFFD700),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (textColor ?? const Color(0xFFFFD700)).withOpacity(0.6),
                  offset: const Offset(3, 3),
                  blurRadius: 0,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Text(
              'TOKON',
              style: TextStyle(
                color: textColor ?? const Color(0xFFFFD700),
                fontSize: textSize * 0.8,
                fontWeight: FontWeight.bold,
                fontFamily: 'Courier',
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    offset: const Offset(2, 2),
                    blurRadius: 0,
                    color: Colors.brown.shade800,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A simplified version of the TOKON logo for smaller spaces
class TokonLogoSmall extends StatelessWidget {
  final double size;
  final Color? color;

  const TokonLogoSmall({
    super.key,
    this.size = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color ?? const Color(0xFFFFD700),
            color?.withOpacity(0.8) ?? const Color(0xFFFFB347),
          ],
          stops: const [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(2, 2),
            blurRadius: 0,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'T',
          style: TextStyle(
            color: Colors.brown.shade800,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            fontFamily: 'Courier',
          ),
        ),
      ),
    );
  }
}

/// An animated version of the TOKON logo
class TokonLogoAnimated extends StatefulWidget {
  final double size;
  final bool showText;
  final Duration animationDuration;

  const TokonLogoAnimated({
    super.key,
    this.size = 120.0,
    this.showText = true,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<TokonLogoAnimated> createState() => _TokonLogoAnimatedState();
}

class _TokonLogoAnimatedState extends State<TokonLogoAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 0.1,
            child: TokonLogo(
              size: widget.size,
              showText: widget.showText,
            ),
          ),
        );
      },
    );
  }
}
