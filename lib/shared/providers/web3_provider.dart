import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/web3_service.dart';
import '../services/ipfs_service.dart';

// Web3Service provider
final web3ServiceProvider = Provider<Web3Service>((ref) {
  final service = Web3Service();
  
  // Initialize contracts when the service is created
  service.initializeContracts().catchError((error) {
    print('❌ Web3Provider: Failed to initialize contracts: $error');
  });
  
  // Dispose the service when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// IPFSService provider
final ipfsServiceProvider = Provider<IPFSService>((ref) {
  final service = IPFSService();
  
  // Dispose the service when the provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

// Network status provider
final networkStatusProvider = FutureProvider<bool>((ref) async {
  final web3Service = ref.read(web3ServiceProvider);
  return await web3Service.isCorrectNetwork();
});

// Gas price provider
final gasPriceProvider = FutureProvider<String>((ref) async {
  final web3Service = ref.read(web3ServiceProvider);
  final gasPrice = await web3Service.getCurrentGasPrice();
  return '${gasPrice.getInWei / BigInt.from(1000000000)} gwei'; // Convert to gwei
});

// Total events count provider
final totalEventsCountProvider = FutureProvider<int>((ref) async {
  final web3Service = ref.read(web3ServiceProvider);
  return await web3Service.getTotalEventsCount();
});
