# Migration to Somnia Testnet

This document outlines the changes made to migrate the AR Bounty Collection app from Arbitrum Sepolia to Somnia Testnet.

## Network Configuration

### Somnia Testnet Details
- **Chain ID**: 50312
- **RPC URL**: https://dream-rpc.somnia.network
- **Explorer**: https://shannon-explorer.somnia.network
- **Currency**: STT (Somnia Test Token)
- **Faucet**: https://testnet.somnia.network/

### Contract Deployment

To deploy contracts to Somnia Testnet:

1. **Get Test Tokens**:
   - Visit: https://testnet.somnia.network/
   - Or use Thirdweb Faucet: https://thirdweb.com/somnia-shannon-testnet
   - Or Google Cloud Faucet: https://cloud.google.com/application/web3/faucet/somnia/shannon

2. **Deploy Contracts**:
   ```bash
   cd contracts
   npm run deploy:somnia-testnet
   ```

3. **Update Contract Addresses**:
   After deployment, update the following files with the new contract addresses:
   - `lib/shared/config/contracts_config.dart`
   - `lib/shared/contracts/abis/contract_addresses.json`
   - `lib/shared/services/web3_service.dart`
   - `lib/shared/services/smart_contract_service.dart`
   - `lib/shared/services/nft_service.dart`

## Files Modified

### Contract Configuration
- `contracts/hardhat.config.js` - Updated network configuration
- `contracts/package.json` - Updated deployment scripts
- `contracts/scripts/deploy-somnia.js` - New deployment script

### Flutter App Configuration
- `lib/shared/config/contracts_config.dart` - Updated network configs
- `lib/shared/config/wallet_connect_config.dart` - Updated supported chains
- `lib/shared/contracts/abis/contract_addresses.json` - Updated contract addresses
- `lib/shared/services/web3_service.dart` - Updated RPC and chain ID
- `lib/shared/services/smart_contract_service.dart` - Updated network settings
- `lib/shared/services/nft_service.dart` - Updated network configuration
- `lib/shared/services/simple_nft_service.dart` - Updated all network references
- `lib/shared/providers/reown_provider.dart` - Updated wallet connection settings
- `lib/features/wallet/wallet_connection_screen.dart` - Updated UI text and validation
- `lib/features/event_creation/event_creation_screen.dart` - Updated chain validation
- `lib/shared/widgets/wallet_connection_wrapper.dart` - Updated network display

## Key Changes

1. **Chain ID**: Changed from 421614 (Arbitrum Sepolia) to 50312 (Somnia Testnet)
2. **RPC URL**: Changed from `https://sepolia-rollup.arbitrum.io/rpc` to `https://dream-rpc.somnia.network`
3. **Explorer**: Changed from `https://sepolia.arbiscan.io` to `https://shannon-explorer.somnia.network`
4. **Currency**: Changed from ETH to STT (Somnia Test Token)
5. **Contract Addresses**: Reset to placeholder addresses (to be updated after deployment)

## Testing

After deployment and updating contract addresses:

1. **Test Wallet Connection**: Ensure wallet connects to Somnia Testnet
2. **Test Event Creation**: Verify events can be created on the new network
3. **Test NFT Minting**: Verify NFTs can be minted and claimed
4. **Test Network Switching**: Ensure automatic network switching works

## Troubleshooting

### Common Issues

1. **"Wrong Network" Error**: 
   - Ensure wallet is connected to Somnia Testnet (Chain ID: 50312)
   - Check if network is added to wallet

2. **"Insufficient Funds" Error**:
   - Get STT tokens from the faucet
   - Ensure wallet has enough STT for gas fees

3. **Contract Not Found Error**:
   - Verify contract addresses are updated in all configuration files
   - Ensure contracts are deployed to Somnia Testnet

### Adding Somnia Testnet to Wallet

**Network Details**:
- Network Name: Somnia Testnet
- RPC URL: https://dream-rpc.somnia.network
- Chain ID: 50312
- Currency Symbol: STT
- Block Explorer: https://shannon-explorer.somnia.network

**Quick Add**: Visit https://testnet.somnia.network/ and click "Add to Wallet"

## Support

- **Somnia Discord**: Join the #dev-chat channel
- **Documentation**: https://docs.somnia.network/
- **Faucet**: https://testnet.somnia.network/

