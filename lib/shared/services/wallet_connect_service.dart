import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../config/wallet_connect_config.dart';

class WalletConnectService {
  static final WalletConnectService _instance = WalletConnectService._internal();
  factory WalletConnectService() => _instance;
  WalletConnectService._internal();

  // State management
  bool _isInitialized = false;
  ReownAppKitModal? _appKitModal;
  
  // Stream controllers for real-time updates
  final StreamController<WalletConnectEvent> _eventController = 
      StreamController<WalletConnectEvent>.broadcast();
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _appKitModal?.isConnected ?? false;
  String? get walletAddress => _appKitModal?.session?.peer?.metadata?.name;
  String? get chainId => _appKitModal?.selectedChain?.chainId;
  Stream<WalletConnectEvent> get events => _eventController.stream;
  ReownAppKitModal? get appKitModal => _appKitModal;

  // Initialize Wallet Connect service using Reown AppKit
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) return;

    try {
      // Create featured wallets list including Core
      final featuredWalletIds = <String>{
        '1ae92b26df02f0abca6304df07debccd18262fdf5fe82daa81593582dac9a369', // Core
        'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96', // MetaMask
        'ecc4036f814562b41a5268adc86270fba1365471402006302e70169465b7ac18', // Zerion
      };

      // Initialize AppKit with configuration
      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: WalletConnectConfig.projectId,
        metadata: const PairingMetadata(
          name: WalletConnectConfig.appName,
          description: WalletConnectConfig.appDescription,
          url: WalletConnectConfig.appUrl,
          icons: [WalletConnectConfig.appIcon],
          redirect: Redirect(
            native: WalletConnectConfig.nativeScheme,
            universal: WalletConnectConfig.universalUrl,
          ),
        ),
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: WalletConnectConfig.requiredChains,
            methods: WalletConnectConfig.requiredMethods,
            events: WalletConnectConfig.requiredEvents,
          ),
        },
        optionalNamespaces: {
          'eip155': RequiredNamespace(
            chains: WalletConnectConfig.optionalChains,
            methods: WalletConnectConfig.requiredMethods,
            events: WalletConnectConfig.requiredEvents,
          ),
        },
        featuredWalletIds: featuredWalletIds,
      );

      // Set up event listeners
      _setupEventListeners();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('WalletConnect service initialized with Reown AppKit');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing WalletConnect service: $e');
      }
      rethrow;
    }
  }

  // Set up event listeners
  void _setupEventListeners() {
    if (_appKitModal == null) return;

    // Session connected
    _appKitModal!.onModalConnect.subscribe((args) {
      _eventController.add(WalletConnectEvent(
        type: WalletConnectEventType.connected,
        data: {
          'walletAddress': _appKitModal!.session?.peer?.metadata?.name,
          'chainId': _appKitModal!.selectedChain?.chainId,
          'sessionTopic': _appKitModal!.session?.topic,
        },
      ));
      
      if (kDebugMode) {
        print('Wallet connected: ${_appKitModal!.session?.peer?.metadata?.name}');
      }
    });

    // Session disconnected
    _appKitModal!.onModalDisconnect.subscribe((args) {
      _eventController.add(WalletConnectEvent(
        type: WalletConnectEventType.disconnected,
        data: null,
      ));
      
      if (kDebugMode) {
        print('Wallet disconnected');
      }
    });

    // Chain changed
    _appKitModal!.onModalNetworkChange.subscribe((args) {
      _eventController.add(WalletConnectEvent(
        type: WalletConnectEventType.updated,
        data: {'chainId': args?.chainId},
      ));
      
      if (kDebugMode) {
        print('Chain switched to: ${args?.chainId}');
      }
    });
  }

  // Open wallet connection modal
  Future<void> openModal(context) async {
    if (!_isInitialized || _appKitModal == null) {
      throw Exception('WalletConnect service not initialized');
    }

    try {
      await _appKitModal!.openModalView(context);
    } catch (e) {
      if (kDebugMode) {
        print('Error opening wallet modal: $e');
      }
      rethrow;
    }
  }

  // Connect to Core mobile wallet directly
  Future<bool> connectToCore() async {
    if (!_isInitialized || _appKitModal == null) {
      throw Exception('WalletConnect service not initialized');
    }

    try {
      // Try to connect to Core wallet specifically
      // This would typically involve opening the modal and letting user select Core
      // For now, we'll open the general modal
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error connecting to Core: $e');
      }
      return false;
    }
  }

  // Disconnect from wallet
  Future<bool> disconnect() async {
    if (!isConnected || _appKitModal == null) {
      return false;
    }

    try {
      await _appKitModal!.disconnect();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error disconnecting: $e');
      }
      return false;
    }
  }

  // Sign message
  Future<String?> signMessage(String message) async {
    if (!isConnected || _appKitModal == null) {
      throw Exception('No active wallet connection');
    }

    try {
      final signature = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:${_appKitModal!.selectedChain!.chainId}',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _appKitModal!.session!.peer?.metadata?.name ?? ''],
        ),
      );
      
      if (kDebugMode) {
        print('Message signed: $signature');
      }
      
      return signature.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing message: $e');
      }
      rethrow;
    }
  }

  // Send transaction
  Future<String?> sendTransaction({
    required String to,
    required String value,
    String? data,
    String? gasLimit,
    String? gasPrice,
  }) async {
    if (!isConnected || _appKitModal == null) {
      throw Exception('No active wallet connection');
    }

    try {
      final transaction = {
        'from': _appKitModal!.session!.peer?.metadata?.name ?? '',
        'to': to,
        'value': value,
        if (data != null) 'data': data,
        if (gasLimit != null) 'gasLimit': gasLimit,
        if (gasPrice != null) 'gasPrice': gasPrice,
      };

      final txHash = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:${_appKitModal!.selectedChain!.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transaction],
        ),
      );
      
      if (kDebugMode) {
        print('Transaction sent: $txHash');
      }
      
      return txHash.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending transaction: $e');
      }
      rethrow;
    }
  }

  // Switch chain
  Future<bool> switchChain(String chainId) async {
    if (!isConnected || _appKitModal == null) {
      throw Exception('No active wallet connection');
    }

    try {
      await _appKitModal!.selectChain(
        ReownAppKitModalNetworks.getNetworkById('eip155', chainId) ??
        ReownAppKitModalNetworks.getNetworkById('eip155', '43113')!,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error switching chain: $e');
      }
      return false;
    }
  }

  // Get supported chains
  List<String> getSupportedChains() {
    return [
      '43113', // Avalanche Fuji testnet
      '43114', // Avalanche mainnet
      '1',     // Ethereum mainnet
      '137',   // Polygon
      '56',    // BSC
    ];
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
    if (_appKitModal?.session != null) {
      return _appKitModal?.session?.peer?.metadata?.name ?? 'Unknown Wallet';
    }
    return 'Not Connected';
  }

  // Clean up resources
  void dispose() {
    _eventController.close();
    _appKitModal?.dispose();
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