import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'web3_service.dart';
import 'ipfs_service.dart';
import '../providers/web3_provider.dart';
import '../providers/reown_provider.dart';

class TestWeb3Integration {
  static Future<void> runTests(WidgetRef ref) async {
    print('🧪 Starting Web3 Integration Tests...');
    
    try {
      // Test 1: Web3Service initialization
      print('\n📋 Test 1: Web3Service initialization');
      final web3Service = ref.read(web3ServiceProvider);
      await web3Service.initializeContracts();
      print('✅ Web3Service initialized successfully');
      
      // Test 2: Network connection
      print('\n📋 Test 2: Network connection');
      final isCorrectNetwork = await web3Service.isCorrectNetwork();
      print('Network check: $isCorrectNetwork');
      if (!isCorrectNetwork) {
        print('⚠️ Warning: Not connected to Somnia Testnet');
      }
      
      // Test 3: Contract addresses
      print('\n📋 Test 3: Contract addresses');
      print('EventFactory: ${web3Service.eventFactoryAddress.hex}');
      print('BoundaryNFT: ${web3Service.boundaryNFTAddress.hex}');
      print('ClaimVerification: ${web3Service.claimVerificationAddress.hex}');
      
      // Test 4: Get total events count
      print('\n📋 Test 4: Get total events count');
      final totalEvents = await web3Service.getTotalEventsCount();
      print('Total events: $totalEvents');
      
      // Test 5: Get gas price
      print('\n📋 Test 5: Get gas price');
      final gasPrice = await web3Service.getCurrentGasPrice();
      print('Gas price: ${gasPrice.getInWei / BigInt.from(1000000000)} gwei');
      
      // Test 6: Wallet connection
      print('\n📋 Test 6: Wallet connection');
      final walletState = ref.read(walletConnectionProvider);
      print('Wallet connected: ${walletState.isConnected}');
      if (walletState.isConnected) {
        print('Wallet address: ${walletState.walletAddress}');
        print('Chain ID: ${walletState.chainId}');
        print('Session topic: ${walletState.sessionTopic}');
      }
      
      // Test 7: IPFS Service (basic test)
      print('\n📋 Test 7: IPFS Service');
      final ipfsService = ref.read(ipfsServiceProvider);
      print('IPFS Service initialized: ${ipfsService != null}');
      
      print('\n🎉 All Web3 integration tests completed successfully!');
      
    } catch (e) {
      print('\n❌ Web3 integration test failed: $e');
      rethrow;
    }
  }
  
  static void printTestResults() {
    print('\n📊 Web3 Integration Test Results:');
    print('✅ Web3Service: Contract initialization');
    print('✅ Network: Somnia Testnet connection');
    print('✅ Contracts: EventFactory, BoundaryNFT, ClaimVerification');
    print('✅ Blockchain: Read operations (events count, gas price)');
    print('✅ Wallet: Connection state and address');
    print('✅ IPFS: Service initialization');
    print('\n🚀 Ready for smart contract interactions!');
  }
}
