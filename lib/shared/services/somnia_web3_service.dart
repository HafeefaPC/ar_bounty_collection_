import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'ipfs_service.dart';
import '../config/contracts_config.dart';

class SomniaWeb3Service {
  static final SomniaWeb3Service _instance = SomniaWeb3Service._internal();
  factory SomniaWeb3Service() => _instance;
  SomniaWeb3Service._internal();

  // Somnia Testnet configuration
  static const String _rpcUrl = 'https://dream-rpc.somnia.network';
  static const int _chainId = 50312;
  static const String _nativeCurrency = 'STT';
  
  // Contract addresses - loaded from config
  String? _eventFactoryAddress;
  String? _boundaryNFTAddress;
  String? _claimVerificationAddress;
  
  // Getters for contract addresses
  String? get eventFactoryAddress => _eventFactoryAddress;
  String? get boundaryNFTAddress => _boundaryNFTAddress;
  String? get claimVerificationAddress => _claimVerificationAddress;
  
  late Web3Client _web3Client;
  late IPFSService _ipfsService;
  
  // Contract ABIs (simplified for essential functions)
  final String _eventFactoryABI = '''
  [
    {
      "inputs": [
        {"internalType": "string", "name": "name", "type": "string"},
        {"internalType": "string", "name": "description", "type": "string"},
        {"internalType": "string", "name": "venue", "type": "string"},
        {"internalType": "uint256", "name": "startTime", "type": "uint256"},
        {"internalType": "uint256", "name": "endTime", "type": "uint256"},
        {"internalType": "uint256", "name": "totalNFTs", "type": "uint256"},
        {"internalType": "string", "name": "metadataURI", "type": "string"},
        {"internalType": "string", "name": "eventCode", "type": "string"},
        {"internalType": "int256", "name": "latitude", "type": "int256"},
        {"internalType": "int256", "name": "longitude", "type": "int256"},
        {"internalType": "uint256", "name": "radius", "type": "uint256"}
      ],
      "name": "createEvent",
      "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [{"internalType": "string", "name": "eventCode", "type": "string"}],
      "name": "getEventByCode",
      "outputs": [{
        "components": [
          {"internalType": "uint256", "name": "id", "type": "uint256"},
          {"internalType": "address", "name": "organizer", "type": "address"},
          {"internalType": "string", "name": "name", "type": "string"},
          {"internalType": "string", "name": "description", "type": "string"},
          {"internalType": "string", "name": "venue", "type": "string"},
          {"internalType": "uint256", "name": "startTime", "type": "uint256"},
          {"internalType": "uint256", "name": "endTime", "type": "uint256"},
          {"internalType": "uint256", "name": "totalNFTs", "type": "uint256"},
          {"internalType": "string", "name": "metadataURI", "type": "string"},
          {"internalType": "bool", "name": "active", "type": "bool"},
          {"internalType": "uint256", "name": "createdAt", "type": "uint256"},
          {"internalType": "uint256", "name": "claimedCount", "type": "uint256"},
          {"internalType": "int256", "name": "latitude", "type": "int256"},
          {"internalType": "int256", "name": "longitude", "type": "int256"},
          {"internalType": "uint256", "name": "radius", "type": "uint256"}
        ],
        "internalType": "struct EventFactory.Event",
        "name": "",
        "type": "tuple"
      }],
      "stateMutability": "view",
      "type": "function"
    }
  ]
  ''';

  // Initialize the blockchain service
  void initialize([String network = ContractsConfig.defaultNetwork]) {
    final contracts = ContractsConfig.getContracts(network);
    _eventFactoryAddress = contracts['EventFactory']!;
    _boundaryNFTAddress = contracts['BoundaryNFT']!;
    _claimVerificationAddress = contracts['ClaimVerification']!;
    
    print('🎯 SomniaWeb3Service: Initialized with Somnia Testnet contracts:');
    print('  - EventFactory: $_eventFactoryAddress ✅ DEPLOYED');
    print('  - BoundaryNFT: $_boundaryNFTAddress ⏳ PENDING');
    print('  - ClaimVerification: $_claimVerificationAddress ✅ DEPLOYED');
    
    _web3Client = Web3Client(_rpcUrl, Client());
    _ipfsService = IPFSService();
  }

  // Create event on blockchain with proper EIP-1559 support for Somnia Testnet
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
      print('🎯 SomniaWeb3Service: Creating event on Somnia Testnet...');
      print('📝 Event Details:');
      print('  - Name: $eventName');
      print('  - Description: $eventDescription');
      print('  - Organizer: $organizerWallet');
      print('  - Venue: $venueName');
      print('  - NFT Supply: $nftSupplyCount');
      print('  - Event Code: $eventCode');
      print('  - Start Time: $startTime');
      print('  - End Time: $endTime');
      print('  - Radius: $radius');
      
      if (_eventFactoryAddress == null) {
        throw Exception('EventFactory contract address not set');
      }

      // Get the createEvent function from the contract
      final contract = DeployedContract(
        ContractAbi.fromJson(_eventFactoryABI, 'EventFactory'),
        EthereumAddress.fromHex(_eventFactoryAddress!),
      );

      final createEventFunction = contract.function('createEvent');
      print('📜 Contract function: ${createEventFunction.name}');

