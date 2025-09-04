import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/wallet_service.dart';
import '../../shared/providers/reown_provider.dart';
import '../../shared/services/global_wallet_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class WalletConnectionScreen extends ConsumerStatefulWidget {
  const WalletConnectionScreen({super.key});

  @override
  ConsumerState<WalletConnectionScreen> createState() => _WalletConnectionScreenState();
}

class _WalletConnectionScreenState extends ConsumerState<WalletConnectionScreen> {
  ReownAppKitModal? _appKitModal;
  bool _isInitialized = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String? _walletAddress;
  String? _connectionError;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeAppKit();
  }

  @override
  void dispose() {
    _isDisposed = true;
    
    // Remove the listener before disposing
    if (_appKitModal != null) {
      try {
        _appKitModal!.removeListener(_onSessionUpdate);
      } catch (e) {
        debugPrint('Error removing listener during dispose: $e');
      }
    }
    
    // Don't dispose the modal here as it's managed by the provider
    super.dispose();
  }

  Future<void> _initializeAppKit() async {
    try {
      final globalWalletService = ref.read(globalWalletServiceProvider);
      
      // Ensure ReownAppKit is initialized using global service
      await globalWalletService.ensureReownAppKitInitialized(context);
      
      _appKitModal = ref.read(reownAppKitProvider);
      
      if (_appKitModal != null) {
        // Listen for session events
        _appKitModal!.addListener(_onSessionUpdate);

        // Check if already connected
        setState(() {
          _isConnected = _appKitModal!.isConnected;
          // We'll get the address after connection in the session listener
          _walletAddress = null;
        });

        setState(() {
          _isInitialized = true;
          _connectionError = null;
        });
      } else {
        throw Exception('Failed to get ReownAppKit instance');
      }
    } catch (e) {
      setState(() {
        _isInitialized = true;
        _connectionError = 'Failed to initialize wallet connection: $e';
      });
      _showError('Failed to initialize wallet connection: $e');
    }
  }

  void _onSessionUpdate() async {
    // Check if widget is still mounted and not disposed before using ref
    if (!mounted || _isDisposed) {
      debugPrint('Widget disposed, skipping session update');
      return;
    }
    
    try {
      // Get the current wallet state from the provider
      final walletState = ref.read(walletConnectionProvider);
      
      if (!mounted || _isDisposed) return; // Check again after async operation
      
      setState(() {
        _isConnected = walletState.isConnected;
        _isConnecting = false;
        _walletAddress = walletState.walletAddress;
      });
      
      if (_isConnected && _walletAddress != null) {
        try {
          // Save wallet data locally
          await _saveWalletData(_walletAddress!);
          
          if (!mounted || _isDisposed) return; // Check after async operation
          
          // Try to connect wallet using WalletService (database operation)
          final walletService = WalletService();
          debugPrint('Attempting to connect wallet: $_walletAddress');
          final success = await walletService.connectWallet(_walletAddress!);
          
          if (!mounted || _isDisposed) return; // Check after async operation
          
          if (success) {
            debugPrint('Wallet connected successfully: $_walletAddress');
            _showSuccess('Wallet connected successfully!');
          } else {
            debugPrint('Wallet connected but database save failed: $_walletAddress');
            _showWarning('Wallet connected! Some features may be limited due to sync issues.');
          }
        } catch (e) {
          debugPrint('Error in _onSessionUpdate: $e');
          if (mounted) {
            _showWarning('Wallet connected! Some features may be limited due to sync issues.');
          }
        }
      } else {
        // Only clear wallet data if explicitly disconnected
        if (_walletAddress != null) {
          _walletAddress = null;
          await _clearWalletData();
        }
      }
    } catch (e) {
      debugPrint('Error in _onSessionUpdate (ref access): $e');
      // Don't try to use ref or setState if there's an error
    }
  }

  Future<void> _connectWallet() async {
    setState(() => _isConnecting = true);

    try {
      final globalWalletService = ref.read(globalWalletServiceProvider);
      
      // Ensure ReownAppKit is initialized
      await globalWalletService.ensureReownAppKitInitialized(context);
      
      // Use the provider's connect method
      await ref.read(walletConnectionProvider.notifier).connect();
      
      // Refresh wallet state
      globalWalletService.refreshWalletState();
      
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('Failed to connect wallet: $e');
    }
  }

  Future<void> _disconnectWallet() async {
    try {
      final globalWalletService = ref.read(globalWalletServiceProvider);
      
      // Use the provider's disconnect method
      await ref.read(walletConnectionProvider.notifier).disconnect();
      
      // Refresh wallet state
      globalWalletService.refreshWalletState();
      
      setState(() {
        _isConnected = false;
        _walletAddress = null;
      });

      await _clearWalletData();
      _showSuccess('Wallet disconnected successfully');
    } catch (e) {
      _showError('Error disconnecting wallet: $e');
    }
  }

  Future<void> _saveWalletData(String address) async {
    try {
      final storageService = ref.read(storageServiceProvider);
      await storageService.saveSetting('wallet_address', address);
      await storageService.saveSetting('is_wallet_connected', true);
      await storageService.saveSetting('wallet_connection_time', DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Error saving wallet data: $e');
    }
  }

  Future<void> _clearWalletData() async {
    try {
      final storageService = ref.read(storageServiceProvider);
      await storageService.removeSetting('wallet_address');
      await storageService.removeSetting('is_wallet_connected');
      await storageService.removeSetting('wallet_connection_time');
    } catch (e) {
      debugPrint('Error clearing wallet data: $e');
    }
  }

  void _showSuccess(String message) {
    if (mounted && context.mounted && !_isDisposed) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.successColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
          ),
        );
      } catch (e) {
        debugPrint('Error showing success message: $e');
      }
    }
  }

  void _showError(String message) {
    if (mounted && context.mounted && !_isDisposed) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.errorColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
          ),
        );
      } catch (e) {
        debugPrint('Error showing error message: $e');
      }
    }
  }

  void _showWarning(String message) {
    if (mounted && context.mounted && !_isDisposed) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.warningColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
          ),
        );
      } catch (e) {
        debugPrint('Error showing warning message: $e');
      }
    }
  }

  void _skipWalletConnection() {
    context.go('/wallet/options');
  }

  void _continueWithWallet() {
    context.go('/wallet/options');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to wallet connection provider changes
    ref.listen<WalletConnectionState>(walletConnectionProvider, (previous, next) {
      if (mounted && context.mounted && !_isDisposed) {
        try {
          setState(() {
            _isConnected = next.isConnected;
            _walletAddress = next.walletAddress;
            _isConnecting = false;
          });
          
          // If wallet is connected, show success message
          if (next.isConnected && previous?.isConnected != true) {
            _showSuccess('Wallet connected successfully!');
          }
        } catch (e) {
          debugPrint('Error in wallet connection listener: $e');
        }
      }
    });

    if (!_isInitialized) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.modernScaffoldBackground,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: AppTheme.modernScaffoldBackground,
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
                      SizedBox(height: screenHeight * 0.08),

                      // Modern Wallet Icon with Glass Effect
                      Container(
                        width: screenWidth * 0.3,
                        height: screenWidth * 0.3,
                        constraints: const BoxConstraints(
                          maxWidth: 140,
                          maxHeight: 140,
                          minWidth: 100,
                          minHeight: 100,
                        ),
                        decoration: AppTheme.modernGlassEffect,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            size: screenWidth * 0.15,
                            color: AppTheme.textColor,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.06),

                      // Modern Title
                      Text(
                        'Connect Your Wallet',
                        style: AppTheme.modernTitle.copyWith(
                          fontSize: screenWidth * 0.08,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      SizedBox(height: screenHeight * 0.02),

                      // Modern Description
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.08),
                        child: Text(
                          'Connect your Web3 wallet to participate in AR airdrop events and collect unique digital assets.',
                          style: AppTheme.modernBodySecondary.copyWith(
                            fontSize: screenWidth * 0.045,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Modern Connection Error Display
                      if (_connectionError != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.05),
                          margin: EdgeInsets.only(bottom: screenHeight * 0.03),
                          decoration: AppTheme.modernCardDecoration.copyWith(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  color: AppTheme.errorColor,
                                  size: screenWidth * 0.06,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Expanded(
                                child: Text(
                                  _connectionError!,
                                  style: AppTheme.modernBodySecondary.copyWith(
                                    color: AppTheme.errorColor,
                                    fontSize: screenWidth * 0.04,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Modern Connected Wallet Display
                      if (_isConnected && _walletAddress != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.05),
                          decoration: AppTheme.modernCardDecoration.copyWith(
                            color: AppTheme.successColor.withOpacity(0.1),
                            border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(screenWidth * 0.03),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.successColor,
                                  size: screenWidth * 0.06,
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wallet Connected',
                                      style: AppTheme.modernSubtitle.copyWith(
                                        fontSize: screenWidth * 0.045,
                                        color: AppTheme.textColor,
                                      ),
                                    ),
                                    SizedBox(height: screenHeight * 0.005),
                                    Text(
                                      '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                                      style: AppTheme.modernBodySecondary.copyWith(
                                        fontSize: screenWidth * 0.04,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _disconnectWallet,
                                child: Container(
                                  padding: EdgeInsets.all(screenWidth * 0.03),
                                  decoration: BoxDecoration(
                                    color: AppTheme.cardColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Icon(
                                    Icons.logout_rounded,
                                    color: AppTheme.textSecondary,
                                    size: screenWidth * 0.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.04),

                      // Modern Connection Buttons
                      if (!_isConnected) ...[
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectWallet,
                            style: AppTheme.modernPrimaryButton,
                            child: _isConnecting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: screenWidth * 0.05,
                                        height: screenWidth * 0.05,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textColor),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'Connecting...',
                                        style: AppTheme.modernButton.copyWith(
                                          fontSize: screenWidth * 0.045,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: screenWidth * 0.06,
                                        color: AppTheme.textColor,
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'Connect Wallet',
                                        style: AppTheme.modernButton.copyWith(
                                          fontSize: screenWidth * 0.045,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.04),

                        // Modern Supported Wallets Info
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.05),
                          decoration: AppTheme.modernCardDecoration,
                          child: Column(
                            children: [
                              Text(
                                'Supported Wallets',
                                style: AppTheme.modernSubtitle.copyWith(
                                  fontSize: screenWidth * 0.045,
                                  color: AppTheme.textColor,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Wrap(
                                spacing: screenWidth * 0.03,
                                runSpacing: screenHeight * 0.015,
                                children: [
                                  _buildModernWalletChip('Core', screenWidth),
                                  _buildModernWalletChip('MetaMask', screenWidth),
                                  _buildModernWalletChip('Trust Wallet', screenWidth),
                                  _buildModernWalletChip('Phantom', screenWidth),
                                  _buildModernWalletChip('Coinbase', screenWidth),
                                  _buildModernWalletChip('Rainbow', screenWidth),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Modern Continue Button (when connected)
                      if (_isConnected)
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: _continueWithWallet,
                            style: AppTheme.modernPrimaryButton.copyWith(
                              backgroundColor: MaterialStateProperty.all(AppTheme.successColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward_rounded, size: screenWidth * 0.06, color: AppTheme.textColor),
                                SizedBox(width: screenWidth * 0.03),
                                Text(
                                  'Continue',
                                  style: AppTheme.modernButton.copyWith(
                                    fontSize: screenWidth * 0.045,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.03),

                      // Modern Skip Button
                      TextButton(
                        onPressed: _skipWalletConnection,
                        style: AppTheme.modernTextButton,
                        child: Text(
                          'Skip for now',
                          style: AppTheme.modernButton.copyWith(
                            fontSize: screenWidth * 0.04,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.05),

                      // Modern Info Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.05),
                        decoration: AppTheme.modernContainerDecoration,
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(screenWidth * 0.03),
                              decoration: BoxDecoration(
                                color: AppTheme.accentColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.accentColor,
                                size: screenWidth * 0.06,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.04),
                            Expanded(
                              child: Text(
                                'Secure wallet connection powered by WalletConnect. Your keys remain in your wallet at all times.',
                                style: AppTheme.modernBodySecondary.copyWith(
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

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

  Widget _buildModernWalletChip(String walletName, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.02,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Text(
        walletName,
        style: AppTheme.modernCaption.copyWith(
          color: AppTheme.textColor,
          fontSize: screenWidth * 0.035,
        ),
      ),
    );
  }
}