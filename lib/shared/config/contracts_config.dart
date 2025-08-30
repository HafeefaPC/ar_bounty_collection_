class ContractsConfig {
  // Contract addresses for Avalanche Fuji testnet
  static const Map<String, String> fujiContracts = {
    'EventFactory': '0x1234567890123456789012345678901234567890',
    'BoundaryNFT': '0x2345678901234567890123456789012345678901',
    'ClaimVerification': '0x3456789012345678901234567890123456789012',
  };

  // Contract addresses for Avalanche mainnet (for future use)
  static const Map<String, String> avalancheContracts = {
    'EventFactory': '0x0000000000000000000000000000000000000000',
    'BoundaryNFT': '0x0000000000000000000000000000000000000000',
    'ClaimVerification': '0x0000000000000000000000000000000000000000',
  };

  // Network configurations
  static const Map<String, Map<String, dynamic>> networkConfigs = {
    'fuji': {
      'name': 'Avalanche Fuji Testnet',
      'chainId': 43113,
      'rpcUrl': 'https://api.avax-test.network/ext/bc/C/rpc',
      'nativeCurrency': 'AVAX',
      'blockExplorer': 'https://testnet.snowtrace.io',
      'contracts': fujiContracts,
    },
    'avalanche': {
      'name': 'Avalanche Mainnet',
      'chainId': 43114,
      'rpcUrl': 'https://api.avax.network/ext/bc/C/rpc',
      'nativeCurrency': 'AVAX',
      'blockExplorer': 'https://snowtrace.io',
      'contracts': avalancheContracts,
    },
  };

  // Default network
  static const String defaultNetwork = 'fuji';

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