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
    'eip155:50312', // Somnia Testnet (primary)
  ];
  
  static const List<String> optionalChains = [
    'eip155:421614', // Arbitrum Sepolia Testnet (legacy)
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

  
 static const Map<String, dynamic> somniaTestnetConfig = {
    'chainId': '50312',
    'name': 'Somnia Testnet',
    'currency': 'STT',
    'rpcUrl': 'https://dream-rpc.somnia.network',
    'explorerUrl': 'https://shannon-explorer.somnia.network',
  };

 
}
