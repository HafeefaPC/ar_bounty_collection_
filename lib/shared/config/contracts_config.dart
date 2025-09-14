class ContractsConfig {
  // Contract addresses for Somnia Testnet (UPDATED - Latest Deployment)
  static const Map<String, String> somniaTestnetContracts = {
    'EventFactory': '0x1F2F71fa673a38CBC5848985A74713bDfB584578', // ✅ DEPLOYED
    'BoundaryNFT': '0x0000000000000000000000000000000000000000', // ⏳ PENDING - Not deployed yet
    'ClaimVerification': '0x80FF10046dc3082A6925F04DE51102ebFB3f9EC6', // ✅ DEPLOYED
  };

  // Contract addresses for somnia testnet (legacy)




  // Network configurations
  static const Map<String, Map<String, dynamic>> networkConfigs = {
    'somniaTestnet': {
      'name': 'Somnia Testnet',
      'chainId': 50312,
      'rpcUrl': 'https://dream-rpc.somnia.network',
      'nativeCurrency': 'STT',
      'blockExplorer': 'https://shannon-explorer.somnia.network',
      'contracts': somniaTestnetContracts,
    },
    
   
   
  };

  // Default network
  static const String defaultNetwork = 'somniaTestnet';

  // Get contract addresses for a specific network
  static Map<String, String> getContracts(String network) {
    final networkConfig = networkConfigs[network];
    if (networkConfig == null) {
      throw Exception('Unknown network: $network');
    }
    return Map<String, String>.from(networkConfig['contracts']);
  }

  // Get network configuration
  static Map<String, dynamic> getNetworkConfig(String network) {
    final networkConfig = networkConfigs[network];
    if (networkConfig == null) {
      throw Exception('Unknown network: $network');
    }
    return Map<String, dynamic>.from(networkConfig);
  }

  // Get contract address by name and network
  static String getContractAddress(String contractName, [String? network]) {
    network ??= defaultNetwork;
    final contracts = getContracts(network);
    final address = contracts[contractName];
    if (address == null) {
      throw Exception('Contract $contractName not found for network $network');
    }
    return address;
  }

  // Check if contracts are deployed for a network
  static bool areContractsDeployed(String network) {
    try {
      final contracts = getContracts(network);
      return contracts.values.every((address) => 
        address != '0x0000000000000000000000000000000000000000' && 
        address.isNotEmpty
      );
    } catch (e) {
      return false;
    }
  }

  // Get supported networks
  static List<String> getSupportedNetworks() {
    return networkConfigs.keys.toList();
  }

  // Get network name by chain ID
  static String? getNetworkByChainId(int chainId) {
    for (final entry in networkConfigs.entries) {
      if (entry.value['chainId'] == chainId) {
        return entry.key;
      }
    }
    return null;
  }
}