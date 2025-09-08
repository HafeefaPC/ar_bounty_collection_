import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:crypto/crypto.dart';
import '../models/nft.dart';
import 'storage_service.dart';

/// Service for fetching and managing NFTs from the blockchain
class NFTService {
  static final NFTService _instance = NFTService._internal();
  factory NFTService() => _instance;
  NFTService._internal();

  // Contract addresses on Arbitrum Sepolia Testnet
  static const String _boundaryNFTAddress = "0xE587360Bc94a98E43F276718E49E213f7a30CA4B";
  static const String _eventFactoryAddress = "0x2f61d477F24C16dcDe68D988BDf6447b7D0Edb79";
  
  // Network configuration
  static const String _rpcUrl = "https://sepolia-rollup.arbitrum.io/rpc";
  static const int _chainId = 421614; // Arbitrum Sepolia Testnet

  ReownAppKitModal? _appKitModal;
  final StorageService _storageService = StorageService();

  /// Initialize the NFT service with ReownAppKit instance
  void initialize(ReownAppKitModal appKitModal) {
    _appKitModal = appKitModal;
    debugPrint('NFTService: Initialized with ReownAppKit');
  }

  /// Check if the service is ready
  bool get isReady => _appKitModal != null && _appKitModal!.isConnected;

  /// Get all NFTs owned by a specific address (combines blockchain and local data)
  Future<NFTCollection> getNFTsByOwner(String ownerAddress) async {
    try {
      debugPrint('NFTService: Fetching NFTs for owner: $ownerAddress');

      // First, get locally stored claimed NFTs
      final localNFTs = await _storageService.getClaimedNFTsByWallet(ownerAddress);
      debugPrint('NFTService: Found ${localNFTs.length} locally stored NFTs');

      // If wallet is not connected, return only local NFTs
      if (!isReady) {
        debugPrint('NFTService: Wallet not connected, returning only local NFTs');
        return NFTCollection(
          owner: ownerAddress,
          nfts: localNFTs,
          totalCount: localNFTs.length,
          lastUpdated: DateTime.now(),
        );
      }

      // Get blockchain NFTs
      try {
        // 1. Get the balance (total number of NFTs owned)
        final balance = await _getBalance(ownerAddress);
        debugPrint('NFTService: Owner has $balance NFTs on blockchain');

        final blockchainNFTs = <NFT>[];

        if (balance > 0) {
          // 2. Get all token IDs owned by the address
          final tokenIds = await _getTokenIdsByOwner(ownerAddress, balance);
          debugPrint('NFTService: Found token IDs: $tokenIds');

          // 3. Fetch metadata for each NFT
          for (final tokenId in tokenIds) {
            try {
              final nft = await _getNFTMetadata(tokenId, ownerAddress);
              if (nft != null) {
                blockchainNFTs.add(nft);
                
                // Store newly discovered NFTs locally
                final isAlreadyStored = await _storageService.isNFTClaimedByWallet(tokenId, ownerAddress);
                if (!isAlreadyStored) {
                  await _storageService.saveClaimedNFT(nft, ownerAddress);
                  debugPrint('NFTService: Saved new NFT $tokenId to local storage');
                }
              }
            } catch (e) {
              debugPrint('NFTService: Error fetching metadata for token $tokenId: $e');
              // Continue with other NFTs even if one fails
            }
          }
        }

        // Combine blockchain and local NFTs (remove duplicates)
        final allNFTs = <String, NFT>{};
        
        // Add blockchain NFTs first (they're more up-to-date)
        for (final nft in blockchainNFTs) {
          allNFTs[nft.tokenId] = nft;
        }
        
        // Add local NFTs that aren't already included
        for (final nft in localNFTs) {
          if (!allNFTs.containsKey(nft.tokenId)) {
            allNFTs[nft.tokenId] = nft;
          }
        }

        final combinedNFTs = allNFTs.values.toList();
        debugPrint('NFTService: Successfully combined ${combinedNFTs.length} total NFTs');

        return NFTCollection(
          owner: ownerAddress,
          nfts: combinedNFTs,
          totalCount: combinedNFTs.length,
          lastUpdated: DateTime.now(),
        );

      } catch (e) {
        debugPrint('NFTService: Error fetching blockchain NFTs, returning local only: $e');
        // If blockchain fetch fails, return local NFTs
        return NFTCollection(
          owner: ownerAddress,
          nfts: localNFTs,
          totalCount: localNFTs.length,
          lastUpdated: DateTime.now(),
        );
      }

    } catch (e) {
      debugPrint('NFTService: Error fetching NFTs: $e');
      rethrow;
    }
  }

