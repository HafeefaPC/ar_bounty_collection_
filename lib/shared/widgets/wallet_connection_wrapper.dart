import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/reown_provider.dart';
import '../services/global_wallet_service.dart';
import '../../core/theme/app_theme.dart';

/// A wrapper widget that ensures wallet connection is properly maintained
/// across all pages. This widget should be used to wrap pages that require
/// wallet functionality.
class WalletConnectionWrapper extends ConsumerStatefulWidget {
  final Widget child;
  final bool requireWallet;
  final String? redirectRoute;

  const WalletConnectionWrapper({
    super.key,
    required this.child,
    this.requireWallet = false,
    this.redirectRoute,
  });

  @override
  ConsumerState<WalletConnectionWrapper> createState() => _WalletConnectionWrapperState();
}

class _WalletConnectionWrapperState extends ConsumerState<WalletConnectionWrapper> {
  @override
  void initState() {
    super.initState();
    // Check wallet status when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkWalletStatus();
    });
  }

  void _checkWalletStatus() {
    final globalWalletService = ref.read(globalWalletServiceProvider);
    
    debugPrint('WalletConnectionWrapper: Checking wallet status');
    debugPrint('WalletConnectionWrapper: isConnected: ${globalWalletService.isWalletConnected()}');
    
    // If wallet is required but not connected, show connection prompt
    if (widget.requireWallet && !globalWalletService.isWalletConnected()) {
      _showWalletConnectionPrompt();
    }
  }

  void _showWalletConnectionPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        title: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'WALLET REQUIRED',
                style: AppTheme.modernSubtitle.copyWith(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This feature requires a connected wallet to interact with the blockchain.',
              style: AppTheme.modernBodySecondary.copyWith(
                color: AppTheme.textColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Please connect your wallet to continue.',
                style: AppTheme.modernBodySecondary.copyWith(
                  color: AppTheme.secondaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (widget.redirectRoute != null) {
                  context.go(widget.redirectRoute!);
                }
              },
              child: Text(
                'CANCEL',
                style: AppTheme.modernButton.copyWith(
                  color: AppTheme.textColor.withOpacity(0.8),
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
            child: ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final globalWalletService = ref.read(globalWalletServiceProvider);
                  
                  // Ensure ReownAppKit is initialized
                  await globalWalletService.ensureReownAppKitInitialized(context);
                  
                  // Connect wallet
                  await ref.read(walletConnectionProvider.notifier).connect();
                  
                  // Refresh wallet state
                  globalWalletService.refreshWalletState();
                  
                } catch (e) {
                  if (mounted && context.mounted) {
                    try {
                      String errorMessage = 'Failed to connect wallet';
                      if (e.toString().contains('disposed') || 
                          e.toString().contains('interrupted') || 
                          e.toString().contains('ReownAppKitModalException')) {
                        errorMessage = 'Wallet connection was interrupted. Please try again.';
                      } else {
                        errorMessage = 'Failed to connect wallet: $e';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: AppTheme.errorColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                        ),
                      );
                    } catch (snackBarError) {
                      debugPrint('Error showing snackbar: $snackBarError');
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              ),
              child: Text(
                'CONNECT WALLET',
                style: AppTheme.modernButton.copyWith(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen to wallet connection changes
    ref.listen<WalletConnectionState>(walletConnectionProvider, (previous, next) {
      debugPrint('WalletConnectionWrapper: Wallet state changed');
      debugPrint('WalletConnectionWrapper: Previous: $previous');
      debugPrint('WalletConnectionWrapper: Next: $next');
      
      // If wallet was connected but now disconnected and wallet is required
      if (widget.requireWallet && 
          previous?.isConnected == true && 
          !next.isConnected) {
        _showWalletConnectionPrompt();
      }
    });

    return widget.child;
  }
}

/// A widget that shows wallet connection status

  // Helper method to get chain name from chain ID
  String _getChainName(String chainId) {
    switch (chainId) {
      case '1':
        return 'ETH Mainnet';
      case '42161':
        return 'Arbitrum One';
      case '421614':
        return 'Arbitrum Sepolia';
      case '137':
        return 'Polygon';
      case '56':
        return 'BNB Chain';
      case '43114':
        return 'Avalanche';
      default:
        return 'Chain $chainId';
    }
  }
