import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/reown_provider.dart';

/// Manages wallet state persistence across app sessions and screen navigation
class WalletStateManager {
  static const String _keyWalletAddress = 'wallet_address';
  static const String _keyChainId = 'chain_id';
  static const String _keyIsConnected = 'is_connected';
  static const String _keySessionTopic = 'session_topic';
  static const String _keyConnectionTime = 'connection_time';

  static final WalletStateManager _instance = WalletStateManager._internal();
  factory WalletStateManager() => _instance;
  WalletStateManager._internal();

  /// Save wallet connection state to persistent storage
  Future<void> saveWalletState(WalletConnectionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_keyIsConnected, state.isConnected);
      await prefs.setString(_keyWalletAddress, state.walletAddress ?? '');
      await prefs.setString(_keyChainId, state.chainId ?? '');
      await prefs.setString(_keySessionTopic, state.sessionTopic ?? '');
      await prefs.setString(_keyConnectionTime, DateTime.now().toIso8601String());
      
      debugPrint('WalletStateManager: Saved wallet state - Connected: ${state.isConnected}, Address: ${state.walletAddress}');
    } catch (e) {
      debugPrint('WalletStateManager: Error saving wallet state: $e');
    }
  }

  /// Load wallet connection state from persistent storage
  Future<WalletConnectionState?> loadWalletState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final isConnected = prefs.getBool(_keyIsConnected) ?? false;
      if (!isConnected) return null;
      
      final walletAddress = prefs.getString(_keyWalletAddress);
      final chainId = prefs.getString(_keyChainId);
      final sessionTopic = prefs.getString(_keySessionTopic);
      final connectionTimeStr = prefs.getString(_keyConnectionTime);
      
      // Check if the connection is not too old (24 hours)
      if (connectionTimeStr != null) {
        final connectionTime = DateTime.parse(connectionTimeStr);
        final now = DateTime.now();
        final difference = now.difference(connectionTime);
        
        if (difference.inHours > 24) {
          debugPrint('WalletStateManager: Stored connection is too old, clearing state');
          await clearWalletState();
          return null;
        }
      }
      
      if (walletAddress?.isNotEmpty == true) {
        final state = WalletConnectionState(
          isConnected: isConnected,
          walletAddress: walletAddress,
          chainId: chainId,
          sessionTopic: sessionTopic,
        );
        
        debugPrint('WalletStateManager: Loaded wallet state - Connected: $isConnected, Address: $walletAddress');
        return state;
      }
      
      return null;
    } catch (e) {
      debugPrint('WalletStateManager: Error loading wallet state: $e');
      return null;
    }
  }

  /// Clear wallet connection state from persistent storage
  Future<void> clearWalletState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.remove(_keyIsConnected);
      await prefs.remove(_keyWalletAddress);
      await prefs.remove(_keyChainId);
      await prefs.remove(_keySessionTopic);
      await prefs.remove(_keyConnectionTime);
      
      debugPrint('WalletStateManager: Cleared wallet state');
    } catch (e) {
      debugPrint('WalletStateManager: Error clearing wallet state: $e');
    }
  }

  /// Check if there's a stored wallet connection
  Future<bool> hasStoredConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyIsConnected) ?? false;
    } catch (e) {
      debugPrint('WalletStateManager: Error checking stored connection: $e');
      return false;
    }
  }
}

/// Provider for the wallet state manager
final walletStateManagerProvider = Provider<WalletStateManager>((ref) {
  return WalletStateManager();
});