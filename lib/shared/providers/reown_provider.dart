import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/reown_appkit.dart';

// Global ReownAppKit instance provider - using keepAlive to prevent disposal
final reownAppKitProvider = StateNotifierProvider<ReownAppKitNotifier, ReownAppKitModal?>((ref) {
  ref.keepAlive(); // Keep the provider alive across page navigation
  return ReownAppKitNotifier();
});

// Provider for wallet connection state - using keepAlive to prevent disposal
final walletConnectionProvider = StateNotifierProvider<WalletConnectionNotifier, WalletConnectionState>((ref) {
  ref.keepAlive(); // Keep the provider alive across page navigation
  return WalletConnectionNotifier(ref.read(reownAppKitProvider.notifier));
});

// State notifier for ReownAppKit
class ReownAppKitNotifier extends StateNotifier<ReownAppKitModal?> {
  ReownAppKitNotifier() : super(null);
  bool _isInitialized = false;

  Future<void> initialize(BuildContext context) async {
    if (_isInitialized && state != null) {
      debugPrint('ReownAppKit already initialized, skipping...');
      return; // Already initialized
    }

    try {
      debugPrint('Initializing ReownAppKit...');
      
      // Dispose existing instance if any
      if (state != null) {
        debugPrint('Disposing existing ReownAppKit instance...');
        try {
          state?.dispose();
        } catch (e) {
          debugPrint('Error disposing existing instance: $e');
        }
        state = null;
      }

      final appKitModal = ReownAppKitModal(
        context: context,
        projectId: '3b63c12d82703e4367c241580f9ccc06',
        metadata: const PairingMetadata(
          name: 'AR Bounty Collection',
          description: 'AR-powered event goodies application for claiming virtual rewards at real-world locations',
          url: 'https://ar-bounty-collection.app',
          icons: ['https://ar-bounty-collection.app/icon.png'],
        ),
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: ['eip155:421614', 'eip155:43113', 'eip155:43114'], // Arbitrum Sepolia + Avalanche Fuji + Mainnet
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
        optionalNamespaces: {
          'eip155': RequiredNamespace(
            chains: ['eip155:1', 'eip155:137', 'eip155:56'], // Ethereum, Polygon, BSC
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      await appKitModal.init();
      state = appKitModal;
      _isInitialized = true;
      
      // Set up listeners after initialization
      _setupListeners(appKitModal);
      
      debugPrint('ReownAppKit initialized successfully');
    } catch (e) {
      debugPrint('Error initializing ReownAppKit: $e');
      _isInitialized = false;
      state = null;
      rethrow;
    }
  }

  void _setupListeners(ReownAppKitModal appKitModal) {
    // Listen for session updates
    appKitModal.addListener(() {
      try {
        debugPrint('ReownAppKit session updated - Connected: ${appKitModal.isConnected}');
        // Update the state to trigger listeners
        state = appKitModal;
      } catch (e) {
        debugPrint('Error in ReownAppKit listener: $e');
        // Don't rethrow to prevent crashes
      }
    });
  }

  @override
  void dispose() {
    debugPrint('Disposing ReownAppKitNotifier...');
    if (state != null) {
      try {
        state?.dispose();
      } catch (e) {
        debugPrint('Error disposing ReownAppKitModal: $e');
      }
      state = null;
    }
    _isInitialized = false;
    super.dispose();
  }

  // Method to check if ReownAppKit is ready to use
  bool isReady() {
    return _isInitialized && state != null;
  }

  // Method to force reinitialize (useful for recovery)
  Future<void> forceReinitialize(BuildContext context) async {
    debugPrint('Force reinitializing ReownAppKit...');
    _isInitialized = false;
    state = null;
    await initialize(context);
  }
}

// State notifier for wallet connection
class WalletConnectionNotifier extends StateNotifier<WalletConnectionState> {
  final ReownAppKitNotifier _reownNotifier;

  WalletConnectionNotifier(this._reownNotifier) : super(WalletConnectionState()) {
    _setupListeners();
  }

  void _setupListeners() {
    // Listen to ReownAppKit changes
    _reownNotifier.addListener((ReownAppKitModal? appKitModal) {
      try {
        _updateConnectionState();
      } catch (e) {
        debugPrint('Error in wallet connection listener: $e');
        // Don't rethrow to prevent crashes
      }
    });
  }

  void _updateConnectionState() async {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) {
      state = WalletConnectionState();
      return;
    }

    final isConnected = appKitModal.isConnected;
    final session = appKitModal.session;
    
    if (isConnected && session != null) {
      // Get the actual wallet address from the session
      String walletAddress = 'Unknown Wallet';
      
      // Try to get the wallet address by making a request to get accounts
      try {
        final result = await appKitModal.request(
          topic: session.topic!,
          chainId: 'eip155:${appKitModal.selectedChain?.chainId ?? '421614'}',
          request: SessionRequestParams(
            method: 'eth_accounts',
            params: [],
          ),
        );
        
        if (result != null && result is List && result.isNotEmpty) {
          walletAddress = result.first.toString();
          debugPrint('Found wallet address from eth_accounts: $walletAddress');
        } else {
          debugPrint('No accounts returned from eth_accounts, using fallback');
          walletAddress = '0x${session.topic!.substring(0, 40)}';
        }
      } catch (e) {
        debugPrint('Error getting wallet address: $e, using fallback');
        walletAddress = '0x${session.topic!.substring(0, 40)}';
      }
      
      final chainId = appKitModal.selectedChain?.chainId ?? '421614'; // Default to Arbitrum Sepolia
      
      state = WalletConnectionState(
        isConnected: true,
        walletAddress: walletAddress,
        chainId: chainId,
        sessionTopic: session.topic,
      );
      
      debugPrint('Wallet connected: $walletAddress on chain $chainId');
      debugPrint('Session topic: ${session.topic}');
      debugPrint('Selected chain: ${appKitModal.selectedChain?.chainId}');
    } else {
      state = WalletConnectionState(
        isConnected: false,
        walletAddress: null,
        chainId: null,
        sessionTopic: null,
      );
      
      debugPrint('Wallet disconnected');
    }
  }

  Future<void> connect() async {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) {
      throw Exception('ReownAppKit not initialized');
    }

    try {
      debugPrint('Opening wallet connection modal...');
      await appKitModal.openModalView();
    } catch (e) {
      debugPrint('Error connecting wallet: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) return;

    try {
      debugPrint('Disconnecting wallet...');
      await appKitModal.disconnect();
    } catch (e) {
      debugPrint('Error disconnecting wallet: $e');
      rethrow;
    }
  }

  Future<String?> sendTransaction(Map<String, dynamic> transaction) async {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null || !state.isConnected) {
      throw Exception('Wallet not connected');
    }

    try {
      final result = await appKitModal.request(
        topic: state.sessionTopic!,
        chainId: 'eip155:${state.chainId}',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transaction],
        ),
      );

      return result?.toString();
    } catch (e) {
      debugPrint('Error sending transaction: $e');
      rethrow;
    }
  }

