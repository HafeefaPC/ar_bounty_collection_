class WalletConnectConfig {
  // WalletConnect Project ID - Get this from https://cloud.walletconnect.com/
  static const String projectId = '77dc05c098aa26a200191c6f8cbd5194';
  
  // Relay URL for WalletConnect
  static const String relayUrl = 'wss://relay.walletconnect.com';
  
  // App metadata for WalletConnect
  static const String appName = 'TOKON AR Bounty Collection';
  static const String appDescription = 'AR-powered event participation and NFT collection app';
  static const String appUrl = 'https://tokon.app';
  static const String appIcon = 'https://tokon.app/icon.png';
  
  // Deep link configuration
  static const String nativeScheme = 'tokon://';
  static const String universalUrl = 'https://tokon.app';
  
  // Supported chains
  static const List<String> requiredChains = [
    'eip155:421614', // Avalanche Fuji testnet (primary)
  ];
  
  static const List<String> optionalChains = [
    'eip155:42161', // Arbitrum One (MAINNET) 
  ];
  
  // Required methods for the app
   static const List<String> requiredMethods = [
    'eth_sendTransaction',
    'eth_signTransaction',
    'eth_sign',
    'personal_sign',
    'eth_signTypedData',
    'eth_accounts',
    'eth_requestAccounts',
    'wallet_switchEthereumChain',
    'wallet_addEthereumChain',
  ];

  // Supported events
  static const List<String> requiredEvents = [
    'chainChanged',
    'accountsChanged',
  ];

  
 static const Map<String, dynamic> arbitrumSepoliaConfig = {
    'chainId': '421614',
    'name': 'Arbitrum Sepolia',
    'currency': 'ETH',
    'rpcUrl': 'https://sepolia-rollup.arbitrum.io/rpc',
    'explorerUrl': 'https://sepolia.arbiscan.io',
  };

  static const Map<String, dynamic> arbitrumOneConfig = {
    'chainId': '42161',
    'name': 'Arbitrum One',
    'currency': 'ETH',
    'rpcUrl': 'https://arb1.arbitrum.io/rpc',
    'explorerUrl': 'https://arbiscan.io',
  };
}
