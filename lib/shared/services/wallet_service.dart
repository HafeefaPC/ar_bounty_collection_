import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class WalletService {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  String? _connectedWalletAddress;
  bool _isConnected = false;

  // Mock wallet addresses for testing
  static const List<String> _mockAddresses = [
    '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6',
    '0x8ba1f109551bD432803012645Hac136c772c3c3',
    '0x1234567890123456789012345678901234567890',
    '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
    '0x9876543210987654321098765432109876543210',
  ];

  String? get walletAddress => _connectedWalletAddress;
  String? get connectedWalletAddress => _connectedWalletAddress;
  bool get isConnected => _isConnected;

  // Simulate wallet connection
  Future<bool> connectWallet() async {
    try {
      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate a random mock address
      final random = Random();
      _connectedWalletAddress = _mockAddresses[random.nextInt(_mockAddresses.length)];
      _isConnected = true;

      // Save to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('wallet_address', _connectedWalletAddress!);
      await prefs.setBool('wallet_connected', true);

      return true;
    } catch (e) {
      print('Error connecting wallet: $e');
      return false;
    }
  }

  // Disconnect wallet
  Future<void> disconnectWallet() async {
    _connectedWalletAddress = null;
    _isConnected = false;

    // Clear from local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('wallet_address');
    await prefs.setBool('wallet_connected', false);
  }

  // Check if wallet was previously connected
  Future<bool> checkPreviousConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('wallet_connected') ?? false;
      
      if (wasConnected) {
        _connectedWalletAddress = prefs.getString('wallet_address');
        _isConnected = _connectedWalletAddress != null;
      }

      return _isConnected;
    } catch (e) {
      print('Error checking previous connection: $e');
      return false;
    }
  }

  // Get wallet balance (mock)
  Future<double> getWalletBalance() async {
    if (!_isConnected) return 0.0;
    
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Return random balance between 0.1 and 10.0
    final random = Random();
    return 0.1 + random.nextDouble() * 9.9;
  }

  // Sign message (mock)
  Future<String> signMessage(String message) async {
    if (!_isConnected) throw Exception('Wallet not connected');
    
    // Simulate signing delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Return mock signature
    final random = Random();
    const chars = '0123456789abcdef';
    return '0x' + String.fromCharCodes(
      Iterable.generate(64, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // Send transaction (mock)
  Future<String> sendTransaction({
    required String to,
    required double amount,
    String? data,
  }) async {
    if (!_isConnected) throw Exception('Wallet not connected');
    
    // Simulate transaction delay
    await Future.delayed(const Duration(seconds: 3));
    
    // Return mock transaction hash
    final random = Random();
    const chars = '0123456789abcdef';
    return '0x' + String.fromCharCodes(
      Iterable.generate(64, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  // Get transaction history (mock)
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    if (!_isConnected) return [];
    
    // Simulate API call delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Return mock transaction history
    return [
      {
        'hash': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        'from': _connectedWalletAddress,
        'to': '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6',
        'value': '0.1',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        'status': 'confirmed',
      },
      {
        'hash': '0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
        'from': '0x8ba1f109551bD432803012645Hac136c772c3c3',
        'to': _connectedWalletAddress,
        'value': '0.5',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
        'status': 'confirmed',
      },
    ];
  }

  // Validate wallet address format
  static bool isValidAddress(String address) {
    // Basic Ethereum address validation
    return address.startsWith('0x') && address.length == 42;
  }

  // Get shortened address for display
  static String getShortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  // Get wallet type (mock)
  String getWalletType() {
    if (!_isConnected) return 'Not Connected';
    
    // Simulate different wallet types
    final random = Random();
    final types = ['MetaMask', 'WalletConnect', 'Coinbase Wallet', 'Trust Wallet'];
    return types[random.nextInt(types.length)];
  }
}