  // Helper method to check if wallet is ready for transactions
  bool isWalletReady() {
    return state.isConnected && 
           state.sessionTopic != null && 
           state.chainId != null &&
           _reownNotifier.state != null;
  }

  // Get the current ReownAppKit instance
  ReownAppKitModal? getAppKitModal() {
    return _reownNotifier.state;
  }

  // Force refresh the connection state
  void refreshConnectionState() {
    debugPrint('Force refreshing wallet connection state...');
    _updateConnectionState();
  }

  // Method to restore wallet connection state from storage
  Future<void> restoreWalletState() async {
    debugPrint('Attempting to restore wallet connection state...');
    
    // Check if ReownAppKit is ready
    if (!_reownNotifier.isReady()) {
      debugPrint('ReownAppKit not ready, cannot restore state');
      return;
    }

    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) {
      debugPrint('AppKitModal is null, cannot restore state');
      return;
    }

    // Check if there's an existing session
    if (appKitModal.isConnected && appKitModal.session != null) {
      debugPrint('Found existing wallet session, restoring state...');
      _updateConnectionState();
    } else {
      debugPrint('No existing wallet session found');
    }
  }
}

// Wallet connection state
class WalletConnectionState {
  final bool isConnected;
  final String? walletAddress;
  final String? chainId;
  final String? sessionTopic;

  WalletConnectionState({
    this.isConnected = false,
    this.walletAddress,
    this.chainId,
    this.sessionTopic,
  });

  WalletConnectionState copyWith({
    bool? isConnected,
    String? walletAddress,
    String? chainId,
    String? sessionTopic,
  }) {
    return WalletConnectionState(
      isConnected: isConnected ?? this.isConnected,
      walletAddress: walletAddress ?? this.walletAddress,
      chainId: chainId ?? this.chainId,
      sessionTopic: sessionTopic ?? this.sessionTopic,
    );
  }

  @override
  String toString() {
    return 'WalletConnectionState(isConnected: $isConnected, walletAddress: $walletAddress, chainId: $chainId)';
  }
}
