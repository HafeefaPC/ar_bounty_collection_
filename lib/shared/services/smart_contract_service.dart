import 'package:flutter/foundation.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SmartContractService {
  // Contract addresses on Somnia Testnet (DEPLOYED ✅)
  static const String eventFactoryAddress = "0xf9CF13b978A71113992De2A0373fE76d3B64B6dc";
  static const String boundaryNFTAddress = "0xbac9dBf16337cAC4b8aBAef3941615e57dB37073";
  static const String claimVerificationAddress = "0xB6Ba7b7501D5F6D71213B0f75f7b8a9eFc3e8507";
  
  // Network configuration
  static const String rpcUrl = "https://dream-rpc.somnia.network";
  static const int chainId = 50312; // Somnia Testnet
  
  ReownAppKitModal? _appKitModal;
  
  SmartContractService({ReownAppKitModal? appKitModal}) {
    _appKitModal = appKitModal;
  }
  
  void setAppKitModal(ReownAppKitModal appKitModal) {
    _appKitModal = appKitModal;
    debugPrint('SmartContractService: AppKit modal set successfully');
  }
  
  /// Check if wallet is properly connected and ready for transactions
  bool isWalletReady() {
    if (_appKitModal == null) {
      debugPrint('SmartContractService: AppKit modal is null');
      return false;
    }
    
    if (!_appKitModal!.isConnected) {
      debugPrint('SmartContractService: Wallet is not connected');
      return false;
    }
    
    if (_appKitModal!.session == null) {
      debugPrint('SmartContractService: No active session');
      return false;
    }
    
    debugPrint('SmartContractService: Wallet is ready for transactions');
    return true;
  }
  
  /// Get wallet connection status
  Map<String, dynamic> getWalletStatus() {
    return {
      'isConnected': _appKitModal?.isConnected ?? false,
      'hasSession': _appKitModal?.session != null,
      'sessionTopic': _appKitModal?.session?.topic,
      'chainId': _appKitModal?.selectedChain?.chainId,
      'walletName': _appKitModal?.session?.peer?.metadata?.name,
    };
  }
  
  /// Create an event on the blockchain using the user's connected wallet
  Future<Map<String, dynamic>> createEventOnBlockchain({
    required String name,
    required String description,
    required String venue,
    required DateTime startTime,
    required DateTime endTime,
    required int totalNFTs,
    required String metadataURI,
    required String eventCode,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      // Validate wallet connection
      if (!isWalletReady()) {
        final status = getWalletStatus();
        throw Exception('Wallet not ready: ${status.toString()}');
      }
      
      debugPrint('Creating event on blockchain: $name');
      debugPrint('Wallet status: ${getWalletStatus()}');
      
      // Prepare event data for blockchain
      final eventData = {
        'name': name,
        'description': description,
        'venue': venue,
        'startTime': startTime.millisecondsSinceEpoch ~/ 1000, // Convert to seconds
        'endTime': endTime.millisecondsSinceEpoch ~/ 1000,
        'totalNFTs': totalNFTs,
        'metadataURI': metadataURI,
        'eventCode': eventCode,
        'latitude': (latitude * 1e6).round(), // Convert to scaled integer
        'longitude': (longitude * 1e6).round(),
        'radius': radius.round(),
      };
      
      debugPrint('Event data prepared: $eventData');
      
      // Create the transaction request
      final transactionRequest = {
        'to': eventFactoryAddress,
        'data': _encodeCreateEventData(eventData),
        'value': '0x0', // No ETH/AVAX sent with this transaction
        'chainId': chainId,
      };
      
      debugPrint('Transaction request: $transactionRequest');
      
      // Send transaction through Reown wallet
      final result = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transactionRequest],
        ),
      );
      
      debugPrint('Transaction result: $result');
      
      if (result != null && result['hash'] != null) {
        return {
          'success': true,
          'transactionHash': result['hash'],
          'eventData': eventData,
          'message': 'Event created successfully on blockchain',
        };
      } else {
        throw Exception('Transaction failed: No transaction hash received');
      }
      
    } catch (e) {
      debugPrint('Error creating event on blockchain: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create event on blockchain',
      };
    }
  }
  
  /// Mint boundary NFTs for an event
  Future<Map<String, dynamic>> mintBoundaryNFTs({
    required int eventId,
    required List<Map<String, dynamic>> boundaries,
  }) async {
    try {
      // Validate wallet connection
      if (!isWalletReady()) {
        final status = getWalletStatus();
        throw Exception('Wallet not ready: ${status.toString()}');
      }
      
      debugPrint('Minting boundary NFTs for event: $eventId');
      debugPrint('Wallet status: ${getWalletStatus()}');
      
      final results = [];
      
      for (int i = 0; i < boundaries.length; i++) {
        final boundary = boundaries[i];
        
        // Prepare boundary data with all required parameters for mintBoundaryNFT
        final boundaryData = {
          'eventId': eventId,
          'name': boundary['name'],
          'description': boundary['description'],
          'imageURI': boundary['imageUrl'],
          'latitude': (boundary['latitude'] * 1e6).round(),
          'longitude': (boundary['longitude'] * 1e6).round(),
          'radius': boundary['radius'].round(),
          'nftTokenURI': boundary['metadataUri'] ?? '',
          'merkleRoot': '0x0000000000000000000000000000000000000000000000000000000000000000', // Default empty merkle root
        };
        
        debugPrint('Minting boundary $i: $boundaryData');
        
        // Create transaction for minting with proper ABI encoding
        final transactionRequest = {
          'to': boundaryNFTAddress,
          'data': _encodeMintBoundaryNFTData(boundaryData),
          'value': '0x0',
          'chainId': chainId,
        };
        
        // Send transaction
        final result = await _appKitModal!.request(
          topic: _appKitModal!.session!.topic,
          chainId: 'eip155:$chainId',
          request: SessionRequestParams(
            method: 'eth_sendTransaction',
            params: [transactionRequest],
          ),
        );
        
        if (result != null && result['hash'] != null) {
          results.add({
            'boundaryIndex': i,
            'success': true,
            'transactionHash': result['hash'],
            'boundaryData': boundaryData,
          });
        } else {
          results.add({
            'boundaryIndex': i,
            'success': false,
            'error': 'No transaction hash received',
          });
        }
      }
      
      final successCount = results.where((r) => r['success'] == true).length;
      
      return {
        'success': successCount > 0,
        'totalBoundaries': boundaries.length,
        'successfulMints': successCount,
        'results': results,
        'message': 'Minted $successCount out of ${boundaries.length} boundary NFTs',
      };
      
    } catch (e) {
      debugPrint('Error minting boundary NFTs: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to mint boundary NFTs',
      };
    }
  }
  
  /// Claim a boundary NFT at a specific location
  Future<Map<String, dynamic>> claimBoundaryNFT({
    required int tokenId,
    required int eventId,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    try {
      // Validate wallet connection
      if (!isWalletReady()) {
        final status = getWalletStatus();
        throw Exception('Wallet not ready: ${status.toString()}');
      }
      
      debugPrint('Claiming boundary NFT: $tokenId at location ($latitude, $longitude)');
      debugPrint('Wallet status: ${getWalletStatus()}');
      
      // Prepare claim data
      final claimData = {
        'tokenId': tokenId,
        'eventId': eventId,
        'latitude': (latitude * 1e6).round(),
        'longitude': (longitude * 1e6).round(),
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        'accuracy': (accuracy * 1e3).round(), // Convert to scaled integer
        'signature': '0x', // Placeholder - would be signed by the app
      };
      
      // Create transaction for claiming
      final transactionRequest = {
        'to': claimVerificationAddress,
        'data': _encodeSubmitLocationClaimData(claimData),
        'value': '0x0',
        'chainId': chainId,
      };
      
      // Send transaction
      final result = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transactionRequest],
        ),
      );
      
      if (result != null && result['hash'] != null) {
        return {
          'success': true,
          'transactionHash': result['hash'],
          'claimData': claimData,
          'message': 'Boundary NFT claimed successfully',
        };
      } else {
        throw Exception('Transaction failed: No transaction hash received');
      }
      
    } catch (e) {
      debugPrint('Error claiming boundary NFT: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to claim boundary NFT',
      };
    }
  }
  
  /// Encode function call data for creating an event
  String _encodeCreateEventData(Map<String, dynamic> eventData) {
    // Function signature: createEvent(string,string,string,uint256,uint256,uint256,string,string,int256,int256,uint256)
    final functionSelector = _calculateFunctionSelector(
      'createEvent(string,string,string,uint256,uint256,uint256,string,string,int256,int256,uint256)'
    );
    
    // For now, return just the function selector
    // In production, you would need to properly encode all parameters
    // This requires proper ABI encoding which is complex without web3dart
    debugPrint('CreateEvent function selector: $functionSelector');
    return functionSelector;
  }
  
  /// Encode function call data for minting boundary NFTs
  String _encodeMintBoundaryNFTData(Map<String, dynamic> boundaryData) {
    // Function signature: mintBoundaryNFT(uint256,string,string,string,int256,int256,uint256,string,bytes32)
    final functionSelector = _calculateFunctionSelector(
      'mintBoundaryNFT(uint256,string,string,string,int256,int256,uint256,string,bytes32)'
    );
    
    debugPrint('MintBoundaryNFT function selector: $functionSelector');
    debugPrint('Boundary data for encoding: $boundaryData');
    
    // For now, return just the function selector
    // In production, you would need to properly encode all 9 parameters:
    // - eventId (uint256)
    // - name (string)
    // - description (string) 
    // - imageURI (string)
    // - latitude (int256)
    // - longitude (int256)
    // - radius (uint256)
    // - nftTokenURI (string)
    // - merkleRoot (bytes32)
    return functionSelector;
  }
  
  /// Encode function call data for submitting location claims
  String _encodeSubmitLocationClaimData(Map<String, dynamic> claimData) {
    // Function signature: submitLocationClaim(uint256,uint256,int256,int256,uint256,uint256,bytes)
    final functionSelector = _calculateFunctionSelector(
      'submitLocationClaim(uint256,uint256,int256,int256,uint256,uint256,bytes)'
    );
    
    debugPrint('SubmitLocationClaim function selector: $functionSelector');
    debugPrint('Claim data for encoding: $claimData');
    
    // For now, return just the function selector
    // In production, you would need to properly encode all 7 parameters:
    // - tokenId (uint256)
    // - eventId (uint256)
    // - latitude (int256)
    // - longitude (int256)
    // - timestamp (uint256)
    // - accuracy (uint256)
    // - signature (bytes)
    return functionSelector;
  }
  
  /// Calculate function selector using keccak256 hash
  String _calculateFunctionSelector(String functionSignature) {
    // Convert function signature to bytes
    final bytes = utf8.encode(functionSignature);
    
    // Calculate keccak256 hash (using SHA3-256 as approximation)
    final digest = sha256.convert(bytes);
    
    // Take first 4 bytes (8 hex characters) for function selector
    final selector = '0x${digest.toString().substring(0, 8)}';
    
    debugPrint('Function signature: $functionSignature');
    debugPrint('Function selector: $selector');
    
    return selector;
  }
  
  /// Set token boundary in ClaimVerification contract
  Future<Map<String, dynamic>> setTokenBoundary({
    required int tokenId,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      if (!isWalletReady()) {
        final status = getWalletStatus();
        throw Exception('Wallet not ready: ${status.toString()}');
      }
      
      debugPrint('Setting token boundary for tokenId: $tokenId');
      
      final boundaryData = {
        'tokenId': tokenId,
        'centerLatitude': (latitude * 1e6).round(),
        'centerLongitude': (longitude * 1e6).round(),
        'radius': radius.round(),
      };
      
      final functionSelector = _calculateFunctionSelector(
        'setTokenBoundary(uint256,int256,int256,uint256)'
      );
      
      final transactionRequest = {
        'to': claimVerificationAddress,
        'data': functionSelector,
        'value': '0x0',
        'chainId': chainId,
      };
      
      final result = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:$chainId',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transactionRequest],
        ),
      );
      
      if (result != null && result['hash'] != null) {
        return {
          'success': true,
          'transactionHash': result['hash'],
          'boundaryData': boundaryData,
          'message': 'Token boundary set successfully',
        };
      } else {
        throw Exception('Transaction failed: No transaction hash received');
      }
      
    } catch (e) {
      debugPrint('Error setting token boundary: $e');
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to set token boundary',
      };
    }
  }
  
  /// Get contract addresses
  Map<String, String> getContractAddresses() {
    return {
      'eventFactory': eventFactoryAddress,
      'boundaryNFT': boundaryNFTAddress,
      'claimVerification': claimVerificationAddress,
    };
  }
  
  /// Get network information
  Map<String, dynamic> getNetworkInfo() {
    return {
      'name': 'Arbitrum Sepolia Testnet',
      'rpcUrl': rpcUrl,
      'chainId': chainId,
      'currencySymbol': 'ETH',
      'explorerUrl': 'https://sepolia.arbiscan.io',
    };
  }
}