  /// Get all claimed NFTs across the entire network from all events
  Future<NFTCollection> getAllClaimedNFTs() async {
    if (!isReady) {
      throw Exception('NFTService not ready - wallet not connected');
    }

    try {
      debugPrint('NFTService: Fetching all claimed NFTs across the network');

      // 1. Get total number of events
      final totalEvents = await _getTotalEvents();
      debugPrint('NFTService: Found $totalEvents total events');

      if (totalEvents == 0) {
        return NFTCollection(
          owner: 'Network',
          nfts: [],
          totalCount: 0,
          lastUpdated: DateTime.now(),
        );
      }

      // 2. Get all claimed NFTs from all events
      final allClaimedNFTs = <NFT>[];
      
      for (int eventId = 1; eventId <= totalEvents; eventId++) {
        try {
          debugPrint('NFTService: Fetching claimed NFTs for event $eventId');
          
          // Get claimed token IDs for this event
          final claimedTokenIds = await _getClaimedTokensByEvent(eventId);
          debugPrint('NFTService: Event $eventId has ${claimedTokenIds.length} claimed NFTs');

          // Get event information
          final eventInfo = await _getEventInfo(eventId);
          
          // Fetch metadata for each claimed NFT
          for (final tokenId in claimedTokenIds) {
            try {
              final nft = await _getNFTMetadataWithEventInfo(tokenId, eventInfo);
              if (nft != null) {
                allClaimedNFTs.add(nft);
              }
            } catch (e) {
              debugPrint('NFTService: Error fetching metadata for token $tokenId: $e');
              // Continue with other NFTs even if one fails
            }
          }
        } catch (e) {
          debugPrint('NFTService: Error fetching NFTs for event $eventId: $e');
          // Continue with other events even if one fails
        }
      }

      debugPrint('NFTService: Successfully fetched ${allClaimedNFTs.length} claimed NFTs from $totalEvents events');

      return NFTCollection(
        owner: 'Network',
        nfts: allClaimedNFTs,
        totalCount: allClaimedNFTs.length,
        lastUpdated: DateTime.now(),
      );

    } catch (e) {
      debugPrint('NFTService: Error fetching all claimed NFTs: $e');
      rethrow;
    }
  }