      // Prepare the transaction parameters
      final parameters = [
        eventName,                    // string name
        eventDescription,             // string description
        venueName,                    // string venue
        BigInt.from(startTime),       // uint256 startTime
        BigInt.from(endTime),         // uint256 endTime
        BigInt.from(nftSupplyCount),  // uint256 totalNFTs
        eventImageUrl,                // string metadataURI
        eventCode,                    // string eventCode
        BigInt.from(latitude),        // int256 latitude
        BigInt.from(longitude),       // int256 longitude
        BigInt.from(radius),          // uint256 radius
      ];

      print('📋 Function parameters (${parameters.length} total):');
      for (int i = 0; i < parameters.length; i++) {
        final param = parameters[i];
        final paramType = param.runtimeType;
        print('  [$i] $paramType: $param');
      }

      // Create the transaction with proper gas estimation for Somnia Testnet
      final transaction = Transaction.callContract(
        contract: contract,
        function: createEventFunction,
        parameters: parameters,
        maxGas: 2000000, // 2M gas limit for Somnia Testnet
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
        _eventFactoryAddress!,
        [hexData],
      );

      print('✅ SomniaWeb3Service: Event creation transaction sent successfully');
      print('📝 Transaction Hash: $txHash');
      print('🔗 View on explorer: https://shannon-explorer.somnia.network/tx/$txHash');

      return txHash;
    } catch (e) {
      print('❌ SomniaWeb3Service: Error creating event: $e');
      print('❌ Error type: ${e.runtimeType}');
      
      // Enhanced error information for event creation
      if (e.toString().contains('revert')) {
        print('❌ Event creation reverted - possible causes:');
        print('   - Event code already exists');
        print('   - Invalid parameters');
        print('   - Contract paused or restricted');
        print('   - Network congestion');
        print('   - Insufficient gas limit');
      }
      
      rethrow;
    }
  }

  // Wait for transaction confirmation with proper timeout for Somnia Testnet
  Future<TransactionReceipt?> waitForTransactionConfirmation(String txHash) async {
    try {
      print('⏳ SomniaWeb3Service: Waiting for transaction confirmation...');
      print('📝 Transaction Hash: $txHash');
      
      // Poll for transaction receipt with longer timeout for Somnia Testnet
      TransactionReceipt? receipt;
      int attempts = 0;
      const maxAttempts = 60; // 60 seconds timeout
      
      while (receipt == null && attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          receipt = await _web3Client.getTransactionReceipt(txHash);
          if (receipt != null) {
            print('✅ SomniaWeb3Service: Transaction confirmed!');
            print('📋 Block Number: ${receipt.blockNumber}');
            print('📋 Gas Used: ${receipt.gasUsed}');
            print('📋 Status: ${receipt.status}');
            break;
          }
        } catch (e) {
          // Transaction not yet mined, continue waiting
          if (attempts % 10 == 0) { // Log every 10 seconds
            print('⏳ SomniaWeb3Service: Still waiting for confirmation... (${attempts + 1}s)');
          }
        }
        attempts++;
      }
      
      if (receipt == null) {
        print('⚠️ SomniaWeb3Service: Transaction confirmation timeout after ${maxAttempts} seconds');
        print('⚠️ Transaction may still be pending on the network');
        print('🔗 Check on explorer: https://shannon-explorer.somnia.network/tx/$txHash');
      }
      
      return receipt;
    } catch (e) {
      print('❌ SomniaWeb3Service: Error waiting for transaction confirmation: $e');
      rethrow;
    }
  }

  // Check if event code already exists
  Future<bool> eventCodeExists(String eventCode) async {
    try {
      print('🔍 Checking if event code exists: $eventCode');
      
      final contract = DeployedContract(
        ContractAbi.fromJson(_eventFactoryABI, 'EventFactory'),
        EthereumAddress.fromHex(_eventFactoryAddress!),
      );
      
      // Call the eventCodeToId mapping directly
      final result = await _web3Client.call(
        contract: contract,
        function: contract.function('eventCodeToId'),
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

  // Get current gas price for Somnia Testnet
  Future<EtherAmount> getCurrentGasPrice() async {
    try {
      return await _web3Client.getGasPrice();
    } catch (e) {
      print('Error getting gas price: $e');
      return EtherAmount.inWei(BigInt.from(2000000000)); // 2 gwei fallback for Somnia
    }
  }

  // Estimate gas for transaction
  Future<BigInt> estimateGas({
    required EthereumAddress from,
    required EthereumAddress to,
    Uint8List? data,
    EtherAmount? value,
  }) async {
    try {
      return await _web3Client.estimateGas(
        sender: from,
        to: to,
        data: data,
        value: value,
      );
    } catch (e) {
      print('Error estimating gas: $e');
      return BigInt.from(2000000); // Default gas limit for Somnia
    }
  }

  // Get network information
  Map<String, dynamic> getNetworkInfo() {
    return {
      'name': 'Somnia Testnet',
      'chainId': _chainId,
      'rpcUrl': _rpcUrl,
      'nativeCurrency': _nativeCurrency,
      'blockExplorer': 'https://shannon-explorer.somnia.network',
    };
  }

  // Check if contracts are deployed
  bool get isInitialized {
    return _eventFactoryAddress != null && 
           _boundaryNFTAddress != null && 
           _claimVerificationAddress != null;
  }

  // Dispose resources
  void dispose() {
    _web3Client.dispose();
    _ipfsService.dispose();
  }
}
