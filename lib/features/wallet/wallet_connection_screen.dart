import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/models/user.dart';

class WalletConnectionScreen extends ConsumerStatefulWidget {
  const WalletConnectionScreen({super.key});

  @override
  ConsumerState<WalletConnectionScreen> createState() => _WalletConnectionScreenState();
}

class _WalletConnectionScreenState extends ConsumerState<WalletConnectionScreen> {
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    _checkPreviousConnection();
  }

  void _checkPreviousConnection() {
    final walletService = WalletService();
    if (walletService.isConnected) {
      setState(() {
        _isConnected = true;
        _walletAddress = walletService.walletAddress;
      });
    }
  }

  Future<void> _connectWallet() async {
    setState(() => _isConnecting = true);
    
    try {
      final walletService = WalletService();
      await walletService.connectWallet();
      
      setState(() {
        _isConnected = true;
        _walletAddress = walletService.walletAddress;
        _isConnecting = false;
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet connected: ${_walletAddress?.substring(0, 8)}...'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect wallet: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _skipWalletConnection() {
    // Navigate to main options
    context.go('/wallet/options');
  }

  void _continueWithWallet() {
    // Navigate to main options
    context.go('/wallet/options');
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenHeight - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.all(screenWidth * 0.06),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top Spacer
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Logo/Icon
                      Container(
                        width: screenWidth * 0.25,
                        height: screenWidth * 0.25,
                        constraints: const BoxConstraints(
                          maxWidth: 120,
                          maxHeight: 120,
                          minWidth: 80,
                          minHeight: 80,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: screenWidth * 0.12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Title
                      Text(
                        'Connect Your Wallet',
                        style: TextStyle(
                          fontSize: screenWidth * 0.07,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Subtitle
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: Text(
                          'Connect your Web3 wallet to participate in AR airdrop events and claim boundaries',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Wallet Status
                      if (_isConnected && _walletAddress != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[300],
                                size: screenWidth * 0.06,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wallet Connected',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: screenWidth * 0.04,
                                      ),
                                    ),
                                    Text(
                                      _walletAddress!,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: screenWidth * 0.03,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Connect Button
                      if (!_isConnected)
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.06,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectWallet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppTheme.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isConnecting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.05,
                                        height: screenWidth * 0.05,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'Connecting...',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.04,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.link, size: screenWidth * 0.06),
                                      SizedBox(width: screenWidth * 0.03),
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
                        ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Continue Button (if connected)
                      if (_isConnected)
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.06,
                          child: ElevatedButton(
                            onPressed: _continueWithWallet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward, size: screenWidth * 0.06),
                                SizedBox(width: screenWidth * 0.03),
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      SizedBox(height: screenHeight * 0.02),
                      
                      // Skip Button
                      TextButton(
                        onPressed: _skipWalletConnection,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withOpacity(0.8),
                        ),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Info Text
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.8),
                              size: screenWidth * 0.06,
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Text(
                                'You can always connect your wallet later from the settings',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: screenWidth * 0.035,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Bottom Spacer
                      SizedBox(height: screenHeight * 0.05),
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
}

