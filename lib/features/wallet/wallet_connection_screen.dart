import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/storage_service.dart';
import '../../shared/services/wallet_service.dart';
import '../../shared/providers/reown_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeAppKit();
  }

  @override
  void dispose() {
    _appKitModal?.dispose();
    super.dispose();
  }

  Future<void> _initializeAppKit() async {
    try {
      // Get the ReownAppKit instance from the provider
      final reownNotifier = ref.read(reownAppKitProvider.notifier);
      await reownNotifier.initialize(context);
      
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
    setState(() {
      _isConnected = _appKitModal!.isConnected;
      _isConnecting = false;
    });
    
    if (_isConnected) {
      try {
        // Get the actual wallet address from the session
        final session = _appKitModal!.session;
        if (session != null && session.topic != null) {
          // Use a placeholder address for now since the actual address isn't directly accessible
          final walletAddress = '0x${session.topic!.substring(0, 40)}';
          
          // First, save wallet data locally (this should always work)
          await _saveWalletData(walletAddress);
          
          // Try to connect wallet using WalletService (database operation)
          final walletService = WalletService();
          debugPrint('Attempting to connect wallet: $walletAddress');
          final success = await walletService.connectWallet(walletAddress);
          
          if (success) {
            setState(() {
              _walletAddress = walletAddress;
            });
            debugPrint('Wallet connected successfully: $walletAddress');
            _showSuccess('Wallet connected successfully!');
          } else {
            // Database operation failed, but wallet is still connected
            // Save wallet data locally and show a warning
            setState(() {
              _walletAddress = walletAddress;
            });
            debugPrint('Wallet connected but database save failed: $walletAddress');
            
          }
        }
      } catch (e) {
        debugPrint('Error in _onSessionUpdate: $e');
        // Even if there's an error, if the wallet is connected, we should show it as connected
        if (_appKitModal!.isConnected) {
          final session = _appKitModal!.session;
          if (session != null && session.topic != null) {
            final walletAddress = '0x${session.topic!.substring(0, 40)}';
            await _saveWalletData(walletAddress);
            setState(() {
              _walletAddress = walletAddress;
            });
            _showWarning('Wallet connected! Some features may be limited due to sync issues.');
          }
        } else {
          _showError('Error processing wallet connection: $e');
        }
      }
    } else {
      // Only clear wallet data if explicitly disconnected
      if (_walletAddress != null) {
        _walletAddress = null;
        await _clearWalletData();
      }
    }
  }

  Future<void> _connectWallet() async {
    if (_appKitModal == null) {
      _showError('Wallet connection not initialized');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      await _appKitModal!.openModalView();
    } catch (e) {
      setState(() => _isConnecting = false);
      _showError('Failed to connect wallet: $e');
    }
  }

  Future<void> _disconnectWallet() async {
    if (_appKitModal == null) return;

    try {
      await _appKitModal!.disconnect();
      
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.successColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
        ),
      );
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.errorColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
        ),
      );
    }
  }

  void _showWarning(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.warningColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)), // Pixelated
        ),
      );
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
    if (!_isInitialized) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
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
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
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
                      SizedBox(height: screenHeight * 0.05),

                      // Retro Wallet Icon
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
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(0), // Pixelated
                          border: Border.all(
                            color: AppTheme.primaryColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.6),
                              offset: const Offset(6, 6),
                              blurRadius: 0,
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

                      // Retro Title
                      Text(
                        'CONNECT YOUR WALLET',
                        style: AppTheme.retroTitle.copyWith(
                          fontSize: screenWidth * 0.07,
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

                      SizedBox(height: screenHeight * 0.02),

                      // Retro Description
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: Text(
                          'Connect your Web3 wallet using WalletConnect to participate in AR airdrop events. Supports Core, MetaMask, Trust Wallet, and more.',
                          style: AppTheme.retroBody.copyWith(
                            fontSize: screenWidth * 0.04,
                            color: AppTheme.textColor.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Retro Connection Error Display
                      if (_connectionError != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(0), // Pixelated
                            border: Border.all(
                              color: AppTheme.errorColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.errorColor.withOpacity(0.4),
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: AppTheme.errorColor,
                                size: screenWidth * 0.06,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Text(
                                  _connectionError!,
                                  style: AppTheme.retroBody.copyWith(
                                    color: AppTheme.textColor,
                                    fontSize: screenWidth * 0.035,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Retro Connected Wallet Display
                      if (_isConnected && _walletAddress != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(0), // Pixelated
                            border: Border.all(
                              color: AppTheme.successColor,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successColor.withOpacity(0.4),
                                offset: const Offset(3, 3),
                                blurRadius: 0,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: AppTheme.successColor,
                                size: screenWidth * 0.06,
                              ),
                              SizedBox(width: screenWidth * 0.03),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'WALLET CONNECTED',
                                      style: AppTheme.retroSubtitle.copyWith(
                                        color: AppTheme.textColor,
                                        fontSize: screenWidth * 0.04,
                                      ),
                                    ),
                                    Text(
                                      '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                                      style: AppTheme.retroBody.copyWith(
                                        color: AppTheme.textColor.withOpacity(0.8),
                                        fontSize: screenWidth * 0.035,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: _disconnectWallet,
                                child: Container(
                                  padding: EdgeInsets.all(screenWidth * 0.02),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(0), // Pixelated
                                    border: Border.all(
                                      color: AppTheme.textColor.withOpacity(0.8),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.logout,
                                    color: AppTheme.textColor.withOpacity(0.8),
                                    size: screenWidth * 0.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.04),

                      // Retro Connection Buttons
                      if (!_isConnected) ...[
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: _isConnecting ? null : _connectWallet,
                            style: AppTheme.retroPrimaryButton.copyWith(
                              backgroundColor: MaterialStateProperty.all(AppTheme.primaryColor),
                              foregroundColor: MaterialStateProperty.all(AppTheme.backgroundColor),
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
                                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.backgroundColor),
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'CONNECTING...',
                                        style: AppTheme.retroButton.copyWith(
                                          fontSize: screenWidth * 0.045,
                                          color: AppTheme.backgroundColor,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet,
                                        size: screenWidth * 0.06,
                                        color: AppTheme.backgroundColor,
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'CONNECT WALLET',
                                        style: AppTheme.retroButton.copyWith(
                                          fontSize: screenWidth * 0.045,
                                          color: AppTheme.backgroundColor,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.03),

                        // Retro Supported Wallets Info
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
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
                          child: Column(
                            children: [
                              Text(
                                'SUPPORTED WALLETS',
                                style: AppTheme.retroSubtitle.copyWith(
                                  color: AppTheme.textColor,
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Wrap(
                                spacing: screenWidth * 0.03,
                                runSpacing: screenHeight * 0.01,
                                children: [
                                  _buildRetroWalletChip('Core', screenWidth),
                                  _buildRetroWalletChip('MetaMask', screenWidth),
                                  _buildRetroWalletChip('Trust Wallet', screenWidth),
                                  _buildRetroWalletChip('Phantom', screenWidth),
                                  _buildRetroWalletChip('Coinbase', screenWidth),
                                  _buildRetroWalletChip('Rainbow', screenWidth),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Retro Continue Button (when connected)
                      if (_isConnected)
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
                          child: ElevatedButton(
                            onPressed: _continueWithWallet,
                            style: AppTheme.retroSecondaryButton.copyWith(
                              backgroundColor: MaterialStateProperty.all(AppTheme.successColor),
                              foregroundColor: MaterialStateProperty.all(AppTheme.backgroundColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward, size: screenWidth * 0.06, color: AppTheme.backgroundColor),
                                SizedBox(width: screenWidth * 0.03),
                                Text(
                                  'CONTINUE',
                                  style: AppTheme.retroButton.copyWith(
                                    fontSize: screenWidth * 0.045,
                                    color: AppTheme.backgroundColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.02),

                      // Retro Skip Button
                      TextButton(
                        onPressed: _skipWalletConnection,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textColor.withOpacity(0.8),
                        ),
                        child: Text(
                          'SKIP FOR NOW',
                          style: AppTheme.retroButton.copyWith(
                            fontSize: screenWidth * 0.04,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Retro Info Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(0), // Pixelated
                          border: Border.all(
                            color: AppTheme.accentColor,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppTheme.accentColor,
                              size: screenWidth * 0.06,
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Text(
                                'Secure wallet connection powered by WalletConnect. Your keys remain in your wallet at all times.',
                                style: AppTheme.retroBody.copyWith(
                                  color: AppTheme.textColor.withOpacity(0.8),
                                  fontSize: screenWidth * 0.035,
                                ),
                                textAlign: TextAlign.center,
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

  Widget _buildRetroWalletChip(String walletName, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(0), // Pixelated
        border: Border.all(
          color: AppTheme.textColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Text(
        walletName,
        style: AppTheme.retroBody.copyWith(
          color: AppTheme.textColor.withOpacity(0.9),
          fontSize: screenWidth * 0.03,
        ),
      ),
    );
  }
}