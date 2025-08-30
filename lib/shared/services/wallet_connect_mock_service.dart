import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/wallet_connect_config.dart';

class WalletConnectMockService {
  static final WalletConnectMockService _instance = WalletConnectMockService._internal();
  factory WalletConnectMockService() => _instance;
  WalletConnectMockService._internal();

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
  bool _isConnected = false;
  String? _walletAddress;
  String? _chainId;
  String? _sessionTopic;
  Map<String, dynamic>? _sessionData;
  
  // Stream controllers for real-time updates
  final StreamController<WalletConnectEvent> _eventController = 
      StreamController<WalletConnectEvent>.broadcast();
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected && _walletAddress != null;
  String? get walletAddress => _walletAddress;
  String? get chainId => _chainId;
  String? get sessionTopic => _sessionTopic;
  Stream<WalletConnectEvent> get events => _eventController.stream;

  // Initialize Wallet Connect service (mock)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Mock initialization - in real implementation this would initialize WalletConnect
      if (kDebugMode) {
        print('Mock Wallet Connect service initialized');
        print('Project ID: ${WalletConnectConfig.projectId}');
        print('App Name: ${WalletConnectConfig.appName}');
      }
      
      // Check for existing sessions
      await _checkExistingSessions();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('Mock Wallet Connect service ready');
        print('Connected: $_isConnected');
        print('Wallet address: $_walletAddress');
        print('Chain ID: $_chainId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing mock Wallet Connect service: $e');
      }
      rethrow;
    }
  }

  // Connect to Core mobile wallet (mock)
  Future<bool> connectToCore() async {
    if (!_isInitialized) {
      throw Exception('Mock Wallet Connect service not initialized');
    }

    try {
      if (kDebugMode) {
        print('Mock: Generating WalletConnect URI for Core mobile...');
        print('Mock: URI would be: wc:mock_uri_for_core_mobile_${DateTime.now().millisecondsSinceEpoch}');
      }

      // Simulate connection delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock successful connection
      _isConnected = true;
      _walletAddress = '0xMockWalletAddress${DateTime.now().millisecondsSinceEpoch}';
      _chainId = '43113'; // Avalanche Fuji testnet
      _sessionTopic = 'mock_session_${DateTime.now().millisecondsSinceEpoch}';
      _sessionData = {
        'topic': _sessionTopic,
        'peer': {
          'name': 'Core Mobile',
          'description': 'Core mobile wallet',
          'url': 'https://core.app',
          'icons': ['https://core.app/icon.png'],
        },
        'namespaces': {
          'eip155': {
            'accounts': ['eip155:$_chainId:$_walletAddress'],
            'methods': WalletConnectConfig.requiredMethods,
            'events': WalletConnectConfig.requiredEvents,
          },
        },
      };
      
      // Save session data
      await _saveSessionData();
      
      // Emit connected event
      _eventController.add(WalletConnectEvent(
        type: WalletConnectEventType.connected,
        data: {
          'walletAddress': _walletAddress,
          'chainId': _chainId,
          'sessionTopic': _sessionTopic,
        },
      ));
      
      if (kDebugMode) {
        print('Mock: Successfully connected to Core Mobile');
        print('Mock: Wallet address: $_walletAddress');
        print('Mock: Chain ID: $_chainId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error connecting to Core: $e');
      }
      return false;
    }
  }

  // Disconnect from wallet (mock)
  Future<bool> disconnect() async {
    if (!_isConnected) {
      return false;
    }

    try {
      // Simulate disconnection delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      _isConnected = false;
      _walletAddress = null;
      _chainId = null;
      _sessionTopic = null;
      _sessionData = null;
      
      // Clear saved session data
      await _clearSessionData();
      
      // Emit disconnected event
      _eventController.add(WalletConnectEvent(
        type: WalletConnectEventType.disconnected,
        data: null,
      ));
      
      if (kDebugMode) {
        print('Mock: Successfully disconnected from Core Mobile');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error disconnecting: $e');
      }
      return false;
    }
  }

  // Sign message (mock)
  Future<String?> signMessage(String message) async {
    if (!_isConnected) {
      throw Exception('No active wallet connection');
    }

    try {
      // Simulate signing delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Generate mock signature
      final mockSignature = '0xMockSignature${DateTime.now().millisecondsSinceEpoch}';
      
      if (kDebugMode) {
        print('Mock: Message signed: $message');
        print('Mock: Signature: $mockSignature');
      }
      
      return mockSignature;
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error signing message: $e');
      }
      rethrow;
    }
  }

  // Send transaction (mock)
  Future<String?> sendTransaction({
    required String to,
    required String value,
    String? data,
    String? gasLimit,
    String? gasPrice,
  }) async {
    if (!_isConnected) {
      throw Exception('No active wallet connection');
    }

    try {
      // Simulate transaction delay
      await Future.delayed(const Duration(seconds: 2));
      
      // Generate mock transaction hash
      final mockTxHash = '0xMockTransactionHash${DateTime.now().millisecondsSinceEpoch}';
      
      if (kDebugMode) {
        print('Mock: Transaction sent');
        print('Mock: To: $to');
        print('Mock: Value: $value');
        print('Mock: Tx Hash: $mockTxHash');
      }
      
      return mockTxHash;
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error sending transaction: $e');
      }
      rethrow;
    }
  }

  // Switch chain (mock)
  Future<bool> switchChain(String chainId) async {
    if (!_isConnected) {
      throw Exception('No active wallet connection');
    }

    try {
      // Simulate chain switching delay
      await Future.delayed(const Duration(seconds: 1));
      
      _chainId = chainId;
      await _saveSessionData();
      
      if (kDebugMode) {
        print('Mock: Switched to chain: $chainId');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error switching chain: $e');
      }
      return false;
    }
  }

  // Check existing sessions (mock)
  Future<void> _checkExistingSessions() async {
    try {
      // Try to load saved session data
      await _loadSessionData();
      
      if (_sessionData != null) {
        // Restore mock session
        _isConnected = true;
        _walletAddress = _sessionData!['mockWalletAddress'];
        _chainId = _sessionData!['mockChainId'];
        _sessionTopic = _sessionData!['mockSessionTopic'];
        
        if (kDebugMode) {
          print('Mock: Restored existing session');
          print('Mock: Wallet address: $_walletAddress');
          print('Mock: Chain ID: $_chainId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error checking existing sessions: $e');
      }
    }
  }

  // Save session data securely (mock)
  Future<void> _saveSessionData() async {
    if (_sessionData != null) {
      final mockData = {
        ..._sessionData!,
        'mockWalletAddress': _walletAddress,
        'mockChainId': _chainId,
        'mockSessionTopic': _sessionTopic,
        'savedAt': DateTime.now().toIso8601String(),
      };
      
      await _secureStorage.write(
        key: 'mock_wallet_connect_session',
        value: jsonEncode(mockData),
      );
    }
  }

  // Load saved session data (mock)
  Future<void> _loadSessionData() async {
    try {
      final sessionData = await _secureStorage.read(key: 'mock_wallet_connect_session');
      if (sessionData != null) {
        _sessionData = jsonDecode(sessionData);
        
        if (kDebugMode) {
          print('Mock: Loaded saved session data');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Mock: Error loading session data: $e');
      }
    }
  }

  // Clear saved session data (mock)
  Future<void> _clearSessionData() async {
    await _secureStorage.delete(key: 'mock_wallet_connect_session');
  }

  // Get supported chains
  List<String> getSupportedChains() {
    return WalletConnectConfig.requiredChains.map((chain) => chain.split(':').last).toList();
  }

  // Validate wallet address format
  static bool isValidAddress(String address) {
    return address.startsWith('0x') && address.length == 42;
  }

  // Get shortened address for display
  static String getShortAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  // Get wallet type
  String getWalletType() {
    if (_sessionData != null) {
      final peer = _sessionData!['peer'];
      if (peer != null && peer['name'] != null) {
        return peer['name'];
      }
    }
    return 'Core Mobile (Mock)';
  }

  // Clean up resources
  void dispose() {
    _eventController.close();
  }
}

// Wallet Connect event types
enum WalletConnectEventType {
  connected,
  disconnected,
  expired,
  updated,
  custom,
}

// Wallet Connect event class
class WalletConnectEvent {
  final WalletConnectEventType type;
  final Map<String, dynamic>? data;

  WalletConnectEvent({
    required this.type,
    this.data,
  });
}
