import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/wallet_service.dart';

class WalletOptionsScreen extends ConsumerStatefulWidget {
  const WalletOptionsScreen({super.key});

  @override
  ConsumerState<WalletOptionsScreen> createState() => _WalletOptionsScreenState();
}

class _WalletOptionsScreenState extends ConsumerState<WalletOptionsScreen> {
  bool _isConnected = false;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _checkWalletStatus();
  }

  void _checkWalletStatus() {
    final walletService = WalletService();
    setState(() {
      _isConnected = walletService.isConnected;
      _walletAddress = walletService.walletAddress;
    });
  }

  void _disconnectWallet() async {
    final walletService = WalletService();
    await walletService.disconnectWallet();
    setState(() {
      _isConnected = false;
      _walletAddress = null;
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Wallet disconnected'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: screenHeight * 0.02,
                  ),
                  child: Column(
                    children: [
                      // Header with animation
                      _buildAnimatedHeader(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Wallet Status Card with animation
                      _buildAnimatedWalletCard(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Options with staggered animations
                      _buildAnimatedOptions(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Wallet Actions with animation
                      _buildAnimatedWalletActions(screenWidth, screenHeight),
                      
                      // Bottom Spacer
                      SizedBox(height: screenHeight * 0.03),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(double screenWidth, double screenHeight) {
    return Row(
      children: [
                  IconButton(
            onPressed: () => context.go('/wallet/connect'),
            icon: Icon(Icons.arrow_back, color: Colors.white, size: screenWidth * 0.06),
            style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            padding: EdgeInsets.all(screenWidth * 0.03),
          ),
        ).animate().fadeIn(
          duration: 600.ms,
          delay: 100.ms,
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: Text(
            'Welcome to FaceReflector',
            style: TextStyle(
              fontSize: screenWidth * 0.065,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate().fadeIn(
            duration: 800.ms,
            delay: 200.ms,
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedWalletCard(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isConnected ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
            size: screenWidth * 0.12,
            color: _isConnected ? Colors.green[300] : Colors.white.withValues(alpha: 0.8),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 400.ms,
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _isConnected ? 'Wallet Connected' : 'No Wallet Connected',
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 600.ms,
          ),
          if (_isConnected && _walletAddress != null) ...[
            SizedBox(height: screenHeight * 0.015),
            Container(
              padding: EdgeInsets.all(screenWidth * 0.03),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _walletAddress!,
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.white.withValues(alpha: 0.9),
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ).animate().fadeIn(
              duration: 600.ms,
              delay: 800.ms,
            ),
          ],
        ],
      ),
    ).animate().fadeIn(
      duration: 800.ms,
      delay: 300.ms,
    );
  }

  Widget _buildAnimatedOptions(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Join Event Option
        _buildAnimatedOptionCard(
          icon: Icons.qr_code,
          title: 'Join Event',
          subtitle: 'Enter event code to participate',
          onTap: () => context.go('/event/join'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 500.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // Create Event Option
        _buildAnimatedOptionCard(
          icon: Icons.add_location,
          title: 'Create Event',
          subtitle: 'Set up a new AR airdrop event',
          onTap: () => context.go('/event/create'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 700.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // Boundary History Option
        _buildAnimatedOptionCard(
          icon: Icons.history,
          title: 'My Boundary Collection',
          subtitle: 'View all your claimed boundaries from different events',
          onTap: () => context.go('/boundary-history'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 900.ms,
        ),
      ],
    );
  }

  Widget _buildAnimatedOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required double screenWidth,
    required double screenHeight,
    required Duration delay,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.05),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.12,
              height: screenWidth * 0.12,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: screenWidth * 0.06,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: screenWidth * 0.045,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: screenWidth * 0.04,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(
      duration: 600.ms,
      delay: delay,
    );
  }

  Widget _buildAnimatedWalletActions(double screenWidth, double screenHeight) {
    if (_isConnected) {
      return SizedBox(
        width: double.infinity,
        height: screenHeight * 0.06,
        child: OutlinedButton(
          onPressed: _disconnectWallet,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: screenWidth * 0.05),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Disconnect Wallet',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
        duration: 600.ms,
        delay: 1100.ms,
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: screenHeight * 0.06,
        child: ElevatedButton(
          onPressed: () => context.go('/wallet/connect'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link, size: screenWidth * 0.05),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Connect Wallet',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
        duration: 600.ms,
        delay: 1100.ms,
      );
    }
  }
}