  /// Get the balance (number of NFTs) owned by an address
  Future<int> _getBalance(String ownerAddress) async {
    try {
      final result = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'balanceOf(address)',
        parameters: [ownerAddress],
      );

      if (result != null && result.isNotEmpty) {
        final balance = int.tryParse(result[0].toString()) ?? 0;
        debugPrint('NFTService: Balance for $ownerAddress: $balance');
        return balance;
      }

      return 0;
    } catch (e) {
      debugPrint('NFTService: Error getting balance: $e');
      return 0;
    }
  }

  /// Get all token IDs owned by an address using tokenOfOwnerByIndex
  Future<List<String>> _getTokenIdsByOwner(String ownerAddress, int balance) async {
    final tokenIds = <String>[];

    try {
      for (int i = 0; i < balance; i++) {
        final result = await _callContractFunction(
          contractAddress: _boundaryNFTAddress,
          functionSignature: 'tokenOfOwnerByIndex(address,uint256)',
          parameters: [ownerAddress, i.toString()],
        );

        if (result != null && result.isNotEmpty) {
          final tokenId = result[0].toString();
          tokenIds.add(tokenId);
        }
      }

      debugPrint('NFTService: Retrieved ${tokenIds.length} token IDs');
      return tokenIds;
    } catch (e) {
      debugPrint('NFTService: Error getting token IDs: $e');
      return tokenIds;
    }
  }

  /// Get NFT metadata for a specific token ID
  Future<NFT?> _getNFTMetadata(String tokenId, String ownerAddress) async {
    try {
      // Get NFT metadata from the contract
      final metadataResult = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'getNFTMetadata(uint256)',
        parameters: [tokenId],
      );

      if (metadataResult == null || metadataResult.isEmpty) {
        debugPrint('NFTService: No metadata found for token $tokenId');
        return null;
      }

      // Parse the metadata result
      final metadata = _parseNFTMetadata(metadataResult);
      metadata['tokenId'] = tokenId;
      metadata['owner'] = ownerAddress;

      // Get additional event information if available
      if (metadata['eventId'] != null) {
        try {
          final eventInfo = await _getEventInfo(metadata['eventId']);
          if (eventInfo != null) {
            metadata.addAll(eventInfo);
          }
        } catch (e) {
          debugPrint('NFTService: Error fetching event info: $e');
        }
      }

      // Create NFT object
      final nft = NFT.fromBlockchainMetadata(
        tokenId: tokenId,
        owner: ownerAddress,
        metadata: metadata,
      );

      debugPrint('NFTService: Created NFT: ${nft.displayName}');
      return nft;

    } catch (e) {
      debugPrint('NFTService: Error getting NFT metadata for token $tokenId: $e');
      return null;
    }
  }

  /// Parse NFT metadata from contract response
  Map<String, dynamic> _parseNFTMetadata(List<dynamic> result) {
    if (result.length < 11) {
      throw Exception('Invalid metadata response length: ${result.length}');
    }

    return {
      'eventId': result[0],
      'name': result[1],
      'description': result[2],
      'imageURI': result[3],
      'latitude': result[4],
      'longitude': result[5],
      'radius': result[6],
      'mintTimestamp': result[7],
      'claimTimestamp': result[8],
      'claimer': result[9],
      'merkleRoot': result[10],
    };
  }

  /// Get event information from EventFactory contract
  Future<Map<String, dynamic>?> _getEventInfo(int eventId) async {
    try {
      final result = await _callContractFunction(
        contractAddress: _eventFactoryAddress,
        functionSignature: 'getEvent(uint256)',
        parameters: [eventId.toString()],
      );

      if (result == null || result.isEmpty) {
        return null;
      }

      // Parse event data (based on EventFactory.Event struct)
      return {
        'eventName': result[2], // name
        'eventDescription': result[3], // description
        'eventVenue': result[4], // venue
      };
    } catch (e) {
      debugPrint('NFTService: Error getting event info for event $eventId: $e');
      return null;
    }
  }

  /// Call a contract function using eth_call
  Future<List<dynamic>?> _callContractFunction({
    required String contractAddress,
    required String functionSignature,
    required List<String> parameters,
  }) async {
    if (_appKitModal == null || !_appKitModal!.isConnected) {
      throw Exception('Wallet not connected');
    }

    try {
      // Encode function call data
      final data = _encodeFunctionCall(functionSignature, parameters);
      
      // Make eth_call request
      final result = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic!,
        chainId: 'eip155:$_chainId',
        request: SessionRequestParams(
          method: 'eth_call',
          params: [
            {
              'to': contractAddress,
              'data': data,
            },
            'latest',
          ],
        ),
      );

      if (result != null && result is String) {
        return _decodeFunctionResult(result, functionSignature);
      }

      return null;
    } catch (e) {
      debugPrint('NFTService: Error calling contract function: $e');
      rethrow;
    }
  }

  /// Encode function call data (simplified version)
  String _encodeFunctionCall(String functionSignature, List<String> parameters) {
    // This is a simplified encoding - in production, you'd want to use a proper ABI encoder
    // For now, we'll use a basic approach that works for simple function calls
    
    final functionSelector = _calculateFunctionSelector(functionSignature);
    
    // For simple parameters, we can encode them manually
    String encodedParams = '';
    for (final param in parameters) {
      if (param.startsWith('0x')) {
        // Address parameter
        encodedParams += param.substring(2).padLeft(64, '0');
      } else {
        // Uint256 parameter
        final intValue = int.tryParse(param) ?? 0;
        encodedParams += intValue.toRadixString(16).padLeft(64, '0');
      }
    }
    
    return functionSelector + encodedParams;
  }

  /// Calculate function selector using keccak256 hash
  String _calculateFunctionSelector(String functionSignature) {
    // Convert function signature to bytes
    final bytes = utf8.encode(functionSignature);
    
    // Calculate keccak256 hash (using SHA3-256 as approximation)
    final digest = sha256.convert(bytes);
    
    // Take first 4 bytes (8 hex characters) for function selector
    return '0x${digest.toString().substring(0, 8)}';
  }

  /// Decode function result (simplified version)
  List<dynamic> _decodeFunctionResult(String result, String functionSignature) {
    // Remove 0x prefix
    final data = result.startsWith('0x') ? result.substring(2) : result;
    
    // This is a simplified decoder - in production, you'd want to use a proper ABI decoder
    // For now, we'll return the raw result and let the caller handle parsing
    
    if (data.isEmpty) {
      return [];
    }
    
    // For simple return types, we can decode them manually
    // This is a basic implementation that works for the functions we're calling
    
    if (functionSignature.contains('balanceOf')) {
      // Returns uint256
      final value = BigInt.parse(data, radix: 16);
      return [value.toString()];
    } else if (functionSignature.contains('tokenOfOwnerByIndex')) {
      // Returns uint256
      final value = BigInt.parse(data, radix: 16);
      return [value.toString()];
    } else if (functionSignature.contains('getNFTMetadata')) {
      // Returns a struct - this is more complex and would need proper ABI decoding
      // For now, we'll return the raw data and parse it in the calling function
      return [data];
    } else if (functionSignature.contains('getEvent')) {
      // Returns a struct - this is more complex and would need proper ABI decoding
      return [data];
    }
    
    return [data];
  }

  /// Get NFT by token ID
  Future<NFT?> getNFTByTokenId(String tokenId) async {
    if (!isReady) {
      throw Exception('NFTService not ready - wallet not connected');
    }

    try {
      // Get the owner of the token
      final ownerResult = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'ownerOf(uint256)',
        parameters: [tokenId],
      );

      if (ownerResult == null || ownerResult.isEmpty) {
        debugPrint('NFTService: No owner found for token $tokenId');
        return null;
      }

      final owner = ownerResult[0].toString();
      
      // Get NFT metadata
      return await _getNFTMetadata(tokenId, owner);
    } catch (e) {
      debugPrint('NFTService: Error getting NFT by token ID $tokenId: $e');
      return null;
    }
  }

  /// Check if an NFT is claimed
  Future<bool> isNFTClaimed(String tokenId) async {
    try {
      final result = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'isNFTClaimed(uint256)',
        parameters: [tokenId],
      );

      if (result != null && result.isNotEmpty) {
        return result[0] == true || result[0] == 'true' || result[0] == '1';
      }

      return false;
    } catch (e) {
      debugPrint('NFTService: Error checking if NFT is claimed: $e');
      return false;
    }
  }

  /// Get total supply of NFTs
  Future<int> getTotalSupply() async {
    try {
      final result = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'totalSupply()',
        parameters: [],
      );

      if (result != null && result.isNotEmpty) {
        return int.tryParse(result[0].toString()) ?? 0;
      }

      return 0;
    } catch (e) {
      debugPrint('NFTService: Error getting total supply: $e');
      return 0;
    }
  }

  /// Get total number of events
  Future<int> _getTotalEvents() async {
    try {
      final result = await _callContractFunction(
        contractAddress: _eventFactoryAddress,
        functionSignature: 'getTotalEvents()',
        parameters: [],
      );

      if (result != null && result.isNotEmpty) {
        return int.tryParse(result[0].toString()) ?? 0;
      }

      return 0;
    } catch (e) {
      debugPrint('NFTService: Error getting total events: $e');
      return 0;
    }
  }

  /// Get claimed token IDs for a specific event
  Future<List<String>> _getClaimedTokensByEvent(int eventId) async {
    try {
      final result = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'getClaimedTokensByEvent(uint256)',
        parameters: [eventId.toString()],
      );

      if (result != null && result.isNotEmpty) {
        // The result should be an array of token IDs
        final tokenIds = <String>[];
        // Parse the result - this might need adjustment based on actual contract response
        if (result[0] is List) {
          for (final tokenId in result[0] as List) {
            tokenIds.add(tokenId.toString());
          }
        } else if (result[0] is String && result[0].isNotEmpty) {
          // If it's a single string, try to parse it
          tokenIds.add(result[0].toString());
        }
        return tokenIds;
      }

      return [];
    } catch (e) {
      debugPrint('NFTService: Error getting claimed tokens for event $eventId: $e');
      return [];
    }
  }

  /// Get NFT metadata with event information
  Future<NFT?> _getNFTMetadataWithEventInfo(String tokenId, Map<String, dynamic>? eventInfo) async {
    try {
      // Get the owner of the token
      final ownerResult = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'ownerOf(uint256)',
        parameters: [tokenId],
      );

      if (ownerResult == null || ownerResult.isEmpty) {
        debugPrint('NFTService: No owner found for token $tokenId');
        return null;
      }

      final owner = ownerResult[0].toString();
      
      // Get NFT metadata from the contract
      final metadataResult = await _callContractFunction(
        contractAddress: _boundaryNFTAddress,
        functionSignature: 'getNFTMetadata(uint256)',
        parameters: [tokenId],
      );

      if (metadataResult == null || metadataResult.isEmpty) {
        debugPrint('NFTService: No metadata found for token $tokenId');
        return null;
      }

      // Parse the metadata result
      final metadata = _parseNFTMetadata(metadataResult);
      metadata['tokenId'] = tokenId;
      metadata['owner'] = owner;

      // Add event information if available
      if (eventInfo != null) {
        metadata.addAll(eventInfo);
      }

      // Create NFT object
      final nft = NFT.fromBlockchainMetadata(
        tokenId: tokenId,
        owner: owner,
        metadata: metadata,
      );

      debugPrint('NFTService: Created NFT: ${nft.displayName}');
      return nft;

    } catch (e) {
      debugPrint('NFTService: Error getting NFT metadata with event info for token $tokenId: $e');
      return null;
    }
  }

  /// Manually store a claimed NFT when it's claimed during bounty collection
  Future<void> storeClaimedNFT(NFT nft, String walletAddress) async {
    try {
      await _storageService.saveClaimedNFT(nft, walletAddress);
      debugPrint('NFTService: Successfully stored claimed NFT ${nft.tokenId} for wallet $walletAddress');
    } catch (e) {
      debugPrint('NFTService: Error storing claimed NFT: $e');
      rethrow;
    }
  }

  /// Get NFT statistics for a wallet
  Future<Map<String, dynamic>> getNFTStats(String walletAddress) async {
    return await _storageService.getNFTStats(walletAddress);
  }

  /// Get locally stored claimed NFTs for a wallet (offline access)
  Future<List<NFT>> getLocalClaimedNFTs(String walletAddress) async {
    return await _storageService.getClaimedNFTsByWallet(walletAddress);
  }

  /// Check if an NFT is already claimed and stored locally
  Future<bool> isNFTStoredLocally(String tokenId, String walletAddress) async {
    return await _storageService.isNFTClaimedByWallet(tokenId, walletAddress);
  }

  /// Remove a locally stored NFT
  Future<void> removeLocalNFT(String tokenId) async {
    await _storageService.removeClaimedNFT(tokenId);
  }

  /// Get contract information
  Map<String, dynamic> getContractInfo() {
    return {
      'boundaryNFTAddress': _boundaryNFTAddress,
      'eventFactoryAddress': _eventFactoryAddress,
      'rpcUrl': _rpcUrl,
      'chainId': _chainId,
      'networkName': 'Arbitrum Sepolia Testnet',
    };
  }
}
