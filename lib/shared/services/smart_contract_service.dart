import 'package:flutter/foundation.dart';
import 'package:reown_appkit/reown_appkit.dart';

class SmartContractService {
  // Contract addresses on Avalanche Fuji Testnet
  static const String eventFactoryAddress = "0x3F8e16eC5a7E23Fd43b017f2C122e7042b4964E5";
  static const String boundaryNFTAddress = "0x3cD6A8f379100235D2c008D20307585bEBb5F5c7";
  static const String claimVerificationAddress = "0x5d4a20e22a730F6A56EeC09ae9245a4f8ef6e442";
  
  // Network configuration
  static const String rpcUrl = "https://api.avax-test.network/ext/bc/C/rpc";
  static const int chainId = 43113; // Fuji Testnet
  
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
        
        // Prepare boundary data
        final boundaryData = {
          'eventId': eventId,
          'name': boundary['name'],
          'description': boundary['description'],
          'imageURI': boundary['imageUrl'],
          'latitude': (boundary['latitude'] * 1e6).round(),
          'longitude': (boundary['longitude'] * 1e6).round(),
          'radius': boundary['radius'].round(),
        };
        
        debugPrint('Minting boundary $i: $boundaryData');
        
        // Create transaction for minting
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
    // This is a simplified encoding - in production you'd use proper ABI encoding
    // For now, returning a placeholder that indicates the function signature
    final functionSignature = 'createEvent(string,string,string,uint256,uint256,uint256,string,string,int256,int256,uint256)';
    final functionSelector = _getFunctionSelector(functionSignature);
    
    // In a real implementation, you'd encode the parameters properly
    // For now, returning the function selector
    return functionSelector;
  }
  
  /// Encode function call data for minting boundary NFTs
  String _encodeMintBoundaryNFTData(Map<String, dynamic> boundaryData) {
    final functionSignature = 'mintBoundaryNFT(uint256,string,string,string,int256,int256,uint256)';
    final functionSelector = _getFunctionSelector(functionSignature);
    
    return functionSelector;
  }
  
  /// Encode function call data for submitting location claims
  String _encodeSubmitLocationClaimData(Map<String, dynamic> claimData) {
    final functionSignature = 'submitLocationClaim(uint256,uint256,int256,int256,uint256,uint256,bytes)';
    final functionSelector = _getFunctionSelector(functionSignature);
    
    return functionSelector;
  }
  
  /// Get function selector (first 4 bytes of function signature hash)
  String _getFunctionSelector(String functionSignature) {
    // This is a simplified implementation
    // In production, you'd use proper keccak256 hashing
    return '0x' + functionSignature.substring(0, 8);
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
      'name': 'Avalanche Fuji Testnet',
      'rpcUrl': rpcUrl,
      'chainId': chainId,
      'currencySymbol': 'AVAX',
      'explorerUrl': 'https://testnet.snowtrace.io',
    };
  }
}
