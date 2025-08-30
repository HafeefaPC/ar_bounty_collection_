import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/services/storage_service.dart';

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
      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: '3b63c12d82703e4367c241580f9ccc06',
        metadata: const PairingMetadata(
          name: 'AR Bounty Collection',
          description: 'AR-powered event goodies application for claiming virtual rewards at real-world locations',
          url: 'https://ar-bounty-collection.app',
          icons: ['https://ar-bounty-collection.app/icon.png'],
        ),
      );

      await _appKitModal!.init();

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
    } catch (e) {
      setState(() {
        _isInitialized = true;
        _connectionError = 'Failed to initialize wallet connection: $e';
      });
      _showError('Failed to initialize wallet connection: $e');
    }
  }

  void _onSessionUpdate() {
    setState(() {
      _isConnected = _appKitModal!.isConnected;
      _isConnecting = false;
      // For now, set a placeholder until we find the correct API
      if (_isConnected) {
        _walletAddress = 'Connected'; // Placeholder
        _showSuccess('Wallet connected successfully!');
        _saveWalletData('connected');
      } else {
        _walletAddress = null;
        _clearWalletData();
      }
    });
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
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
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

                      // Wallet Icon
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
                              color: Colors.black.withValues(alpha: 0.1),
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

                      // Description
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                        child: Text(
                          'Connect your Web3 wallet using WalletConnect to participate in AR airdrop events. Supports Core, MetaMask, Trust Wallet, and more.',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      SizedBox(height: screenHeight * 0.04),

                      // Connection Error Display
                      if (_connectionError != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          margin: EdgeInsets.only(bottom: screenHeight * 0.02),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.errorColor.withValues(alpha: 0.3),
                            ),
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
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: screenWidth * 0.035,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Connected Wallet Display
                      if (_isConnected && _walletAddress != null)
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
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
                                      '${_walletAddress!.substring(0, 6)}...${_walletAddress!.substring(_walletAddress!.length - 4)}',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
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
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.logout,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    size: screenWidth * 0.05,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(height: screenHeight * 0.04),

                      // Connection Buttons
                      if (!_isConnected) ...[
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
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
                                          fontSize: screenWidth * 0.045,
                                          fontWeight: FontWeight.w600,
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
                                      ),
                                      SizedBox(width: screenWidth * 0.03),
                                      Text(
                                        'Connect Wallet',
                                        style: TextStyle(
                                          fontSize: screenWidth * 0.045,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.03),

                        // Supported Wallets Info
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.04),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Supported Wallets',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.02),
                              Wrap(
                                spacing: screenWidth * 0.03,
                                runSpacing: screenHeight * 0.01,
                                children: [
                                  _buildWalletChip('Core', screenWidth),
                                  _buildWalletChip('MetaMask', screenWidth),
                                  _buildWalletChip('Trust Wallet', screenWidth),
                                  _buildWalletChip('Phantom', screenWidth),
                                  _buildWalletChip('Coinbase', screenWidth),
                                  _buildWalletChip('Rainbow', screenWidth),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Continue Button (when connected)
                      if (_isConnected)
                        SizedBox(
                          width: double.infinity,
                          height: screenHeight * 0.07,
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
                                    fontSize: screenWidth * 0.045,
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
                          foregroundColor: Colors.white.withValues(alpha: 0.8),
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

                      // Info Section
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.04),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withValues(alpha: 0.8),
                              size: screenWidth * 0.06,
                            ),
                            SizedBox(height: screenHeight * 0.01),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                              child: Text(
                                'Secure wallet connection powered by WalletConnect. Your keys remain in your wallet at all times.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildWalletChip(String walletName, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.025,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        walletName,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: screenWidth * 0.03,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}