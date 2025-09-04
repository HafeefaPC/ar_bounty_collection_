import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';
import 'package:crypto/crypto.dart';
import '../models/event.dart';
import '../models/boundary.dart';
import 'ipfs_service.dart';
import '../config/contracts_config.dart';

class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService() => _instance;
  BlockchainService._internal();

  // Avalanche Fuji Testnet configuration
  static const String _rpcUrl = 'https://api.avax-test.network/ext/bc/C/rpc';
  static const int _chainId = 43113;
  static const String _nativeCurrency = 'AVAX';
  
  // Contract addresses - to be set after deployment
  String? _eventFactoryAddress;
  String? _boundaryNFTAddress;
  String? _claimVerificationAddress;
  
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

  final String _boundaryNFTABI = '''
  [
    {
      "inputs": [
        {"internalType": "uint256", "name": "eventId", "type": "uint256"},
        {"internalType": "string[]", "name": "names", "type": "string[]"},
        {"internalType": "string[]", "name": "descriptions", "type": "string[]"},
        {"internalType": "string[]", "name": "imageURIs", "type": "string[]"},
        {"internalType": "int256[]", "name": "latitudes", "type": "int256[]"},
        {"internalType": "int256[]", "name": "longitudes", "type": "int256[]"},
        {"internalType": "uint256[]", "name": "radiuses", "type": "uint256[]"},
        {"internalType": "string[]", "name": "tokenURIs", "type": "string[]"},
        {"internalType": "bytes32[]", "name": "merkleRoots", "type": "bytes32[]"}
      ],
      "name": "batchMintBoundaryNFTs",
      "outputs": [{"internalType": "uint256[]", "name": "", "type": "uint256[]"}],
      "stateMutability": "nonpayable",
      "type": "function"
    },
    {
      "inputs": [
        {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
        {
          "components": [
            {"internalType": "int256", "name": "latitude", "type": "int256"},
            {"internalType": "int256", "name": "longitude", "type": "int256"},
            {"internalType": "uint256", "name": "timestamp", "type": "uint256"},
            {"internalType": "bytes32[]", "name": "merkleProof", "type": "bytes32[]"}
          ],
          "internalType": "struct BoundaryNFT.ClaimProof",
          "name": "proof",
          "type": "tuple"
        }
      ],
      "name": "claimBoundaryNFT",
      "outputs": [],
      "stateMutability": "nonpayable",
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
    
    _web3Client = Web3Client(_rpcUrl, Client());
    _ipfsService = IPFSService();
  }

  // Convert double coordinates to blockchain integers (scaled by 1e6)
  BigInt _coordToInt(double coord) {
    return BigInt.from((coord * 1000000).round());
  }

  // Convert blockchain integers back to double coordinates
  double _intToCoord(BigInt intCoord) {
    return intCoord.toDouble() / 1000000.0;
  }

  // Generate a random event code
  String _generateEventCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
    );
  }

  // Create event on blockchain
  Future<String> createEventOnBlockchain({
    required Event event,
    required String privateKey,
    required List<String> boundaryImagePaths,
  }) async {
    if (_eventFactoryAddress == null) {
      throw Exception('EventFactory contract address not set');
    }

    try {
      // 1. Upload images to IPFS
      print('Uploading boundary images to IPFS...');
      final boundaryImageHashes = <String>[];
      for (int i = 0; i < boundaryImagePaths.length; i++) {
        final imageFile = File(boundaryImagePaths[i]);
        final imageHash = await _ipfsService.uploadFile(
          imageFile.path,
          customName: 'boundary-${event.id}-$i-image',
        );
        boundaryImageHashes.add(imageHash);
      }

      // 2. Upload event metadata to IPFS
      print('Uploading event metadata to IPFS...');
      final eventMetadata = _ipfsService.createEventMetadata(
        name: event.name,
        description: event.description,
        organizer: EthereumAddress.fromHex(privateKey).hexEip55,
        latitude: event.latitude,
        longitude: event.longitude,
        venue: event.venueName,
        nftSupplyCount: event.nftSupplyCount,
        imageUrl: boundaryImageHashes.isNotEmpty ? boundaryImageHashes.first : 'default_image',
        boundaries: event.boundaries.map((b) => {
          'name': b.name,
          'description': b.description,
          'latitude': b.latitude,
          'longitude': b.longitude,
          'radius': b.radius,
          'image': boundaryImageHashes.isNotEmpty ? boundaryImageHashes.first : 'default_image',
        }).toList(),
        startDate: event.startDate,
        endDate: event.endDate,
      );
      
      final eventMetadataHash = await _ipfsService.uploadMetadata(eventMetadata);

      // 3. Create event on blockchain
      print('Creating event on blockchain...');
      final credentials = EthPrivateKey.fromHex(privateKey);
      final contract = DeployedContract(
        ContractAbi.fromJson(_eventFactoryABI, 'EventFactory'),
        EthereumAddress.fromHex(_eventFactoryAddress!),
      );

      final createEventFunction = contract.function('createEvent');
      final eventCode = _generateEventCode();

      final transaction = Transaction.callContract(
        contract: contract,
        function: createEventFunction,
        parameters: [
          event.name,
          event.description,
          event.venueName,
          BigInt.from(event.startDate?.millisecondsSinceEpoch ?? 0),
          BigInt.from(event.endDate?.millisecondsSinceEpoch ?? 0),
          BigInt.from(event.nftSupplyCount),
          eventMetadataHash,
          eventCode,
          _coordToInt(event.latitude),
          _coordToInt(event.longitude),
          BigInt.from((event.visibilityRadius * 1000).round()), // Convert to meters
        ],
        maxGas: 500000,
      );

      final txHash = await _web3Client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      print('Event creation transaction sent: $txHash');
      
      // 4. Wait for transaction confirmation
      final receipt = await _waitForTransaction(txHash);
      if (receipt?.status != true) {
        throw Exception('Event creation transaction failed');
      }

      // 5. Mint boundary NFTs
      await _mintBoundaryNFTs(
        eventId: BigInt.from(1), // This should be extracted from event creation logs
        boundaries: event.boundaries,
        imageHashes: boundaryImageHashes,
        privateKey: privateKey,
      );

      return txHash;
    } catch (e) {
      print('Error creating event on blockchain: $e');
      rethrow;
    }
  }

  // Mint boundary NFTs
  Future<String> _mintBoundaryNFTs({
    required BigInt eventId,
    required List<Boundary> boundaries,
    required List<String> imageHashes,
    required String privateKey,
  }) async {
    if (_boundaryNFTAddress == null) {
      throw Exception('BoundaryNFT contract address not set');
    }

    try {
      print('Minting ${boundaries.length} boundary NFTs...');
      
      // Prepare NFT metadata and upload to IPFS
      final tokenURIs = <String>[];
      for (int i = 0; i < boundaries.length; i++) {
        final boundary = boundaries[i];
        final imageHash = i < imageHashes.length ? imageHashes[i] : null;
        
        final nftMetadata = {
          'name': boundary.name,
          'description': boundary.description,
          'image': imageHash ?? 'default_image',
          'attributes': [
            {'trait_type': 'Event ID', 'value': eventId.toString()},
            {'trait_type': 'Token ID', 'value': '${eventId}_$i'},
            {'trait_type': 'Latitude', 'value': boundary.latitude.toString()},
            {'trait_type': 'Longitude', 'value': boundary.longitude.toString()},
            {'trait_type': 'Radius', 'value': boundary.radius.toString()},
          ],
        };
        
        final metadataHash = await _ipfsService.uploadMetadata(nftMetadata);
        
        tokenURIs.add('ipfs://$metadataHash');
      }

      // Prepare contract parameters
      final credentials = EthPrivateKey.fromHex(privateKey);
      final contract = DeployedContract(
        ContractAbi.fromJson(_boundaryNFTABI, 'BoundaryNFT'),
        EthereumAddress.fromHex(_boundaryNFTAddress!),
      );

      final batchMintFunction = contract.function('batchMintBoundaryNFTs');
      
      // Generate simple merkle roots (in production, these should be proper merkle trees)
      final merkleRoots = boundaries.map((boundary) {
        final data = '${boundary.latitude}_${boundary.longitude}_${boundary.radius}';
        final hash = sha256.convert(utf8.encode(data));
        return '0x${hash.toString()}';
      }).toList();

      final transaction = Transaction.callContract(
        contract: contract,
        function: batchMintFunction,
        parameters: [
          eventId,
          boundaries.map((b) => b.name).toList(),
          boundaries.map((b) => b.description).toList(),
          imageHashes.map((hash) => 'ipfs://$hash').toList(),
          boundaries.map((b) => _coordToInt(b.latitude)).toList(),
          boundaries.map((b) => _coordToInt(b.longitude)).toList(),
          boundaries.map((b) => BigInt.from((b.radius * 1000).round())).toList(),
          tokenURIs,
          merkleRoots,
        ],
        maxGas: 2000000,
      );

      final txHash = await _web3Client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      print('Boundary NFTs minting transaction sent: $txHash');
      return txHash;
    } catch (e) {
      print('Error minting boundary NFTs: $e');
      rethrow;
    }
  }

  // Get event from blockchain by event code
  Future<Map<String, dynamic>?> getEventByCode(String eventCode) async {
    if (_eventFactoryAddress == null) {
      throw Exception('EventFactory contract address not set');
    }

    try {
      final contract = DeployedContract(
        ContractAbi.fromJson(_eventFactoryABI, 'EventFactory'),
        EthereumAddress.fromHex(_eventFactoryAddress!),
      );

      final getEventFunction = contract.function('getEventByCode');
      final result = await _web3Client.call(
        contract: contract,
        function: getEventFunction,
        params: [eventCode],
      );

      if (result.isNotEmpty) {
        final eventData = result[0] as List;
        return _parseEventData(eventData);
      }
    } catch (e) {
      print('Error getting event by code: $e');
    }
    
    return null;
  }

  // Parse blockchain event data
  Map<String, dynamic> _parseEventData(List eventData) {
    return {
      'id': (eventData[0] as BigInt).toInt(),
      'organizer': (eventData[1] as EthereumAddress).hex,
      'name': eventData[2] as String,
      'description': eventData[3] as String,
      'venue': eventData[4] as String,
      'startTime': (eventData[5] as BigInt).toInt(),
      'endTime': (eventData[6] as BigInt).toInt(),
      'totalNFTs': (eventData[7] as BigInt).toInt(),
      'metadataURI': eventData[8] as String,
      'active': eventData[9] as bool,
      'createdAt': (eventData[10] as BigInt).toInt(),
      'claimedCount': (eventData[11] as BigInt).toInt(),
      'latitude': _intToCoord(eventData[12] as BigInt),
      'longitude': _intToCoord(eventData[13] as BigInt),
      'radius': (eventData[14] as BigInt).toInt(),
    };
  }

  // Claim boundary NFT
  Future<String> claimBoundaryNFT({
    required String tokenId,
    required double latitude,
    required double longitude,
    required String privateKey,
  }) async {
    if (_boundaryNFTAddress == null) {
      throw Exception('BoundaryNFT contract address not set');
    }

    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final contract = DeployedContract(
        ContractAbi.fromJson(_boundaryNFTABI, 'BoundaryNFT'),
        EthereumAddress.fromHex(_boundaryNFTAddress!),
      );

      final claimFunction = contract.function('claimBoundaryNFT');
      
      // Generate claim proof (simplified - in production, this should be a proper merkle proof)
      final timestamp = BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      final merkleProof = <String>[]; // Empty proof for now

      final transaction = Transaction.callContract(
        contract: contract,
        function: claimFunction,
        parameters: [
          BigInt.parse(tokenId),
          [
            _coordToInt(latitude),
            _coordToInt(longitude),
            timestamp,
            merkleProof,
          ],
        ],
        maxGas: 300000,
      );

      final txHash = await _web3Client.sendTransaction(
        credentials,
        transaction,
        chainId: _chainId,
      );

      print('Boundary claim transaction sent: $txHash');
      return txHash;
    } catch (e) {
      print('Error claiming boundary NFT: $e');
      rethrow;
    }
  }

  // Wait for transaction confirmation
  Future<TransactionReceipt?> _waitForTransaction(
    String txHash, {
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (stopwatch.elapsed < timeout) {
      try {
        final receipt = await _web3Client.getTransactionReceipt(txHash);
        if (receipt != null) {
          return receipt;
        }
      } catch (e) {
        // Continue waiting
      }
      
      await Future.delayed(const Duration(seconds: 5));
    }
    
    throw Exception('Transaction confirmation timeout');
  }

  // Get current gas price
  Future<EtherAmount> getCurrentGasPrice() async {
    try {
      return await _web3Client.getGasPrice();
    } catch (e) {
      print('Error getting gas price: $e');
      return EtherAmount.inWei(BigInt.from(25000000000)); // 25 gwei fallback
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
      return BigInt.from(500000); // Default gas limit
    }
  }

  // Get network information
  Map<String, dynamic> getNetworkInfo() {
    return {
      'name': 'Avalanche Fuji Testnet',
      'chainId': _chainId,
      'rpcUrl': _rpcUrl,
      'nativeCurrency': _nativeCurrency,
      'blockExplorer': 'https://testnet.snowtrace.io',
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