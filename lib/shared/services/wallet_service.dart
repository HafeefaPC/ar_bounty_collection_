import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'supabase_service.dart';

class WalletService {
  static const _storage = FlutterSecureStorage();
  static const String _walletAddressKey = 'wallet_address';
  static const String _isConnectedKey = 'is_wallet_connected';
  static const String _connectionTimeKey = 'wallet_connection_time';
  
  ReownAppKitModal? _appKitModal;
  String? _connectedWalletAddress;
  bool _isConnected = false;
  final SupabaseService _supabaseService = SupabaseService();

  // Getters
  String? get connectedWalletAddress => _connectedWalletAddress;
  bool get isConnected => _isConnected;
  ReownAppKitModal? get appKitModal => _appKitModal;

  // Initialize wallet service
  Future<void> initialize(BuildContext context) async {
    await _loadWalletState();
  }

  // Set ReownAppKit instance
  void setReownAppKit(ReownAppKitModal appKitModal) {
    _appKitModal = appKitModal;
    debugPrint('ReownAppKit set in WalletService');
    
    // Update wallet state from ReownAppKit
    if (appKitModal.isConnected && appKitModal.session != null) {
      final session = appKitModal.session!;
      final accounts = session.getAccounts();
      if (accounts != null && accounts.isNotEmpty) {
        // Extract address from the account string (format: eip155:chainId:address)
        final account = accounts.first;
        final parts = account.split(':');
        if (parts.length >= 3) {
          _connectedWalletAddress = parts[2];
          _isConnected = true;
          debugPrint('Wallet address updated from ReownAppKit: $_connectedWalletAddress');
        }
      }
    }
  }

  // Load wallet state from secure storage
  Future<void> _loadWalletState() async {
    try {
      final walletAddress = await _storage.read(key: _walletAddressKey);
      final isConnected = await _storage.read(key: _isConnectedKey);
      
      if (walletAddress != null && isConnected == 'true') {
        _connectedWalletAddress = walletAddress;
        _isConnected = true;
        debugPrint('Wallet state loaded: $walletAddress');
      }
    } catch (e) {
      debugPrint('Error loading wallet state: $e');
    }
  }

  // Save wallet state to secure storage
  Future<void> _saveWalletState(String walletAddress) async {
    try {
      await _storage.write(key: _walletAddressKey, value: walletAddress);
      await _storage.write(key: _isConnectedKey, value: 'true');
      await _storage.write(key: _connectionTimeKey, value: DateTime.now().toIso8601String());
      
      _connectedWalletAddress = walletAddress;
      _isConnected = true;
      
      debugPrint('Wallet state saved: $walletAddress');
    } catch (e) {
      debugPrint('Error saving wallet state: $e');
    }
  }

  // Clear wallet state from secure storage
  Future<void> _clearWalletState() async {
    try {
      await _storage.delete(key: _walletAddressKey);
      await _storage.delete(key: _isConnectedKey);
      await _storage.delete(key: _connectionTimeKey);
      
      _connectedWalletAddress = null;
      _isConnected = false;
      
      debugPrint('Wallet state cleared');
    } catch (e) {
      debugPrint('Error clearing wallet state: $e');
    }
  }

  // Connect wallet and create user in database
  Future<bool> connectWallet(String walletAddress) async {
    try {
      // Test database connection first
      debugPrint('Testing database connection...');
      try {
        final testResponse = await _supabaseService.getUserByWalletAddress('test_connection');
        debugPrint('Database connection test: $testResponse');
      } catch (testError) {
        debugPrint('Database connection test failed: $testError');
      }
      
      // Create or update user in database
      final userCreated = await _createOrUpdateUser(walletAddress);
      
      if (userCreated) {
        // Save wallet state locally
        await _saveWalletState(walletAddress);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error connecting wallet: $e');
      // Even if database fails, try to save wallet state locally
      try {
        await _saveWalletState(walletAddress);
        debugPrint('Wallet state saved locally despite database failure');
        return true; // Return true since wallet is functionally connected
      } catch (localError) {
        debugPrint('Failed to save wallet state locally: $localError');
        return false;
      }
    }
  }

  // Create or update user in database
  Future<bool> _createOrUpdateUser(String walletAddress) async {
    try {
      debugPrint('Starting _createOrUpdateUser for wallet: $walletAddress');
      
      // Check if user already exists
      debugPrint('Checking if user exists...');
      final existingUser = await _supabaseService.getUserByWalletAddress(walletAddress);
      debugPrint('Existing user check result: ${existingUser != null ? 'Found' : 'Not found'}');
      
      if (existingUser != null) {
        // Update last login
        debugPrint('Updating last login for existing user...');
        await _supabaseService.updateUserLastLogin(walletAddress);
        debugPrint('User updated successfully: $walletAddress');
        return true;
      } else {
        // Create new user
        debugPrint('Creating new user...');
        final newUser = {
          'wallet_address': walletAddress,
          'username': 'user_${walletAddress.substring(0, 8)}',
          'display_name': 'User ${walletAddress.substring(0, 8)}',
          'created_at': DateTime.now().toIso8601String(),
          'last_login': DateTime.now().toIso8601String(),
          'preferences': {},
          'stats': {
            'total_nfts_earned': 0,
            'total_events_joined': 0,
            'total_boundaries_claimed': 0
          }
        };
        
        debugPrint('New user data: $newUser');
        final success = await _supabaseService.createUser(newUser);
        debugPrint('Create user result: $success');
        
        if (success) {
          debugPrint('New user created successfully: $walletAddress');
          return true;
        } else {
          debugPrint('Failed to create user: $walletAddress');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error in _createOrUpdateUser: $e');
      debugPrint('Error stack trace: ${StackTrace.current}');
      return false;
    }
  }

  // Disconnect wallet
  Future<void> disconnectWallet() async {
    try {
      await _clearWalletState();
      debugPrint('Wallet disconnected');
    } catch (e) {
      debugPrint('Error disconnecting wallet: $e');
    }
  }

  // Check if wallet is connected
  Future<bool> checkWalletConnection() async {
    await _loadWalletState();
    return _isConnected && _connectedWalletAddress != null;
  }

  // Check if wallet is connected (local check only, no database)
  bool isWalletConnectedLocally() {
    final connected = _isConnected && _connectedWalletAddress != null;
    debugPrint('WalletService.isWalletConnectedLocally() called: $connected');
    debugPrint('  - _isConnected: $_isConnected');
    debugPrint('  - _connectedWalletAddress: $_connectedWalletAddress');
    return connected;
  }

  // Get wallet address
  String? get walletAddress => _connectedWalletAddress;

  // Force refresh wallet state from storage
  Future<void> refreshWalletState() async {
    debugPrint('WalletService.refreshWalletState() called');
    await _loadWalletState();
    debugPrint('Wallet state refreshed - Connected: $_isConnected, Address: $_connectedWalletAddress');
  }

  // Set app kit modal (for AR functionality)
  void setAppKitModal(ReownAppKitModal modal) {
    _appKitModal = modal;
  }

  // Dispose
  void dispose() {
    _appKitModal?.dispose();
  }
}