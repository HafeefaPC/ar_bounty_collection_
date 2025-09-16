class ContractsConfig {
  // Contract addresses for Somnia Testnet (DEPLOYED ✅)
  static const Map<String, String> somniaTestnetContracts = {
    'EventFactory': '0xf9CF13b978A71113992De2A0373fE76d3B64B6dc',
    'BoundaryNFT': '0xbac9dBf16337cAC4b8aBAef3941615e57dB37073',
    'ClaimVerification': '0xB6Ba7b7501D5F6D71213B0f75f7b8a9eFc3e8507',
  };

  // Contract addresses for Somnia Mainnet (for future use)
  static const Map<String, String> somniaMainnetContracts = {
    'EventFactory': '0x0000000000000000000000000000000000000000',
    'BoundaryNFT': '0x0000000000000000000000000000000000000000',
    'ClaimVerification': '0x0000000000000000000000000000000000000000',
  };

  // Contract addresses for Arbitrum Sepolia testnet (legacy)
  static const Map<String, String> arbitrumSepoliaContracts = {
    'EventFactory': '0xF1f37ee2187da8807AFeF6bc31526bFfA6f43f1d',
    'BoundaryNFT': '0xC585B8e492210FbEDbFE8BB353366DC968c9F77A',
    'ClaimVerification': '0xed4468D5f1247dfD6BD19Dd54BD91278B647d6Aa',
  };

  // Contract addresses for Avalanche Fuji testnet (legacy)
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
    'somniaTestnet': {
      'name': 'Somnia Testnet',
      'chainId': 50312,
      'rpcUrl': 'https://dream-rpc.somnia.network',
      'nativeCurrency': 'STT',
      'blockExplorer': 'https://shannon-explorer.somnia.network/',
      'contracts': somniaTestnetContracts,
    },
    'somniaMainnet': {
      'name': 'Somnia Mainnet',
      'chainId': 5031,
      'rpcUrl': 'https://api.infra.mainnet.somnia.network/',
      'nativeCurrency': 'SOMI',
      'blockExplorer': 'https://explorer.somnia.network',
      'contracts': somniaMainnetContracts,
    },
    'arbitrumSepolia': {
      'name': 'Arbitrum Sepolia Testnet',
      'chainId': 421614,
      'rpcUrl': 'https://sepolia-rollup.arbitrum.io/rpc',
      'nativeCurrency': 'ETH',
      'blockExplorer': 'https://sepolia.arbiscan.io',
      'contracts': arbitrumSepoliaContracts,
    },
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