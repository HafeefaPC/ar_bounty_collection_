import 'wallet_connect_service.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final WalletConnectService _walletConnectService = WalletConnectService();

  String? get walletAddress => _walletConnectService.walletAddress;
  String? get connectedWalletAddress => _walletConnectService.walletAddress;
  bool get isConnected => _walletConnectService.isConnected;

  // Initialize WalletConnect service
  Future<void> initialize() async {
    await _walletConnectService.initialize();
  }

  // Connect wallet with WalletConnect modal
  Future<bool> connectWallet() async {
    try {
      // This would require context, so we return true for now
      // The actual connection will happen when openModal is called
      return true;
    } catch (e) {
      return false;
    }
  }

  // Open wallet connection modal (requires context)
  Future<void> openWalletModal(context) async {
    await _walletConnectService.openModal(context);
  }

  // Connect to Core mobile wallet via Wallet Connect
  Future<bool> connectToCoreMobile() async {
    return await _walletConnectService.connectToCore();
  }

  // Connect wallet with email authentication (legacy - now redirects to WalletConnect)
  Future<bool> connectWalletWithEmail(String email) async {
    // Email authentication is not supported with pure WalletConnect
    // This method is kept for backward compatibility
    return false;
  }

  // Connect external wallet
  Future<bool> connectExternalWallet({String? walletType}) async {
    try {
      return await _walletConnectService.connectToCore();
    } catch (e) {
      return false;
    }
  }

  // Disconnect wallet
  Future<void> disconnectWallet() async {
    await _walletConnectService.disconnect();
  }

  // Check if wallet was previously connected
  Future<bool> checkPreviousConnection() async {
    return _walletConnectService.isConnected;
  }

  // Get wallet balance (needs to be implemented with Web3 calls)
  Future<double> getWalletBalance() async {
    // This would require a Web3 service to get the actual balance
    // For now, return 0.0
    return 0.0;
  }

  // Sign message
  Future<String> signMessage(String message) async {
    final signature = await _walletConnectService.signMessage(message);
    return signature ?? '';
  }

  // Send transaction
  Future<String> sendTransaction({
    required String to,
    required String amount,
    String? data,
  }) async {
    // Convert amount to wei (assuming amount is in ETH/AVAX)
    final wei = (double.parse(amount) * 1e18).toInt().toRadixString(16);
    final txHash = await _walletConnectService.sendTransaction(
      to: to,
      value: '0x$wei',
      data: data,
    );
    return txHash ?? '';
  }

  // Get transaction history (would need to be implemented with blockchain API)
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    // This would require a blockchain API service
    return [];
  }

  // Export wallet (not supported with WalletConnect)
  Future<String?> exportWallet() async {
    // Not supported with WalletConnect as it's non-custodial
    return null;
  }

  // Get user profile (limited with WalletConnect)
  Map<String, dynamic>? get userProfile => {
    'walletAddress': walletAddress,
    'walletType': getWalletType(),
  };

  // Get user email (not available with WalletConnect)
  String? get userEmail => null;

  // Validate wallet address format
  static bool isValidAddress(String address) {
    return WalletConnectService.isValidAddress(address);
  }

  // Get shortened address for display
  static String getShortAddress(String address) {
    return WalletConnectService.getShortAddress(address);
  }

  // Get wallet type
  String getWalletType() {
    return _walletConnectService.getWalletType();
  }

  // Create embedded wallet (not supported with WalletConnect)
  Future<bool> createEmbeddedWallet() async {
    return false;
  }

  // Check if user has embedded wallet (not supported with WalletConnect)
  bool hasEmbeddedWallet() {
    return false;
  }

  // Connect wallet with SMS authentication (not supported with WalletConnect)
  Future<bool> connectWalletWithSMS(String phoneNumber) async {
    return false;
  }

  // Switch to specific chain
  Future<bool> switchChain(String chainId) async {
    return await _walletConnectService.switchChain(chainId);
  }

  // Get supported chains
  List<String> getSupportedChains() {
    return _walletConnectService.getSupportedChains();
  }

  // Get wallet connect service events stream
  Stream<WalletConnectEvent> get walletEvents => _walletConnectService.events;

  // Get current chain ID
  String? get chainId => _walletConnectService.chainId;

  // Clean up resources
  void dispose() {
    _walletConnectService.dispose();
  }
}