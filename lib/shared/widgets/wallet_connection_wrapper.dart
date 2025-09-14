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
class WalletConnectionStatus extends ConsumerWidget {
  final bool showAddress;
  final bool showDisconnectButton;
  final bool showNetworkSwitch;

  const WalletConnectionStatus({
    super.key,
    this.showAddress = true,
    this.showDisconnectButton = false,
    this.showNetworkSwitch = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletConnectionProvider);
    final walletNotifier = ref.read(walletConnectionProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: walletState.isConnected ? AppTheme.successColor : AppTheme.textColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            walletState.isConnected 
                ? Icons.account_balance_wallet 
                : Icons.account_balance_wallet_outlined,
            color: walletState.isConnected ? AppTheme.successColor : AppTheme.textColor.withOpacity(0.5),
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                walletState.isConnected ? 'WALLET CONNECTED' : 'NO WALLET',
                style: AppTheme.modernButton.copyWith(
                  color: walletState.isConnected ? AppTheme.successColor : AppTheme.textColor.withOpacity(0.7),
                  fontSize: 10,
                  letterSpacing: 1.0,
                ),
              ),
              if (showAddress && walletState.walletAddress != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${walletState.walletAddress!.substring(0, 6)}...${walletState.walletAddress!.substring(walletState.walletAddress!.length - 4)}',
                  style: AppTheme.modernBodySecondary.copyWith(
                    color: AppTheme.textColor.withOpacity(0.8),
                    fontSize: 10,
                    fontFamily: 'Courier',
                  ),
                ),
                // Add chain ID display
                if (walletState.chainId != null) ...[
                  const SizedBox(height: 2),
                  Builder(
                    builder: (context) {
                      // Extract chain ID without eip155: prefix for comparison
                      final chainId = walletState.chainId!.replaceAll('eip155:', '');
                      final isSomniaTestnet = chainId == '50312';
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSomniaTestnet 
                              ? AppTheme.successColor.withOpacity(0.2)
                              : AppTheme.warningColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSomniaTestnet 
                                ? AppTheme.successColor.withOpacity(0.5)
                                : AppTheme.warningColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getChainName(chainId),
                          style: AppTheme.modernBodySecondary.copyWith(
                            color: isSomniaTestnet 
                                ? AppTheme.successColor
                                : AppTheme.warningColor,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ],
          ),
          // Network switch button
          if (showNetworkSwitch && walletState.isConnected) ...[
            Builder(
              builder: (context) {
                // Extract chain ID without eip155: prefix for comparison
                final chainId = walletState.chainId?.replaceAll('eip155:', '') ?? '';
                final isSomniaTestnet = chainId == '50312';
                
                if (isSomniaTestnet) {
                  return const SizedBox.shrink(); // Don't show switch button if already on correct network
                }
                
                return Row(
                  children: [
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        try {
                          // Show loading indicator
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Switching to Somnia Testnet...',
                                      style: AppTheme.modernBodySecondary.copyWith(color: AppTheme.backgroundColor),
                                    ),
                                  ],
                                ),
                                backgroundColor: AppTheme.primaryColor,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                          
                          // Attempt to switch network
                          final success = await walletNotifier.switchToSomniaTestnet();
                          
                          // Wait for state to update
                          await Future.delayed(const Duration(seconds: 2));
                          
                          // Force refresh the wallet state
                          walletNotifier.refreshConnectionState();
                          
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success ? 'Successfully switched to Somnia Testnet!' : 'Failed to switch network. Please try manually.'),
                                backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error switching network: $e'),
                                backgroundColor: AppTheme.errorColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.warningColor.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.swap_horiz,
                          color: AppTheme.warningColor,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          // Disconnect button
          if (showDisconnectButton && walletState.isConnected) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                try {
                  await walletNotifier.disconnect();
                } catch (e) {
                  if (context.mounted) {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error disconnecting wallet: $e'),
                          backgroundColor: AppTheme.errorColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                        ),
                      );
                    } catch (snackBarError) {
                      debugPrint('Error showing disconnect error snackbar: $snackBarError');
                    }
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.logout,
                  color: AppTheme.textColor.withOpacity(0.7),
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  // Helper method to get chain name from chain ID
  String _getChainName(String chainId) {
    switch (chainId) {
      case '1':
        return 'ETH Mainnet';
      case '5031':
        return 'Somnia Mainnet';
      case '50312':
        return 'Somnia Testnet';
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
}