import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/providers/reown_provider.dart';

class WalletOptionsScreen extends ConsumerStatefulWidget {
  const WalletOptionsScreen({super.key});

  @override
  ConsumerState<WalletOptionsScreen> createState() => _WalletOptionsScreenState();
}

class _WalletOptionsScreenState extends ConsumerState<WalletOptionsScreen> with WidgetsBindingObserver {
  bool _isConnected = false;
  String? _walletAddress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay the check to ensure wallet service is properly initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh wallet status when app comes back to foreground
      _checkWalletStatus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh wallet status when dependencies change (e.g., navigation back)
    _checkWalletStatus();
  }

  void _checkWalletStatus() async {
    try {
      // Get wallet connection state from the provider
      final walletState = ref.read(walletConnectionProvider);
      
      debugPrint('Wallet status check - Connected: ${walletState.isConnected}, Address: ${walletState.walletAddress}');
      
      if (mounted) {
        setState(() {
          _isConnected = walletState.isConnected;
          _walletAddress = walletState.walletAddress;
        });
      }
    } catch (e) {
      debugPrint('Error checking wallet status: $e');
      // Set default state on error
      if (mounted) {
        setState(() {
          _isConnected = false;
          _walletAddress = null;
        });
      }
    }
  }



  // Public method to refresh wallet status
  void refreshWalletStatus() {
    _checkWalletStatus();
  }

  void _disconnectWallet() async {
    try {
      // Disconnect using the provider
      await ref.read(walletConnectionProvider.notifier).disconnect();
      
      setState(() {
        _isConnected = false;
        _walletAddress = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Wallet disconnected'),
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
          ),
        );
      }
    } catch (e) {
      debugPrint('Error disconnecting wallet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting wallet: $e'),
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to wallet connection provider changes
    ref.listen<WalletConnectionState>(walletConnectionProvider, (previous, next) {
      if (mounted) {
        setState(() {
          _isConnected = next.isConnected;
          _walletAddress = next.walletAddress;
        });
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    

    

    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              _checkWalletStatus();
            },
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
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
                      // Retro Header with animation
                      _buildRetroAnimatedHeader(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Retro Wallet Status Card with animation
                      _buildRetroAnimatedWalletCard(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Retro Options with staggered animations
                      _buildRetroAnimatedOptions(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Retro Wallet Actions with animation
                      _buildRetroAnimatedWalletActions(screenWidth, screenHeight),
                      
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
      )
    );
  }

  Widget _buildRetroAnimatedHeader(double screenWidth, double screenHeight) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(0), // Pixelated
            border: Border.all(
              color: AppTheme.textColor.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: IconButton(
            onPressed: () => context.go('/wallet/connect'),
            icon: Icon(Icons.arrow_back, color: AppTheme.textColor, size: screenWidth * 0.06),
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.surfaceColor,
              padding: EdgeInsets.all(screenWidth * 0.03),
            ),
          ),
        ).animate().fadeIn(
          duration: 600.ms,
          delay: 100.ms,
        ),
        SizedBox(width: screenWidth * 0.04),
        Expanded(
          child: Text(
            'WELCOME TO FACEREFLECTOR',
            style: AppTheme.retroTitle.copyWith(
              fontSize: screenWidth * 0.065,
              color: AppTheme.textColor,
            ),
          ).animate().fadeIn(
            duration: 800.ms,
            delay: 200.ms,
          ),
        ),
      ],
    );
  }

  Widget _buildRetroAnimatedWalletCard(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(0), // Pixelated
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.4),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            _isConnected ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
            size: screenWidth * 0.12,
            color: _isConnected ? AppTheme.successColor : AppTheme.textColor.withOpacity(0.8),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 400.ms,
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _isConnected ? 'WALLET CONNECTED' : 'NO WALLET CONNECTED',
            style: AppTheme.retroSubtitle.copyWith(
              fontSize: screenWidth * 0.05,
              color: AppTheme.textColor,
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
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(0), // Pixelated
                border: Border.all(
                  color: AppTheme.textColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Text(
                _walletAddress!,
                style: AppTheme.retroBody.copyWith(
                  fontSize: screenWidth * 0.035,
                  color: AppTheme.textColor.withOpacity(0.9),
                  fontFamily: 'Courier',
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

  Widget _buildRetroAnimatedOptions(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Join Event Option
        _buildRetroAnimatedOptionCard(
          icon: Icons.qr_code,
          title: 'JOIN EVENT',
          subtitle: 'Enter event code to participate',
          onTap: () => context.go('/event/join'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 500.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // Create Event Option
        _buildRetroAnimatedOptionCard(
          icon: Icons.add_location,
          title: 'CREATE EVENT',
          subtitle: 'Set up a new AR airdrop event',
          onTap: () => context.go('/event/create'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 700.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // Boundary History Option
        _buildRetroAnimatedOptionCard(
          icon: Icons.history,
          title: 'MY BOUNDARY COLLECTION',
          subtitle: 'View all your claimed boundaries from different events',
          onTap: () => context.go('/boundary-history'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 900.ms,
        ),
      ],
    );
  }

  Widget _buildRetroAnimatedOptionCard({
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
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.12,
              height: screenWidth * 0.12,
              decoration: BoxDecoration(
                gradient: AppTheme.retroGradient,
                borderRadius: BorderRadius.circular(0), // Pixelated
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.4),
                    offset: const Offset(3, 3),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: AppTheme.backgroundColor,
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
                    style: AppTheme.retroSubtitle.copyWith(
                      fontSize: screenWidth * 0.045,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    subtitle,
                    style: AppTheme.retroBody.copyWith(
                      fontSize: screenWidth * 0.035,
                      color: AppTheme.textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppTheme.textColor.withOpacity(0.5),
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

  Widget _buildRetroAnimatedWalletActions(double screenWidth, double screenHeight) {
    if (_isConnected) {
      return SizedBox(
        width: double.infinity,
        height: screenHeight * 0.06,
        child: OutlinedButton(
          onPressed: _disconnectWallet,
          style: AppTheme.retroOutlinedButton.copyWith(
            side: MaterialStateProperty.all(BorderSide(
              color: AppTheme.textColor.withOpacity(0.4),
              width: 2,
            )),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, size: screenWidth * 0.05, color: AppTheme.textColor),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'DISCONNECT WALLET',
                style: AppTheme.retroButton.copyWith(
                  fontSize: screenWidth * 0.04,
                  color: AppTheme.textColor,
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
          onPressed: () async {
            // Initialize wallet service before navigating
            final walletService = WalletService();
            await walletService.initialize(context);
            if (mounted) {
              context.go('/wallet/connect');
            }
          },
          style: AppTheme.retroPrimaryButton.copyWith(
            backgroundColor: MaterialStateProperty.all(AppTheme.textColor),
            foregroundColor: MaterialStateProperty.all(AppTheme.backgroundColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link, size: screenWidth * 0.05, color: AppTheme.backgroundColor),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'CONNECT WALLET',
                style: AppTheme.retroButton.copyWith(
                  fontSize: screenWidth * 0.04,
                  color: AppTheme.backgroundColor,
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

