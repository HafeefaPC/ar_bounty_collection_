import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reown_appkit/reown_appkit.dart';
import '../services/wallet_state_manager.dart';

// Global ReownAppKit instance provider - using keepAlive to prevent disposal
final reownAppKitProvider = StateNotifierProvider<ReownAppKitNotifier, ReownAppKitModal?>((ref) {
  ref.keepAlive(); // Keep the provider alive across page navigation
  return ReownAppKitNotifier();
});

// Provider for wallet connection state - using keepAlive to prevent disposal
final walletConnectionProvider = StateNotifierProvider<WalletConnectionNotifier, WalletConnectionState>((ref) {
  ref.keepAlive(); // Keep the provider alive across page navigation
  return WalletConnectionNotifier(
    ref.read(reownAppKitProvider.notifier),
    ref.read(walletStateManagerProvider),
  );
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
      debugPrint('Initializing ReownAppKit with strict Arbitrum-only configuration...');
      
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

      // Add Arbitrum Sepolia to supported networks BEFORE creating the modal
      ReownAppKitModalNetworks.addSupportedNetworks('eip155', [
        ReownAppKitModalNetworkInfo(
          name: 'Arbitrum Sepolia',
          chainId: '421614',
          chainIcon: 'https://arbitrum.io/wp-content/uploads/2021/01/cropped-Arbitrum_Symbol-Full-color-White-background-192x192.png',
          currency: 'ETH',
          rpcUrl: 'https://sepolia-rollup.arbitrum.io/rpc',
          explorerUrl: 'https://sepolia.arbiscan.io',
          isTestNetwork: true,
        )
      ]);

      final appKitModal = ReownAppKitModal(
        context: context,
        projectId: '77dc05c098aa26a200191c6f8cbd5194',
        metadata: const PairingMetadata(
          name: 'AR Bounty Collection',
          description: 'AR-powered event goodies application for claiming virtual rewards at real-world locations',
          url: 'https://ar-bounty-collection.app',
          icons: ['https://ar-bounty-collection.app/icon.png'],
          redirect: Redirect(
            native: 'arbountycollection://',
            universal: 'https://ar-bounty-collection.app',
          ),
        ),
        // STRICT: Only allow Arbitrum Sepolia in required namespaces
        requiredNamespaces: {
          'eip155': RequiredNamespace(
            chains: [
              'eip155:421614', // ONLY Arbitrum Sepolia
            ],
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
              'eth_accounts',
              'eth_requestAccounts',
              'wallet_switchEthereumChain',
              'wallet_addEthereumChain',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
        // Even optional namespaces should be limited to Arbitrum family
        optionalNamespaces: {
          'eip155': RequiredNamespace(
            chains: [
              'eip155:42161', // Only Arbitrum One as fallback
            ],
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
              'eth_accounts',
              'eth_requestAccounts',
              'wallet_switchEthereumChain',
              'wallet_addEthereumChain',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
        // Include specific wallets that work well with Arbitrum
        includedWalletIds: {
          '1ae92b26df02f0abca6304df07debccd18262fdf5fe82daa81593582dac9a369', // Core
          'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96', // MetaMask
          '4622a2b2d6af1c9844944291e5e7351a6aa24cd7b23099efac1b2fd875da31a0', // Trust Wallet
          'fd20dc426fb37566d803205b19bbc1d4096b248ac04548e3cfb6b3a38bd033aa', // Coinbase Wallet
          'ef333840daf915aafdc4a004525502d6d49d77bd9c65e0642dbaef2e0b5a3b0e', // OKX Wallet
        },
        // Explicitly exclude wallets that might not support Arbitrum well
        excludedWalletIds: const <String>{},
      );

      await appKitModal.init();
      
      // WAIT for initialization to complete before setting default chain
      await Future.delayed(const Duration(milliseconds: 500));
      
      // CRITICAL: Aggressively set Arbitrum Sepolia as the default
      try {
        debugPrint('Setting default chain to Arbitrum Sepolia...');
        
        // Try to set Arbitrum Sepolia as the default chain
        final arbitrumSepoliaNetwork = ReownAppKitModalNetworks.getNetworkById('eip155', '421614');
        
        if (arbitrumSepoliaNetwork != null) {
          await appKitModal.selectChain(arbitrumSepoliaNetwork);
          debugPrint('Successfully set Arbitrum Sepolia as default chain');
          
          // Verify the chain was set correctly
          await Future.delayed(const Duration(milliseconds: 200));
          final currentChain = appKitModal.selectedChain?.chainId;
          debugPrint('Verification: Current selected chain is: $currentChain');
          
          if (currentChain != '421614') {
            debugPrint('WARNING: Default chain setting may not have worked properly');
          }
        } else {
          debugPrint('WARNING: Arbitrum Sepolia network not found in default networks');
          debugPrint('The network will be added when user connects and switches');
        }
        
      } catch (e) {
        debugPrint('Error setting default chain: $e');
        // Continue anyway, but the user will need to switch manually
      }
      
      state = appKitModal;
      _isInitialized = true;
      
      // Set up listeners after initialization
      _setupListeners(appKitModal);
      
      debugPrint('ReownAppKit initialized successfully with strict Arbitrum configuration');
      
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
        debugPrint('Current chain: ${appKitModal.selectedChain?.chainId}');
        
        // If connected but not on Arbitrum Sepolia, show warning and attempt switch
        final listenerChainId = appKitModal.selectedChain?.chainId?.replaceAll('eip155:', '') ?? '';
        if (appKitModal.isConnected && listenerChainId != '421614') {
          debugPrint('Warning: Connected to chain ${appKitModal.selectedChain?.chainId} instead of Arbitrum Sepolia (421614)');
          
          // Attempt automatic switch after a brief delay
          Future.delayed(const Duration(milliseconds: 2000), () async {
            final currentChainId = appKitModal.selectedChain?.chainId?.replaceAll('eip155:', '') ?? '';
            if (appKitModal.isConnected && currentChainId != '421614') {
              debugPrint('Attempting automatic chain switch to Arbitrum Sepolia...');
              final switched = await ensureArbitrumSepolia();
              if (!switched) {
                debugPrint('Automatic chain switch failed - user intervention required');
              }
            }
          });
        }
        
        // Update the state to trigger listeners
        Future(() => state = appKitModal);
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
  // Method to switch to Arbitrum Sepolia if on wrong chain
  Future<bool> ensureArbitrumSepolia() async {
    if (state == null || !state!.isConnected) return false;
    
    final currentChainId = state!.selectedChain?.chainId?.replaceAll('eip155:', '') ?? '';
    if (currentChainId != '421614') {
      try {
        debugPrint('Attempting to switch to Arbitrum Sepolia...');
        debugPrint('Current chain: ${state!.selectedChain?.chainId}');
        
        // First try to find Arbitrum Sepolia in available networks
        final arbitrumSepoliaNetwork = ReownAppKitModalNetworks.getNetworkById('eip155', '421614');
        if (arbitrumSepoliaNetwork != null) {
          await state!.selectChain(arbitrumSepoliaNetwork);
          debugPrint('Switched to Arbitrum Sepolia via selectChain');
          
          // Wait for the switch to complete and verify
          await Future.delayed(const Duration(seconds: 2));
          final newChainId = state!.selectedChain?.chainId;
          debugPrint('After selectChain, current chain: $newChainId');
          
          if (newChainId == '421614') {
            return true;
          }
        } else {
          // If not found, try to request the wallet to switch via wallet_switchEthereumChain
          debugPrint('Arbitrum Sepolia not found in networks, requesting wallet switch...');
          
          final session = state!.session;
          if (session != null) {
            // Get the current chain ID for the request (remove eip155: prefix if present)
            final currentChainId = (state!.selectedChain?.chainId ?? '1').replaceAll('eip155:', '');
            debugPrint('Using current chain ID for request: eip155:$currentChainId');
            
            try {
              await state!.request(
                topic: session.topic!,
                chainId: 'eip155:$currentChainId', // Use actual current chain
                request: SessionRequestParams(
                  method: 'wallet_switchEthereumChain',
                  params: [
                    {'chainId': '0x66eee'} // 421614 in hex
                  ],
                ),
              );
              debugPrint('Requested wallet switch to Arbitrum Sepolia');
              // Wait for the switch to complete
              await Future.delayed(const Duration(seconds: 3));
              
              // Verify the switch
              final newChainId = state!.selectedChain?.chainId;
              debugPrint('After wallet_switchEthereumChain, current chain: $newChainId');
              
              if (newChainId == '421614') {
                return true;
              }
            } catch (switchError) {
              debugPrint('Switch failed, trying to add network: $switchError');
              
              // If switch fails, try to add the network first
              try {
                await state!.request(
                  topic: session.topic!,
                  chainId: 'eip155:$currentChainId', // Use actual current chain
                  request: SessionRequestParams(
                    method: 'wallet_addEthereumChain',
                    params: [
                      {
                        'chainId': '0x66eee', // 421614 in hex
                        'chainName': 'Arbitrum Sepolia',
                        'rpcUrls': ['https://sepolia-rollup.arbitrum.io/rpc'],
                        'nativeCurrency': {
                          'name': 'Ethereum',
                          'symbol': 'ETH',
                          'decimals': 18,
                        },
                        'blockExplorerUrls': ['https://sepolia.arbiscan.io'],
                      }
                    ],
                  ),
                );
                debugPrint('Successfully added Arbitrum Sepolia network');
                // After adding, try to switch again
                await Future.delayed(const Duration(milliseconds: 500));
                try {
                  await state!.request(
                    topic: session.topic!,
                    chainId: 'eip155:$currentChainId',
                    request: SessionRequestParams(
                      method: 'wallet_switchEthereumChain',
                      params: [
                        {'chainId': '0x66eee'} // 421614 in hex
                      ],
                    ),
                  );
                  debugPrint('Successfully switched to newly added Arbitrum Sepolia');
                  await Future.delayed(const Duration(seconds: 2));
                  
                  // Verify the switch
                  final newChainId = state!.selectedChain?.chainId;
                  debugPrint('After adding network and switching, current chain: $newChainId');
                  
                  if (newChainId == '421614') {
                    return true;
                  }
                } catch (secondSwitchError) {
                  debugPrint('Failed to switch after adding network: $secondSwitchError');
                }
                return true;
              } catch (addError) {
                debugPrint('Failed to add network: $addError');
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error switching to Arbitrum Sepolia: $e');
      }
      return false;
    }
    return true; // Already on Arbitrum Sepolia
  }
}



// State notifier for wallet connection
class WalletConnectionNotifier extends StateNotifier<WalletConnectionState> {
  final ReownAppKitNotifier _reownNotifier;
  final WalletStateManager _stateManager;

  WalletConnectionNotifier(this._reownNotifier, this._stateManager) : super(WalletConnectionState()) {
    _setupListeners();
    _loadPersistedState();
  }

  /// Load persisted wallet state on initialization
  Future<void> _loadPersistedState() async {
    try {
      final persistedState = await _stateManager.loadWalletState();
      if (persistedState != null) {
        Future(() => state = persistedState);
        debugPrint('WalletConnectionNotifier: Loaded persisted state - Connected: ${persistedState.isConnected}');
      }
    } catch (e) {
      debugPrint('WalletConnectionNotifier: Error loading persisted state: $e');
    }
  }

  void _setupListeners() {
    // Listen to ReownAppKit changes
    _reownNotifier.addListener((ReownAppKitModal? appKitModal) {
      try {
        // Delay state update to avoid Riverpod lifecycle issues
        Future(() => _updateConnectionState());
      } catch (e) {
        debugPrint('Error in wallet connection listener: $e');
        // Don't rethrow to prevent crashes
      }
    });
  }

  void _updateConnectionState() async {
    final appKitModal = _reownNotifier.state;
    if (appKitModal == null) {
      Future(() => state = WalletConnectionState());
      return;
    }

    final isConnected = appKitModal.isConnected;
    final session = appKitModal.session;
    
    if (isConnected && session != null) {
      String? walletAddress;
      
      try {
        // Try to get wallet address from session accounts first
        final accounts = session.getAccounts();
        if (accounts?.isNotEmpty == true) {
          // Extract address from the account string (format: eip155:chainId:address)
          final account = accounts!.first;
          final parts = account.split(':');
          if (parts.length >= 3) {
            walletAddress = parts[2];
            debugPrint('Found wallet address from session: $walletAddress');
          }
        }
        
        // If no address from session, try eth_accounts request
        if (walletAddress == null) {
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
          }
        }
        
        // Final fallback
        if (walletAddress == null || walletAddress == 'Unknown Wallet') {
          walletAddress = 'Connected Wallet';
        }
      } catch (e) {
        debugPrint('Error getting wallet address: $e');
        walletAddress = 'Connected Wallet';
      }
      
      final chainId = appKitModal.selectedChain?.chainId ?? '421614'; // Default to Arbitrum Sepolia
      // Warn if not on Arbitrum Sepolia (extract numeric chain ID)
      final numericChainId = chainId.replaceAll('eip155:', '');
      if (numericChainId != '421614') {
        debugPrint('WARNING: Connected to chain $chainId instead of Arbitrum Sepolia (421614)');
      }
      
      final newState = WalletConnectionState(
        isConnected: true,
        walletAddress: walletAddress,
        chainId: chainId,
        sessionTopic: session.topic,
      );
      
      // Update state in next frame to avoid Riverpod lifecycle issues
      Future(() => state = newState);
      
      // Save to persistent storage
      _stateManager.saveWalletState(newState);
      
      debugPrint('Wallet connected: $walletAddress on chain $chainId');
      debugPrint('Session topic: ${session.topic}');
      debugPrint('Selected chain: ${appKitModal.selectedChain?.chainId}');
      
      // Debug session namespaces and accounts
      debugPrint('Session namespaces: ${session.namespaces}');
      debugPrint('Session accounts: ${session.getAccounts()}');
    } else {
      final newState = WalletConnectionState(
        isConnected: false,
        walletAddress: null,
        chainId: null,
        sessionTopic: null,
      );
      
      // Update state in next frame to avoid Riverpod lifecycle issues
      Future(() => state = newState);
      
      // Clear persistent storage
      _stateManager.clearWalletState();
      
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
      
      // After connection attempt, ensure we're on Arbitrum Sepolia
      if (appKitModal.isConnected) {
        debugPrint('Wallet connected, now ensuring correct chain...');
        // Wait a bit for the session to stabilize
        await Future.delayed(const Duration(milliseconds: 1500));
        
        // Force refresh the connection state first
        refreshConnectionState();
        
        // Then ensure we're on Arbitrum Sepolia
        final switched = await _reownNotifier.ensureArbitrumSepolia();
        if (!switched && appKitModal.selectedChain?.chainId != '421614') {
          debugPrint('Failed to automatically switch to Arbitrum Sepolia. User will need to switch manually.');
        }
      }
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

    // Ensure we're on Arbitrum Sepolia before sending transaction
    if (state.chainId != '421614') {
      final switched = await _reownNotifier.ensureArbitrumSepolia();
      if (!switched) {
        throw Exception('Please switch to Arbitrum Sepolia network');
      }
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
           state.chainId == '421614' && // Must be on Arbitrum Sepolia
           _reownNotifier.state != null;
  }

  // Get the current ReownAppKit instance
  ReownAppKitModal? getAppKitModal() {
    return _reownNotifier.state;
  }

  // Force refresh the connection state
  void refreshConnectionState() {
    debugPrint('Force refreshing wallet connection state...');
    // Delay state update to avoid Riverpod lifecycle issues
    Future(() => _updateConnectionState());
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
      
      // Delay state update to avoid Riverpod lifecycle issues
      Future(() => _updateConnectionState());
      
      // Ensure we're on the correct chain
      await _reownNotifier.ensureArbitrumSepolia();
    } else {
      debugPrint('No existing wallet session found');
    }
  }

  // Method to force switch to Arbitrum Sepolia
  Future<bool> switchToArbitrumSepolia() async {
    debugPrint('WalletConnectionNotifier: Attempting to switch to Arbitrum Sepolia...');
    
    try {
      // First, refresh the connection state to get the latest information
      _updateConnectionState();
      
      // Wait a moment for the state to update
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Attempt to switch using the ReownAppKit notifier
      final success = await _reownNotifier.ensureArbitrumSepolia();
      
      if (success) {
        debugPrint('WalletConnectionNotifier: Successfully switched to Arbitrum Sepolia');
        
        // Wait for the switch to complete
        await Future.delayed(const Duration(seconds: 2));
        
        // Force refresh the connection state after the switch
        _updateConnectionState();
        
        // Wait for state to update
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Verify the switch was successful
        final currentState = state;
        if (currentState.chainId == '421614') {
          debugPrint('WalletConnectionNotifier: Verified switch to Arbitrum Sepolia (Chain ID: ${currentState.chainId})');
          return true;
        } else {
          debugPrint('WalletConnectionNotifier: Switch verification failed. Current chain: ${currentState.chainId}');
          return false;
        }
      } else {
        debugPrint('WalletConnectionNotifier: Failed to switch to Arbitrum Sepolia');
        return false;
      }
    } catch (e) {
      debugPrint('WalletConnectionNotifier: Error switching to Arbitrum Sepolia: $e');
      return false;
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
