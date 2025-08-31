import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/reown_appkit.dart';

// Global ReownAppKit instance provider
final reownAppKitProvider = StateNotifierProvider<ReownAppKitNotifier, ReownAppKitModal?>((ref) {
  return ReownAppKitNotifier();
});

// Provider for wallet connection state
final walletConnectionProvider = StateNotifierProvider<WalletConnectionNotifier, WalletConnectionState>((ref) {
  return WalletConnectionNotifier(ref.read(reownAppKitProvider.notifier));
});

// State notifier for ReownAppKit
class ReownAppKitNotifier extends StateNotifier<ReownAppKitModal?> {
  ReownAppKitNotifier() : super(null);

  Future<void> initialize(BuildContext context) async {
    if (state != null) return; // Already initialized

    try {
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
            chains: ['eip155:43113', 'eip155:43114'], // Avalanche Fuji + Mainnet
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
      
      // Set up listeners after initialization
      _setupListeners(appKitModal);
    } catch (e) {
      debugPrint('Error initializing ReownAppKit: $e');
      rethrow;
    }
  }

  void _setupListeners(ReownAppKitModal appKitModal) {
    // Listen for session updates
    appKitModal.addListener(() {
      debugPrint('ReownAppKit session updated - Connected: ${appKitModal.isConnected}');
    });
  }

  void dispose() {
    state?.dispose();
    state = null;
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
      _updateConnectionState();
    });
  }

  void _updateConnectionState() {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) {
      state = WalletConnectionState();
      return;
    }

    final isConnected = appKitModal.isConnected;
    final session = appKitModal.session;
    
    if (isConnected && session != null) {
      final walletAddress = session.peer?.metadata?.name ?? 'Unknown Wallet';
      final chainId = appKitModal.selectedChain?.chainId ?? '43113';
      
      state = WalletConnectionState(
        isConnected: true,
        walletAddress: walletAddress,
        chainId: chainId,
        sessionTopic: session.topic,
      );
      
      debugPrint('Wallet connected: $walletAddress on chain $chainId');
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
