import 'dart:convert';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';

class Web3Service {
  static const String _arbitrumSepoliaRpcUrl = 'https://sepolia-rollup.arbitrum.io/rpc';
  static const int _chainId = 421614;
  
  late Web3Client _client;
  late EthereumAddress _eventFactoryAddress;
  late EthereumAddress _boundaryNFTAddress;
  late EthereumAddress _claimVerificationAddress;
  
  late DeployedContract _eventFactoryContract;
  late DeployedContract _boundaryNFTContract;
  late DeployedContract _claimVerificationContract;
  
  Web3Service() {
    _client = Web3Client(_arbitrumSepoliaRpcUrl, http.Client());
    _loadContractAddresses();
  }
  
  void _loadContractAddresses() {
    // Load contract addresses from the deployment
    _eventFactoryAddress = EthereumAddress.fromHex('0xf7bECe16CC3182C1890eC722cbd0E29aC61F888D');
    _boundaryNFTAddress = EthereumAddress.fromHex('0x1F2F71fa673a38CBC5848985A74713bDfB584578');
    _claimVerificationAddress = EthereumAddress.fromHex('0xf9c06Bf0C78E6738871BA2F2C2365244fbBB3046');
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
  String get rpcUrl => _arbitrumSepoliaRpcUrl;
  
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
    required Function(String, List<dynamic>) signTransaction,
  }) async {
    try {
      print('🚀 Web3Service: Creating event on blockchain...');
      print('Event Name: $eventName');
      print('Organizer: $organizerWallet');
      print('NFT Supply: $nftSupplyCount');
      
      // Get the createEvent function
      final createEventFunction = _eventFactoryContract.function('createEvent');
      
      // Prepare the transaction parameters
      final transaction = Transaction.callContract(
        contract: _eventFactoryContract,
        function: createEventFunction,
        parameters: [
          eventName,
          eventDescription,
          EthereumAddress.fromHex(organizerWallet),
          BigInt.from(latitude),
          BigInt.from(longitude),
          venueName,
          BigInt.from(nftSupplyCount),
          eventImageUrl,
        ],
      );
      
      // Use the signTransaction function to sign and send the transaction
      final txHash = await signTransaction(
        _eventFactoryAddress.hex,
        [
          transaction.data,
          _chainId,
        ],
      );
      
      print('✅ Web3Service: Event creation transaction sent: $txHash');
      return txHash;
    } catch (e) {
      print('❌ Web3Service: Error creating event: $e');
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
  
  // Get total events count
  Future<int> getTotalEventsCount() async {
    try {
      final totalEventsFunction = _eventFactoryContract.function('getTotalEventsCount');
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
  
  void dispose() {
    _client.dispose();
  }
}
