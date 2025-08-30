import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivyWalletService {
  static final PrivyWalletService _instance = PrivyWalletService._internal();
  factory PrivyWalletService() => _instance;
  PrivyWalletService._internal();

  // Privy instance (placeholder for future implementation)
  dynamic _privy;
  
  // Secure storage for sensitive data
  final _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // State management
  bool _isInitialized = false;
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;
  String? _userEmail;
  String? _phoneNumber;
  String? _walletAddress;
  Map<String, dynamic>? _userProfile;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _isAuthenticated && _user != null;
  String? get userEmail => _userEmail ?? _user?['email'];
  String? get phoneNumber => _phoneNumber ?? _user?['phone'];
  String? get walletAddress => _walletAddress ?? _getWalletAddressFromUser();
  String? get connectedWalletAddress => walletAddress;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isConnected => isAuthenticated && walletAddress != null;
  Map<String, dynamic>? get user => _user;

  // Get wallet address from user's linked accounts
  String? _getWalletAddressFromUser() {
    if (_user == null) return null;
    
    // Look for wallet in user data structure
    final wallets = _user?['linkedAccounts'] as List?;
    if (wallets != null) {
      for (final wallet in wallets) {
        if (wallet['type'] == 'wallet') {
          return wallet['address'];
        }
      }
    }
    return null;
  }

  // Initialize Privy service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // TODO: Initialize actual Privy Flutter SDK when API is available
      // For now, use mock implementation
      _privy = null; // Placeholder
      
      // Check for existing authentication state
      await _checkAuthenticationState();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('Privy wallet service initialized');
        print('Authenticated: $_isAuthenticated');
        print('User: ${_user?['id']}');
        print('Wallet address: $walletAddress');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Privy service: $e');
      }
      _isInitialized = true; // Mark as initialized even if setup fails
    }
  }

  // Check current authentication state
  Future<void> _checkAuthenticationState() async {
    try {
      // Check for stored authentication state
      final prefs = await SharedPreferences.getInstance();
      final isAuthenticated = prefs.getBool('privy_authenticated') ?? false;
      final userData = prefs.getString('privy_user');
      
      if (isAuthenticated && userData != null) {
        _user = jsonDecode(userData);
        _isAuthenticated = true;
        _updateUserInfo();
      } else {
        _resetAuthenticationState();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking authentication state: $e');
      }
      _resetAuthenticationState();
    }
  }

  // Update user information from Privy user object
  void _updateUserInfo() {
    if (_user == null) return;
    
    _userEmail = _user?['email'];
    _phoneNumber = _user?['phone'];
    _walletAddress = _getWalletAddressFromUser();
    
    // Create user profile
    _userProfile = {
      'id': _user?['id'],
      'email': _userEmail,
      'phone': _phoneNumber,
      'wallet_address': _walletAddress,
      'created_at': _user?['createdAt'] ?? DateTime.now().toIso8601String(),
      'wallet_type': getWalletType(),
    };
  }

  // Authenticate with email using Privy SDK
  Future<bool> authenticateWithEmail(String email) async {
    if (!_isInitialized) {
      throw Exception('Privy service not initialized');
    }

    try {
      if (kDebugMode) {
        print('Authenticating with email: $email');
      }

      // For now, simulate the authentication process
      // In production, you would use the actual Privy API calls
      await Future.delayed(const Duration(seconds: 1));
      
      // Create mock user data
      _user = {
        'id': _generateUserId(email),
        'email': email,
        'createdAt': DateTime.now().toIso8601String(),
        'linkedAccounts': [],
      };
      
      _isAuthenticated = true;
      _updateUserInfo();
      _saveAuthenticationState();
      
      // Automatically create embedded wallet for email users
      await createEmbeddedWallet();
      
      if (kDebugMode) {
        print('Successfully authenticated user: ${_user?['id']}');
        print('Email: ${_user?['email']}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error authenticating with email: $e');
      }
      return false;
    }
  }

  // Authenticate with SMS using phone number
  Future<bool> authenticateWithSMS(String phoneNumber) async {
    if (!_isInitialized) {
      throw Exception('Privy service not initialized');
    }

    try {
      if (kDebugMode) {
        print('Authenticating with phone: $phoneNumber');
      }

      // For now, simulate the authentication process
      await Future.delayed(const Duration(seconds: 1));
      
      // Create mock user data
      _user = {
        'id': _generateUserId(phoneNumber),
        'phone': phoneNumber,
        'createdAt': DateTime.now().toIso8601String(),
        'linkedAccounts': [],
      };
      
      _isAuthenticated = true;
      _updateUserInfo();
      _saveAuthenticationState();
      
      // Automatically create embedded wallet for SMS users
      await createEmbeddedWallet();
      
      if (kDebugMode) {
        print('Successfully authenticated user: ${_user?['id']}');
        print('Phone: ${_user?['phone']}');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error authenticating with SMS: $e');
      }
      return false;
    }
  }

  // Connect external wallet
  Future<bool> connectExternalWallet({String? walletType}) async {
    if (!_isInitialized) {
      throw Exception('Privy service not initialized');
    }

    try {
      if (kDebugMode) {
        print('Connecting external wallet...');
      }

      // For now, simulate external wallet connection
      await Future.delayed(const Duration(seconds: 2));
      
      final mockAddress = _generateMockWalletAddress();
      
      // Create user with wallet
      _user = {
        'id': _generateUserId(mockAddress),
        'createdAt': DateTime.now().toIso8601String(),
        'linkedAccounts': [
          {
            'type': 'wallet',
            'address': mockAddress,
            'walletClientType': walletType ?? 'metamask',
          }
        ],
      };
      
      _isAuthenticated = true;
      _updateUserInfo();
      _saveAuthenticationState();
      
      if (kDebugMode) {
        print('Successfully connected wallet: $mockAddress');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting external wallet: $e');
      }
      return false;
    }
  }

  // Create embedded wallet for authenticated user
  Future<bool> createEmbeddedWallet() async {
    if (!_isAuthenticated || _user == null) {
      throw Exception('User must be authenticated first');
    }

    try {
      if (kDebugMode) {
        print('Creating embedded wallet...');
      }

      // Check if user already has a wallet
      if (walletAddress != null) {
        if (kDebugMode) {
          print('User already has a wallet: $walletAddress');
        }
        return true;
      }

      // Simulate wallet creation
      await Future.delayed(const Duration(seconds: 1));
      
      final mockAddress = _generateMockWalletAddress();
      
      // Add wallet to user's linked accounts
      final linkedAccounts = _user?['linkedAccounts'] as List? ?? [];
      linkedAccounts.add({
        'type': 'wallet',
        'address': mockAddress,
        'walletClientType': 'privy',
      });
      
      _user?['linkedAccounts'] = linkedAccounts;
      _updateUserInfo();
      _saveAuthenticationState();
      
      if (kDebugMode) {
        print('Successfully created embedded wallet: $mockAddress');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating embedded wallet: $e');
      }
      return false;
    }
  }

  // Sign message with wallet
  Future<String> signMessage(String message) async {
    if (!isConnected) {
      throw Exception('No wallet connected or authenticated');
    }

    try {
      if (kDebugMode) {
        print('Signing message with wallet: $walletAddress');
      }

      // Simulate message signing
      await Future.delayed(const Duration(milliseconds: 500));
      
      final signature = _generateMockSignature(message);
      
      if (kDebugMode) {
        print('Message signed successfully');
      }
      
      return signature;
    } catch (e) {
      if (kDebugMode) {
        print('Error signing message: $e');
      }
      rethrow;
    }
  }

  // Send transaction
  Future<String> sendTransaction({
    required String to,
    required String amount,
    String? data,
  }) async {
    if (!isConnected) {
      throw Exception('No wallet connected or authenticated');
    }

    try {
      if (kDebugMode) {
        print('Sending transaction from: $walletAddress');
        print('To: $to, Amount: $amount ETH');
      }

      // Simulate transaction sending
      await Future.delayed(const Duration(seconds: 2));
      
      final txHash = _generateMockTransactionHash();
      
      if (kDebugMode) {
        print('Transaction sent successfully: $txHash');
      }
      
      return txHash;
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      rethrow;
    }
  }

  // Get wallet balance
  Future<double> getWalletBalance() async {
    if (!isConnected) {
      return 0.0;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      // Return mock balance based on wallet address
      final addressHash = walletAddress?.hashCode ?? 0;
      return (addressHash % 1000) / 100.0; // Random balance 0-10 ETH
    } catch (e) {
      if (kDebugMode) {
        print('Error getting wallet balance: $e');
      }
      return 0.0;
    }
  }

  // Get transaction history
  Future<List<Map<String, dynamic>>> getTransactionHistory() async {
    if (!isConnected) return [];

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      return [
        {
          'hash': _generateMockTransactionHash(),
          'from': walletAddress,
          'to': '0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6',
          'value': '0.1',
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
          'status': 'confirmed',
          'type': 'NFT_CLAIM',
        },
        {
          'hash': _generateMockTransactionHash(),
          'from': '0x8ba1f109551bD432803012645Hac136c772c3c3',
          'to': walletAddress,
          'value': '0.5',
          'timestamp': DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch,
          'status': 'confirmed',
          'type': 'EVENT_REWARD',
        },
      ];
    } catch (e) {
      if (kDebugMode) {
        print('Error getting transaction history: $e');
      }
      return [];
    }
  }

  // Export wallet (private key access)
  Future<String?> exportWallet() async {
    if (!isConnected) {
      throw Exception('No wallet connected');
    }

    try {
      if (kDebugMode) {
        print('Wallet export requested for: $walletAddress');
      }
      
      // Return null for security - actual implementation would vary
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting wallet: $e');
      }
      return null;
    }
  }

  // Logout and clear session
  Future<void> logout() async {
    try {
      if (_isInitialized && _privy != null) {
        // Call Privy logout if available
        try {
          // TODO: Implement actual Privy logout when API is available
          // await _privy.logout();
        } catch (e) {
          if (kDebugMode) {
            print('Privy logout error: $e');
          }
        }
      }
      
      await _clearAuthenticationState();
      _resetAuthenticationState();
      
      if (kDebugMode) {
        print('Successfully logged out');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during logout: $e');
      }
      // Still reset state even if logout fails
      await _clearAuthenticationState();
      _resetAuthenticationState();
    }
  }

  // Helper Methods

  // Generate mock wallet address
  String _generateMockWalletAddress() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final addressHex = timestamp.toRadixString(16);
    return '0x${addressHex.padLeft(40, '0')}';
  }

  // Generate mock signature
  String _generateMockSignature(String message) {
    final timestamp = DateTime.now().millisecondsSinceEpoch + message.hashCode;
    return '0x${timestamp.toRadixString(16).padLeft(128, '0')}';
  }

  // Generate mock transaction hash
  String _generateMockTransactionHash() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '0x${timestamp.toRadixString(16).padLeft(64, '0')}';
  }

  // Generate consistent user ID
  String _generateUserId(String input) {
    return input.hashCode.abs().toString();
  }

  // Save authentication state to local storage
  Future<void> _saveAuthenticationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool('privy_authenticated', _isAuthenticated);
      
      if (_userEmail != null) {
        await prefs.setString('privy_user_email', _userEmail!);
      }
      
      if (_phoneNumber != null) {
        await prefs.setString('privy_user_phone', _phoneNumber!);
      }
      
      if (_walletAddress != null) {
        await prefs.setString('privy_wallet_address', _walletAddress!);
      }
      
      if (_user != null) {
        await prefs.setString('privy_user', jsonEncode(_user));
      }
      
      if (_userProfile != null) {
        await prefs.setString('privy_user_profile', jsonEncode(_userProfile));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving authentication state: $e');
      }
    }
  }

  // Clear authentication state from local storage
  Future<void> _clearAuthenticationState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('privy_authenticated');
      await prefs.remove('privy_user_email');
      await prefs.remove('privy_user_phone');
      await prefs.remove('privy_wallet_address');
      await prefs.remove('privy_user');
      await prefs.remove('privy_user_profile');
      
      // Clear secure storage
      await _secureStorage.deleteAll();
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing authentication state: $e');
      }
    }
  }

  // Reset internal state
  void _resetAuthenticationState() {
    _isAuthenticated = false;
    _user = null;
    _userEmail = null;
    _phoneNumber = null;
    _walletAddress = null;
    _userProfile = null;
  }

  // Check previous connection
  Future<bool> checkPreviousConnection() async {
    if (!_isInitialized) {
      await initialize();
    }
    return _isAuthenticated;
  }

  // Get wallet type
  String getWalletType() {
    if (!_isAuthenticated || _user == null) return 'Not Connected';
    
    final linkedAccounts = _user?['linkedAccounts'] as List?;
    if (linkedAccounts != null && linkedAccounts.isNotEmpty) {
      final wallet = linkedAccounts.firstWhere(
        (account) => account['type'] == 'wallet',
        orElse: () => null,
      );
      if (wallet != null) {
        return wallet['walletClientType'] ?? 'Unknown Wallet';
      }
    }
    
    return 'No Wallet';
  }

  // Validate Ethereum address format
  static bool isValidAddress(String address) {
    return address.startsWith('0x') && address.length == 42;
  }

  // Get shortened address for display
  static String getShortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  // Get supported authentication methods
  List<String> getSupportedAuthMethods() {
    return [
      'email',
      'sms',
      'wallet', // External wallet connection
    ];
  }

  // Check if user has embedded wallet
  bool hasEmbeddedWallet() {
    if (_user == null) return false;
    
    final linkedAccounts = _user?['linkedAccounts'] as List?;
    if (linkedAccounts != null) {
      return linkedAccounts.any((account) => 
        account['type'] == 'wallet' && 
        account['walletClientType'] == 'privy'
      );
    }
    return false;
  }

  // Get all user's wallets
  List<Map<String, dynamic>> getUserWallets() {
    if (_user == null) return [];
    
    final linkedAccounts = _user?['linkedAccounts'] as List?;
    if (linkedAccounts != null) {
      return linkedAccounts
          .where((account) => account['type'] == 'wallet')
          .cast<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }
}