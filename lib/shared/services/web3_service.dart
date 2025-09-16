import 'dart:convert';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class Web3Service {
  static const String _somniaTestnetRpcUrl = 'https://dream-rpc.somnia.network';
  static const int _chainId = 50312;
  
  late Web3Client _client;
  late EthereumAddress _eventFactoryAddress;
  late EthereumAddress _boundaryNFTAddress;
  late EthereumAddress _claimVerificationAddress;
  
  late DeployedContract _eventFactoryContract;
  late DeployedContract _boundaryNFTContract;
  late DeployedContract _claimVerificationContract;
  
  Web3Service() {
    _client = Web3Client(_somniaTestnetRpcUrl, http.Client());
    _loadContractAddresses();
  }
  
  void _loadContractAddresses() {
    // Load contract addresses from Somnia Testnet deployment
    _eventFactoryAddress = EthereumAddress.fromHex('0xf9CF13b978A71113992De2A0373fE76d3B64B6dc');
    _boundaryNFTAddress = EthereumAddress.fromHex('0xbac9dBf16337cAC4b8aBAef3941615e57dB37073');
    _claimVerificationAddress = EthereumAddress.fromHex('0xB6Ba7b7501D5F6D71213B0f75f7b8a9eFc3e8507');
    
    print('✅ Web3Service: Loaded Somnia Testnet contract addresses:');
    print('  - EventFactory: ${_eventFactoryAddress.hex}');
    print('  - BoundaryNFT: ${_boundaryNFTAddress.hex}');
    print('  - ClaimVerification: ${_claimVerificationAddress.hex}');
  }
  
  Future<void> initializeContracts() async {
    try {
      // Load EventFactory ABI
      final eventFactoryAbiJson = await rootBundle.loadString('lib/shared/contracts/abis/EventFactory.json');
      final eventFactoryAbi = jsonDecode(eventFactoryAbiJson) as List<dynamic>;
      _eventFactoryContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(eventFactoryAbi), 'EventFactory'),
        _eventFactoryAddress,
      );
      
      // Load BoundaryNFT ABI
      final boundaryNFTAbiJson = await rootBundle.loadString('lib/shared/contracts/abis/BoundaryNFT.json');
      final boundaryNFTAbi = jsonDecode(boundaryNFTAbiJson) as List<dynamic>;
      _boundaryNFTContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(boundaryNFTAbi), 'BoundaryNFT'),
        _boundaryNFTAddress,
      );
      
      // Load ClaimVerification ABI
      final claimVerificationAbiJson = await rootBundle.loadString('lib/shared/contracts/abis/ClaimVerification.json');
      final claimVerificationAbi = jsonDecode(claimVerificationAbiJson) as List<dynamic>;
      _claimVerificationContract = DeployedContract(
        ContractAbi.fromJson(jsonEncode(claimVerificationAbi), 'ClaimVerification'),
        _claimVerificationAddress,
      );
      
      print('✅ Web3Service: All contracts initialized successfully');
    } catch (e) {
      print('❌ Web3Service: Error initializing contracts: $e');
      rethrow;
    }
  }
  
  // Get the current chain ID
  int get chainId => _chainId;
  
  // Get the RPC URL
  String get rpcUrl => _somniaTestnetRpcUrl;
  
  // Get contract addresses
  EthereumAddress get eventFactoryAddress => _eventFactoryAddress;
  EthereumAddress get boundaryNFTAddress => _boundaryNFTAddress;
  EthereumAddress get claimVerificationAddress => _claimVerificationAddress;
  
  // Create event function using ReownAppKit
  Future<String> createEvent({
    required String eventName,
    required String eventDescription,
    required String organizerWallet,
    required int latitude,
    required int longitude,
    required String venueName,
    required int nftSupplyCount,
    required String eventImageUrl,
    required String eventCode,
    required int startTime,
    required int endTime,
    required int radius,
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🚀 Web3Service: Creating event on blockchain...');
      print('📝 Event Details:');
      print('  - Event Name: "$eventName" (length: ${eventName.length})');
      print('  - Description: "$eventDescription" (length: ${eventDescription.length})');
      print('  - Venue: "$venueName" (length: ${venueName.length})');
      print('  - Organizer: $organizerWallet');
      print('  - Start Time: $startTime (${DateTime.fromMillisecondsSinceEpoch(startTime * 1000)})');
      print('  - End Time: $endTime (${DateTime.fromMillisecondsSinceEpoch(endTime * 1000)})');
      print('  - NFT Supply: $nftSupplyCount');
      print('  - Metadata URI: "$eventImageUrl" (length: ${eventImageUrl.length})');
      print('  - Event Code: "$eventCode" (length: ${eventCode.length})');
      print('  - Latitude: $latitude (scaled: ${BigInt.from(latitude)})');
      print('  - Longitude: $longitude (scaled: ${BigInt.from(longitude)})');
      print('  - Radius: $radius meters');
      
      // Validate parameters before sending transaction
      if (eventName.isEmpty) throw Exception('Event name cannot be empty');
      if (eventDescription.isEmpty) throw Exception('Event description cannot be empty');
      if (venueName.isEmpty) throw Exception('Venue name cannot be empty');
      if (eventCode.isEmpty) throw Exception('Event code cannot be empty');
      if (eventImageUrl.isEmpty) throw Exception('Event image URL cannot be empty');
      if (nftSupplyCount <= 0) throw Exception('NFT supply count must be positive');
      if (radius <= 0) throw Exception('Radius must be positive');
      if (startTime <= 0) throw Exception('Start time must be positive');
      if (endTime <= startTime) throw Exception('End time must be after start time');
      
      print('✅ Parameter validation passed');
      
      // Get the createEvent function from the contract
      final createEventFunction = _eventFactoryContract.function('createEvent');
      print('📜 Contract function: ${createEventFunction.name}');
      print('📜 Function inputs: ${createEventFunction.parameters.map((i) => '${i.name} (${i.type})').join(', ')}');
      
      // Prepare the transaction parameters (exact order per ABI)
      final parameters = [
        eventName,                  // 1. string name
        eventDescription,           // 2. string description  
        venueName,                 // 3. string venue
        BigInt.from(startTime),    // 4. uint256 startTime
        BigInt.from(endTime),      // 5. uint256 endTime
        BigInt.from(nftSupplyCount), // 6. uint256 totalNFTs
        eventImageUrl,             // 7. string metadataURI
        eventCode,                 // 8. string eventCode
        BigInt.from(latitude),     // 9. int256 latitude (can be negative)
        BigInt.from(longitude),    // 10. int256 longitude (can be negative)
        BigInt.from(radius),       // 11. uint256 radius
      ];
      
      print('📋 Function parameters (${parameters.length} total):');
      for (int i = 0; i < parameters.length; i++) {
        final param = parameters[i];
        final paramType = param.runtimeType;
        print('  [$i] $paramType: $param');
      }
      
      // Create the transaction
      final transaction = Transaction.callContract(
        contract: _eventFactoryContract,
        function: createEventFunction,
        parameters: parameters,
      );
      
      print('📋 Raw transaction data: ${transaction.data}');
      print('📋 Transaction data length: ${transaction.data?.length ?? 0}');
      
      if (transaction.data == null || transaction.data!.isEmpty) {
        throw Exception('Failed to encode transaction data - empty result');
      }
      
      // Convert transaction data to proper hex string
      final hexData = '0x${transaction.data!.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📋 Transaction data as hex: $hexData');
      print('📋 Hex data length: ${hexData.length} characters');
      
      // Validate hex data
      if (hexData.length < 10) { // Function selector (4 bytes) + some data
        throw Exception('Transaction data too short - likely encoding error');
      }
      
      // Extract and verify function selector
      final functionSelector = hexData.substring(0, 10); // 0x + 8 hex chars = 10 chars
      print('📋 Function selector: $functionSelector');
      
      print('🔗 Sending transaction to wallet for signing...');
      
      // Use the signTransaction function to sign and send the transaction
      final txHash = await signTransaction(
        _eventFactoryAddress.hex,
        [hexData],
      );
      
      print('✅ Web3Service: Event creation transaction sent successfully');
      print('📝 Transaction Hash: $txHash');
      print('🔗 View on explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error creating event: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Enhanced error information
      if (e.toString().contains('revert')) {
        print('❌ Transaction reverted on blockchain - check contract requirements');
        print('❌ Possible causes:');
        print('   - Missing ORGANIZER_ROLE permission');
        print('   - Invalid parameter values');
        print('   - Contract logic failure');
        print('   - Insufficient gas limit');
      } else if (e.toString().contains('encoding')) {
        print('❌ Parameter encoding error - check data types');
      } else if (e.toString().contains('insufficient')) {
        print('❌ Insufficient funds for gas fees');
      }
      
      rethrow;
    }
  }
  
  // Get event details
  Future<Map<String, dynamic>> getEventDetails(int eventId) async {
    try {
      final getEventFunction = _eventFactoryContract.function('getEvent');
      final result = await _client.call(
        contract: _eventFactoryContract,
        function: getEventFunction,
        params: [BigInt.from(eventId)],
      );
      
      return {
        'eventId': result[0].toString(),
        'name': result[1].toString(),
        'description': result[2].toString(),
        'organizer': result[3].toString(),
        'latitude': result[4].toString(),
        'longitude': result[5].toString(),
        'venueName': result[6].toString(),
        'nftSupplyCount': result[7].toString(),
        'eventImageUrl': result[8].toString(),
        'isActive': result[9] as bool,
        'createdAt': result[10].toString(),
      };
    } catch (e) {
      print('❌ Web3Service: Error getting event details: $e');
      rethrow;
    }
  }
  
  // Check if event code already exists
  Future<bool> eventCodeExists(String eventCode) async {
    try {
      print('🔍 Checking if event code exists: $eventCode');
      
      // Call the eventCodeToId mapping directly
      final result = await _client.call(
        contract: _eventFactoryContract,
        function: _eventFactoryContract.function('eventCodeToId'),
        params: [eventCode],
      );
      
      final eventId = result.first as BigInt;
      final exists = eventId > BigInt.zero;
      
      print('🔍 Event code "$eventCode" exists: $exists (ID: $eventId)');
      return exists;
    } catch (e) {
      print('❌ Error checking event code existence: $e');
      // If there's an error, assume it doesn't exist to allow creation
      return false;
    }
  }

  // Get total events count
  Future<int> getTotalEventsCount() async {
    try {
      final totalEventsFunction = _eventFactoryContract.function('getTotalEvents');
      final result = await _client.call(
        contract: _eventFactoryContract,
        function: totalEventsFunction,
        params: [],
      );
      
      return (result[0] as BigInt).toInt();
    } catch (e) {
      print('❌ Web3Service: Error getting total events count: $e');
      rethrow;
    }
  }

  // Test method to send a simple transaction to verify wallet connection
  Future<String> testSimpleTransaction({
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🧪 Web3Service: Testing simple transaction...');
      
      // Create a simple transaction that just sends 0 ETH to the contract
      // This should trigger the wallet approval dialog
      final txHash = await signTransaction(
        _eventFactoryAddress.hex,
        ['0x'], // Empty data - just a simple transfer
      );
      
      print('✅ Web3Service: Simple transaction sent: $txHash');
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error in simple transaction: $e');
      rethrow;
    }
  }
  
  // Get events by organizer
  Future<List<int>> getEventsByOrganizer(String organizerAddress) async {
    try {
      final getEventsByOrganizerFunction = _eventFactoryContract.function('getEventsByOrganizer');
      final result = await _client.call(
        contract: _eventFactoryContract,
        function: getEventsByOrganizerFunction,
        params: [EthereumAddress.fromHex(organizerAddress)],
      );
      
      return (result[0] as List<dynamic>).map((e) => (e as BigInt).toInt()).toList();
    } catch (e) {
      print('❌ Web3Service: Error getting events by organizer: $e');
      rethrow;
    }
  }
  
  // Check if address is connected to the correct network
  Future<bool> isCorrectNetwork() async {
    try {
      final networkId = await _client.getNetworkId();
      return networkId == _chainId;
    } catch (e) {
      print('❌ Web3Service: Error checking network: $e');
      return false;
    }
  }
  
  // Get current gas price
  Future<EtherAmount> getCurrentGasPrice() async {
    try {
      return await _client.getGasPrice();
    } catch (e) {
      print('❌ Web3Service: Error getting gas price: $e');
      rethrow;
    }
  }
  
  // Get account balance
  Future<EtherAmount> getBalance(EthereumAddress address) async {
    try {
      return await _client.getBalance(address);
    } catch (e) {
      print('❌ Web3Service: Error getting balance: $e');
      rethrow;
    }
  }
  
  // Wait for transaction confirmation
  Future<TransactionReceipt?> waitForTransactionConfirmation(String txHash) async {
    try {
      // Poll for transaction receipt
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 30; // 30 seconds timeout
      
      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          receipt = await _client.getTransactionReceipt(txHash);
        } catch (e) {
          // Transaction not yet mined, continue waiting
        }
        attempts++;
      }
      
      return receipt;
    } catch (e) {
      print('❌ Web3Service: Error waiting for transaction confirmation: $e');
      rethrow;
    }
  }
  
  // Check if an address has ORGANIZER_ROLE (DEPRECATED - anyone can create events now)
  Future<bool> hasOrganizerRole(String address) async {
    print('ℹ️ ORGANIZER_ROLE checking is deprecated - anyone can create events now!');
    return true; // Always return true since role checking is removed
  }

  // Get the ORGANIZER_ROLE hash for manual role granting
  Future<String> getOrganizerRoleHash() async {
    try {
      final organizerRoleFunction = _eventFactoryContract.function('ORGANIZER_ROLE');
      final roleResult = await _client.call(
        contract: _eventFactoryContract,
        function: organizerRoleFunction,
        params: [],
      );
      
      final roleHash = roleResult[0] as List<int>;
      final hexRoleHash = '0x${roleHash.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📝 ORGANIZER_ROLE hash: $hexRoleHash');
      
      return hexRoleHash;
    } catch (e) {
      print('❌ Web3Service: Error getting ORGANIZER_ROLE hash: $e');
      rethrow;
    }
  }

  // Get the contract owner address
  Future<String> getContractOwner() async {
    try {
      final ownerFunction = _eventFactoryContract.function('owner');
      final ownerResult = await _client.call(
        contract: _eventFactoryContract,
        function: ownerFunction,
        params: [],
      );
      
      final ownerAddress = ownerResult[0] as EthereumAddress;
      print('📝 Contract owner: ${ownerAddress.hex}');
      
      return ownerAddress.hex;
    } catch (e) {
      print('❌ Web3Service: Error getting contract owner: $e');
      rethrow;
    }
  }

  // Get the DEFAULT_ADMIN_ROLE hash
  Future<String> getDefaultAdminRoleHash() async {
    try {
      final defaultAdminRoleFunction = _eventFactoryContract.function('DEFAULT_ADMIN_ROLE');
      final defaultAdminResult = await _client.call(
        contract: _eventFactoryContract,
        function: defaultAdminRoleFunction,
        params: [],
      );
      
      final defaultAdminRoleHash = defaultAdminResult[0] as List<int>;
      final hexDefaultAdminRoleHash = '0x${defaultAdminRoleHash.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📝 DEFAULT_ADMIN_ROLE hash: $hexDefaultAdminRoleHash');
      
      return hexDefaultAdminRoleHash;
    } catch (e) {
      print('❌ Web3Service: Error getting DEFAULT_ADMIN_ROLE hash: $e');
      rethrow;
    }
  }

  // Check if an address has DEFAULT_ADMIN_ROLE
  Future<bool> hasDefaultAdminRole(String address) async {
    try {
      final defaultAdminRoleFunction = _eventFactoryContract.function('DEFAULT_ADMIN_ROLE');
      final defaultAdminResult = await _client.call(
        contract: _eventFactoryContract,
        function: defaultAdminRoleFunction,
        params: [],
      );
      
      final defaultAdminRoleHash = defaultAdminResult[0] as List<int>;
      
      final hasRoleFunction = _eventFactoryContract.function('hasRole');
      final hasAdminRoleResult = await _client.call(
        contract: _eventFactoryContract,
        function: hasRoleFunction,
        params: [defaultAdminRoleHash, EthereumAddress.fromHex(address)],
      );
      
      final hasAdminRole = hasAdminRoleResult[0] as bool;
      print('📝 Address $address has DEFAULT_ADMIN_ROLE: $hasAdminRole');
      
      return hasAdminRole;
    } catch (e) {
      print('❌ Web3Service: Error checking DEFAULT_ADMIN_ROLE: $e');
      return false;
    }
  }

  // Force refresh role status by waiting and retrying
  Future<bool> forceRefreshRoleStatus(String address) async {
    try {
      print('🔄 Force refreshing role status for address: $address');
      
      // Wait a bit for blockchain state to update
      await Future.delayed(const Duration(seconds: 3));
      
      // Try multiple times with increasing delays
      for (int attempt = 1; attempt <= 3; attempt++) {
        print('🔄 Role check attempt $attempt/3');
        
        final hasRole = await hasOrganizerRole(address);
        if (hasRole) {
          print('✅ Role confirmed on attempt $attempt');
          return true;
        }
        
        if (attempt < 3) {
          print('⏳ Waiting ${attempt * 2} seconds before retry...');
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }
      
      print('❌ Role still not detected after 3 attempts');
      return false;
    } catch (e) {
      print('❌ Error force refreshing role status: $e');
      return false;
    }
  }

  // Grant ORGANIZER_ROLE to an address (admin only)
  Future<String> grantOrganizerRole({
    required String address,
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🔑 Granting ORGANIZER_ROLE to: $address');
      
      // Get the ORGANIZER_ROLE hash
      final roleHash = await getOrganizerRoleHash();
      
      // Get the grantRole function
      final grantRoleFunction = _eventFactoryContract.function('grantRole');
      
      // Convert role hash string back to bytes32 for the contract call
      final roleHashHex = roleHash.substring(2); // Remove 0x prefix
      final roleHashBytes = Uint8List.fromList(
        List.generate(roleHashHex.length ~/ 2, (i) => 
          int.parse(roleHashHex.substring(i * 2, i * 2 + 2), radix: 16)
        )
      );
      
      // Prepare parameters: role, account
      final parameters = [
        roleHashBytes, // Use the role hash as bytes32
        EthereumAddress.fromHex(address),
      ];
      
      print('📋 Grant role parameters:');
      print('  - Role: $roleHash');
      print('  - Address: $address');
      
      // Create the transaction
      final transaction = Transaction.callContract(
        contract: _eventFactoryContract,
        function: grantRoleFunction,
        parameters: parameters,
      );
      
      // Convert transaction data to hex
      final hexData = '0x${transaction.data!.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      
      print('🔗 Sending grant role transaction...');
      
      // Sign and send the transaction
      final txHash = await signTransaction(
        _eventFactoryAddress.hex,
        [hexData],
      );
      
      print('✅ ORGANIZER_ROLE granted successfully');
      print('📝 Transaction Hash: $txHash');
      
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error granting ORGANIZER_ROLE: $e');
      rethrow;
    }
  }

  // ===== NFT CLAIMING AND MINTING METHODS =====
  
  // Claim existing NFT (this is what users should call, not mint)
  Future<String> claimBoundaryNFT({
    required int tokenId,
    required int eventId,
    required int latitude,
    required int longitude,
    required int accuracy,
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🎯 Web3Service: Claiming boundary NFT...');
      print('📝 Claim Details:');
      print('  - Token ID: $tokenId');
      print('  - Event ID: $eventId');
      print('  - Latitude: $latitude');
      print('  - Longitude: $longitude');
      print('  - Accuracy: $accuracy');
      
      // Get the claim function from BoundaryNFT contract
      final claimFunction = _boundaryNFTContract.function('claimBoundaryNFT');
      print('📜 Contract function: ${claimFunction.name}');
      
      // Create ClaimProof struct
      final claimProof = {
        'latitude': BigInt.from(latitude),
        'longitude': BigInt.from(longitude),
        'timestamp': BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'accuracy': BigInt.from(accuracy),
        'signature': '0x' + '0' * 130, // Mock signature for now
      };
      
      // Prepare the transaction parameters
      final parameters = [
        BigInt.from(tokenId),  // uint256 tokenId
        claimProof,            // ClaimProof struct
      ];
      
      print('📋 Function parameters:');
      print('  [0] Token ID: $tokenId');
      print('  [1] Claim Proof: $claimProof');
      
      // Create the transaction
      final transaction = Transaction.callContract(
        contract: _boundaryNFTContract,
        function: claimFunction,
        parameters: parameters,
      );
      
      if (transaction.data == null || transaction.data!.isEmpty) {
        throw Exception('Failed to encode NFT claiming transaction data');
      }
      
      // Convert transaction data to hex
      final hexData = '0x${transaction.data!.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📋 Transaction data as hex: $hexData');
      
      print('🔗 Sending NFT claiming transaction to wallet...');
      
      // Use the signTransaction function to sign and send the transaction
      final txHash = await signTransaction(
        _boundaryNFTAddress.hex,
        [hexData],
      );
      
      print('✅ Web3Service: NFT claiming transaction sent successfully');
      print('📝 Transaction Hash: $txHash');
      print('🔗 View on explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error claiming NFT: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  
  // Mint NFT for a boundary claim with correct ABI parameters
  Future<String> mintBoundaryNFT({
    required int eventId,
    required String name,
    required String description,
    required String imageURI,
    required int latitude,
    required int longitude, 
    required int radius,
    required String nftTokenURI,
    required String merkleRoot,
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🎨 Web3Service: Minting boundary NFT...');
      print('📝 NFT Details:');
      print('  - Event ID: $eventId');
      print('  - Name: "$name"');
      print('  - Description: "$description"');
      print('  - Image URI: "$imageURI"');
      print('  - Latitude: $latitude');
      print('  - Longitude: $longitude');
      print('  - Radius: $radius');
      print('  - NFT Token URI: "$nftTokenURI"');
      print('  - Merkle Root: "$merkleRoot"');
      
      // Get the mint function from BoundaryNFT contract
      final mintFunction = _boundaryNFTContract.function('mintBoundaryNFT');
      print('📜 Contract function: ${mintFunction.name}');
      print('📜 Function inputs: ${mintFunction.parameters.map((i) => '${i.name} (${i.type})').join(', ')}');
      
      // Convert merkle root from hex string to bytes32
      final merkleRootBytes = Uint8List.fromList(
        List.generate(merkleRoot.length ~/ 2, (i) => 
          int.parse(merkleRoot.substring(i * 2, i * 2 + 2), radix: 16)
        )
      );
      
      // Prepare the transaction parameters (exact order per ABI)
      final parameters = [
        BigInt.from(eventId),           // 1. uint256 eventId
        name,                          // 2. string name
        description,                   // 3. string description
        imageURI,                      // 4. string imageURI
        BigInt.from(latitude),         // 5. int256 latitude (can be negative)
        BigInt.from(longitude),        // 6. int256 longitude (can be negative)
        BigInt.from(radius),           // 7. uint256 radius
        nftTokenURI,                   // 8. string nftTokenURI
        merkleRootBytes,               // 9. bytes32 merkleRoot
      ];
      
      print('📋 Function parameters (${parameters.length} total):');
      for (int i = 0; i < parameters.length; i++) {
        final param = parameters[i];
        final paramType = param.runtimeType;
        print('  [$i] $paramType: $param');
      }
      
      // Create the transaction
      final transaction = Transaction.callContract(
        contract: _boundaryNFTContract,
        function: mintFunction,
        parameters: parameters,
      );
      
      if (transaction.data == null || transaction.data!.isEmpty) {
        throw Exception('Failed to encode NFT minting transaction data');
      }
      
      // Convert transaction data to hex
      final hexData = '0x${transaction.data!.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📋 Transaction data as hex: $hexData');
      print('📋 Hex data length: ${hexData.length} characters');
      
      // Extract function selector
      final functionSelector = hexData.substring(0, 10);
      print('📋 Function selector: $functionSelector');
      
      print('🔗 Sending NFT minting transaction to wallet...');
      
      // Use the signTransaction function to sign and send the transaction
      final txHash = await signTransaction(
        _boundaryNFTAddress.hex,
        [hexData],
      );
      
      print('✅ Web3Service: NFT minting transaction sent successfully');
      print('📝 Transaction Hash: $txHash');
      print('🔗 View on explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error minting NFT: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Enhanced error information for NFT minting
      if (e.toString().contains('revert')) {
        print('❌ NFT minting reverted - possible causes:');
        print('   - Invalid event ID');
        print('   - Boundary already minted');
        print('   - Invalid coordinates');
        print('   - Insufficient permissions');
      }
      
      rethrow;
    }
  }
  
  // Verify location claim
  Future<String> submitLocationClaim({
    required int tokenId,
    required int eventId,
    required int latitude,
    required int longitude,
    required int timestamp,
    required int accuracy,
    required String signature,
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('📍 Web3Service: Submitting location claim...');
      print('📝 Claim Details:');
      print('  - Token ID: $tokenId');
      print('  - Event ID: $eventId');
      print('  - Latitude: $latitude');
      print('  - Longitude: $longitude');
      print('  - Timestamp: $timestamp');
      print('  - Accuracy: $accuracy');
      
      // Get the submitLocationClaim function from ClaimVerification contract
      final claimFunction = _claimVerificationContract.function('submitLocationClaim');
      print('📜 Contract function: ${claimFunction.name}');
      
      // Convert signature from hex string to bytes
      final signatureBytes = Uint8List.fromList(
        List.generate(signature.length ~/ 2, (i) => 
          int.parse(signature.substring(i * 2, i * 2 + 2), radix: 16)
        )
      );
      
      // Prepare the transaction parameters
      final parameters = [
        BigInt.from(tokenId),           // uint256 tokenId
        BigInt.from(eventId),           // uint256 eventId
        BigInt.from(latitude),          // int256 latitude
        BigInt.from(longitude),         // int256 longitude
        BigInt.from(timestamp),         // uint256 timestamp
        BigInt.from(accuracy),          // uint256 accuracy
        signatureBytes,                 // bytes signature
      ];
      
      print('📋 Function parameters (${parameters.length} total):');
      for (int i = 0; i < parameters.length; i++) {
        final param = parameters[i];
        final paramType = param.runtimeType;
        print('  [$i] $paramType: $param');
      }
      
      // Create the transaction
      final transaction = Transaction.callContract(
        contract: _claimVerificationContract,
        function: claimFunction,
        parameters: parameters,
      );
      
      // Convert transaction data to hex
      final hexData = '0x${transaction.data!.map((e) => e.toRadixString(16).padLeft(2, '0')).join()}';
      print('📋 Transaction data as hex: $hexData');
      
      print('🔗 Sending location claim transaction to wallet...');
      
      // Use the signTransaction function to sign and send the transaction
      final txHash = await signTransaction(
        _claimVerificationAddress.hex,
        [hexData],
      );
      
      print('✅ Web3Service: Location claim transaction sent successfully');
      print('📝 Transaction Hash: $txHash');
      print('🔗 View on explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error submitting location claim: $e');
      print('❌ Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  
  // Get NFT metadata for a token
  Future<Map<String, dynamic>> getNFTMetadata(int tokenId) async {
    try {
      final metadataFunction = _boundaryNFTContract.function('nftMetadata');
      final result = await _client.call(
        contract: _boundaryNFTContract,
        function: metadataFunction,
        params: [BigInt.from(tokenId)],
      );
      
      return {
        'eventId': (result[0] as BigInt).toInt(),
        'name': result[1].toString(),
        'description': result[2].toString(),
        'imageURI': result[3].toString(),
        'latitude': (result[4] as BigInt).toInt(),
        'longitude': (result[5] as BigInt).toInt(),
        'radius': (result[6] as BigInt).toInt(),
        'mintTimestamp': (result[7] as BigInt).toInt(),
        'claimTimestamp': (result[8] as BigInt).toInt(),
        'claimer': result[9].toString(),
      };
    } catch (e) {
      print('❌ Web3Service: Error getting NFT metadata: $e');
      rethrow;
    }
  }
  
  // Check if a token has been claimed
  Future<bool> isTokenClaimed(int tokenId) async {
    try {
      final claimedFunction = _boundaryNFTContract.function('claimedTokens');
      final result = await _client.call(
        contract: _boundaryNFTContract,
        function: claimedFunction,
        params: [BigInt.from(tokenId)],
      );
      
      return result[0] as bool;
    } catch (e) {
      print('❌ Web3Service: Error checking if token is claimed: $e');
      return false;
    }
  }
  
  // Get user's NFT tokens
  Future<List<int>> getUserNFTs(String userAddress) async {
    try {
      final userTokensFunction = _boundaryNFTContract.function('userTokens');
      final result = await _client.call(
        contract: _boundaryNFTContract,
        function: userTokensFunction,
        params: [EthereumAddress.fromHex(userAddress)],
      );
      
      return (result[0] as List<dynamic>).map((e) => (e as BigInt).toInt()).toList();
    } catch (e) {
      print('❌ Web3Service: Error getting user NFTs: $e');
      return [];
    }
  }
  
  // Get total supply of NFTs
  Future<int> getTotalNFTSupply() async {
    try {
      final totalSupplyFunction = _boundaryNFTContract.function('totalSupply');
      final result = await _client.call(
        contract: _boundaryNFTContract,
        function: totalSupplyFunction,
        params: [],
      );
      
      return (result[0] as BigInt).toInt();
    } catch (e) {
      print('❌ Web3Service: Error getting total NFT supply: $e');
      return 0;
    }
  }

  void dispose() {
    _client.dispose();
  }
}
