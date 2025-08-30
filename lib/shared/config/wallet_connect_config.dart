class WalletConnectConfig {
  // WalletConnect Project ID - Get this from https://cloud.walletconnect.com/
  static const String projectId = '2f5e1e2f5e1e2f5e1e2f5e1e2f5e1e2f';
  
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
    'eip155:43113', // Avalanche Fuji testnet (primary)
  ];
  
  static const List<String> optionalChains = [
    'eip155:1',     // Ethereum mainnet
    'eip155:137',   // Polygon
    'eip155:56',    // BSC
    'eip155:43114', // Avalanche mainnet
  ];
  
  // Required methods for the app
  static const List<String> requiredMethods = [
    'eth_sendTransaction',
    'eth_signTransaction',
    'eth_sign',
    'personal_sign',
    'eth_signTypedData',
  ];
  
  // Required events
  static const List<String> requiredEvents = [
    'chainChanged',
    'accountsChanged',
  ];
  
  // Core mobile specific configuration
  static const Map<String, dynamic> coreMobileConfig = {
    'name': 'Core Mobile',
    'description': 'Connect with Core mobile wallet via Wallet Connect',
    'icon': 'https://core.app/icon.png',
    'url': 'https://core.app',
  };
}
