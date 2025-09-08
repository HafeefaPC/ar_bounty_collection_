import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/wallet_service.dart';
import '../../../shared/providers/reown_provider.dart';
import '../../../shared/services/global_wallet_service.dart';

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
      final globalWalletService = ref.read(globalWalletServiceProvider);
      
      // Restore wallet state using global service
      await globalWalletService.restoreWalletState();
      
      // Get current wallet state
      final isConnected = globalWalletService.isWalletConnected();
      final walletAddress = globalWalletService.getWalletAddress();
      
      debugPrint('Wallet status check - Connected: $isConnected, Address: $walletAddress');
      
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _walletAddress = walletAddress;
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
        
        // Show notification when wallet connection status changes
        if (previous?.isConnected != next.isConnected) {
          if (next.isConnected) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Wallet connected successfully!'),
                backgroundColor: AppTheme.successColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              ),
            );
          } else if (previous?.isConnected == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Wallet disconnected'),
                backgroundColor: AppTheme.warningColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              ),
            );
          }
        }
      }
    });

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    

    

    
    return Scaffold(
      body: Container(
        decoration: AppTheme.modernScaffoldBackground,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              _checkWalletStatus();
            },
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.cardColor,
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
                      // Modern Header with animation
                      _buildModernAnimatedHeader(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Modern Wallet Status Card with animation
                      _buildModernAnimatedWalletCard(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.05),
                      
                      // Modern Options with staggered animations
                      _buildModernAnimatedOptions(screenWidth, screenHeight),
                      
                      SizedBox(height: screenHeight * 0.04),
                      
                      // Modern Wallet Actions with animation
                      _buildModernAnimatedWalletActions(screenWidth, screenHeight),
                      
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

  Widget _buildModernAnimatedHeader(double screenWidth, double screenHeight) {
    return Row(
      children: [
        Container(
          decoration: AppTheme.modernContainerDecoration,
          child: IconButton(
            onPressed: () => context.go('/wallet/connect'),
            icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textColor, size: screenWidth * 0.06),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
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
            'Welcome to TOKON',
            style: AppTheme.modernTitle.copyWith(
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

  Widget _buildModernAnimatedWalletCard(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: AppTheme.modernCardDecoration,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              gradient: _isConnected ? AppTheme.primaryGradient : AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _isConnected ? Icons.account_balance_wallet_rounded : Icons.account_balance_wallet_outlined,
              size: screenWidth * 0.12,
              color: AppTheme.textColor,
            ),
          ).animate().fadeIn(
            duration: 600.ms,
            delay: 400.ms,
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            _isConnected ? 'Wallet Connected' : 'No Wallet Connected',
            style: AppTheme.modernSubtitle.copyWith(
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
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: AppTheme.modernContainerDecoration,
              child: Text(
                _walletAddress!,
                style: AppTheme.modernBodySecondary.copyWith(
                  fontSize: screenWidth * 0.035,
                  color: AppTheme.textSecondary,
                  fontFamily: 'SF Mono',
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

  Widget _buildModernAnimatedOptions(double screenWidth, double screenHeight) {
    return Column(
      children: [
        // Join Event Option
        _buildModernAnimatedOptionCard(
          icon: Icons.qr_code_scanner_rounded,
          title: 'Join Event',
          subtitle: 'Enter event code to participate',
          onTap: () => context.go('/event/join'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 500.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // Create Event Option
        _buildModernAnimatedOptionCard(
          icon: Icons.add_location_alt_rounded,
          title: 'Create Event',
          subtitle: 'Set up a new AR airdrop event',
          onTap: () => context.go('/event/create'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 700.ms,
        ),
        
        SizedBox(height: screenHeight * 0.025),
        
        // NFT Collection Option
        _buildModernAnimatedOptionCard(
          icon: Icons.collections_rounded,
          title: 'Network NFT Collection',
          subtitle: 'View all claimed NFTs from events across the network',
          onTap: () => context.go('/nft-collection'),
          screenWidth: screenWidth,
          screenHeight: screenHeight,
          delay: 900.ms,
        ),
        
      ],
    );
  }

  Widget _buildModernAnimatedOptionCard({
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
        decoration: AppTheme.modernCardDecoration,
        child: Row(
          children: [
            Container(
              width: screenWidth * 0.12,
              height: screenWidth * 0.12,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: AppTheme.textColor,
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
                    style: AppTheme.modernSubtitle.copyWith(
                      fontSize: screenWidth * 0.045,
                      color: AppTheme.textColor,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.005),
                  Text(
                    subtitle,
                    style: AppTheme.modernBodySecondary.copyWith(
                      fontSize: screenWidth * 0.035,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppTheme.textSecondary,
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

  Widget _buildModernAnimatedWalletActions(double screenWidth, double screenHeight) {
    if (_isConnected) {
      return SizedBox(
        width: double.infinity,
        height: screenHeight * 0.06,
        child: OutlinedButton(
          onPressed: _disconnectWallet,
          style: AppTheme.modernOutlinedButton,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: screenWidth * 0.05, color: AppTheme.textColor),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Disconnect Wallet',
                style: AppTheme.modernButton.copyWith(
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
        duration: 600.ms,
        delay: 1300.ms,
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
          style: AppTheme.modernPrimaryButton,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_rounded, size: screenWidth * 0.05, color: AppTheme.textColor),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'Connect Wallet',
                style: AppTheme.modernButton.copyWith(
                  fontSize: screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(
        duration: 600.ms,
        delay: 1300.ms,
      );
    }
  }
}

