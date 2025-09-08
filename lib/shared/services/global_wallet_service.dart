import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reown_provider.dart';

/// Global wallet service that manages wallet connection state across the entire app
class GlobalWalletService {
  static final GlobalWalletService _instance = GlobalWalletService._internal();
  factory GlobalWalletService() => _instance;
  GlobalWalletService._internal();

  bool _isInitialized = false;
  WidgetRef? _ref;

  /// Initialize the global wallet service
  Future<void> initialize(WidgetRef ref) async {
    if (_isInitialized) return;
    
    _ref = ref;
    _isInitialized = true;
    
    debugPrint('GlobalWalletService: Initialized');
    
    // Set up periodic sync to ensure state consistency
    _setupPeriodicSync();
    
    // Try to restore wallet state on app startup
    await restoreWalletState();
  }

  /// Set up periodic state synchronization
  void _setupPeriodicSync() {
    // Sync every 5 seconds to ensure state consistency across pages
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized || _ref == null) {
        timer.cancel();
        return;
      }
      
      try {
        final walletNotifier = _ref!.read(walletConnectionProvider.notifier);
        walletNotifier.refreshConnectionState();
      } catch (e) {
        debugPrint('GlobalWalletService: Error in periodic sync: $e');
      }
    });
  }

  /// Restore wallet connection state
  Future<void> restoreWalletState() async {
    if (_ref == null) {
      debugPrint('GlobalWalletService: Ref is null, cannot restore state');
      return;
    }

    try {
      debugPrint('GlobalWalletService: Attempting to restore wallet state...');
      
      final walletNotifier = _ref!.read(walletConnectionProvider.notifier);
      await walletNotifier.restoreWalletState();
      
      final walletState = _ref!.read(walletConnectionProvider);
      debugPrint('GlobalWalletService: Wallet state restored - Connected: ${walletState.isConnected}');
      
    } catch (e) {
      debugPrint('GlobalWalletService: Error restoring wallet state: $e');
    }
  }

  /// Check if wallet is connected
  bool isWalletConnected() {
    if (_ref == null) return false;
    
    try {
      final walletState = _ref!.read(walletConnectionProvider);
      return walletState.isConnected;
    } catch (e) {
      debugPrint('GlobalWalletService: Error checking wallet connection: $e');
      return false;
    }
  }

  /// Get wallet address
  String? getWalletAddress() {
    if (_ref == null) return null;
    
    try {
      final walletState = _ref!.read(walletConnectionProvider);
      return walletState.walletAddress;
    } catch (e) {
      debugPrint('GlobalWalletService: Error getting wallet address: $e');
      return null;
    }
  }

  /// Force refresh wallet state
  void refreshWalletState() {
    if (_ref == null) return;
    
    try {
      final walletNotifier = _ref!.read(walletConnectionProvider.notifier);
      walletNotifier.refreshConnectionState();
    } catch (e) {
      debugPrint('GlobalWalletService: Error refreshing wallet state: $e');
    }
  }

  /// Initialize ReownAppKit if needed
  Future<void> ensureReownAppKitInitialized(BuildContext context) async {
    if (_ref == null) return;
    
    try {
      final reownNotifier = _ref!.read(reownAppKitProvider.notifier);
      if (!reownNotifier.isReady()) {
        debugPrint('GlobalWalletService: ReownAppKit not ready, initializing...');
        await reownNotifier.initialize(context);
      }
    } catch (e) {
      debugPrint('GlobalWalletService: Error initializing ReownAppKit: $e');
    }
  }
}

/// Provider for the global wallet service
final globalWalletServiceProvider = Provider<GlobalWalletService>((ref) {
  return GlobalWalletService();
});
