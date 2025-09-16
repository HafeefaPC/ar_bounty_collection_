# 🚀 **Complete Somnia Testnet Migration Guide**

## 📋 **Migration Overview**

This guide will help you migrate your AR Bounty Collection project from **Arbitrum Sepolia** to **Somnia Testnet**. All functionality remains the same - only the network configuration changes.

## 🔧 **Step 1: Deploy Contracts to Somnia Testnet**

### **1.1 Update Environment Variables**

Create a `.env` file in the `contracts/` directory:

```bash
# .env file for Somnia Testnet deployment
PRIVATE_KEY=3009eef2ac66c793320e1ee0cecdd2aec069aceb0f161b0b13e88857b9a7cbf7
SOMNIA_TESTNET_RPC_URL=https://dream-rpc.somnia.network
```

### **1.2 Deploy Contracts**

```bash
# Navigate to contracts directory
cd contracts

# Install dependencies (if not already done)
npm install

# Deploy to Somnia Testnet
npx hardhat run scripts/deploy-somnia-testnet.js --network somniaTestnet
```

### **1.3 Expected Output**

After successful deployment, you should see:

```
🎉 Deployment completed successfully!
📄 Deployment data saved to: contracts/deployments/somnia-testnet-deployment.json

📋 DEPLOYMENT SUMMARY:
==================================================
🌐 Network: Somnia Testnet (Chain ID: 50312)
👤 Deployer: 0x1570a891556eF3A181658EaD5AA409B21C7Cd42d
⏰ Time: 2024-01-XX...

📦 CONTRACT ADDRESSES:
  EventFactory:     0x[ADDRESS]
  BoundaryNFT:      0x[ADDRESS]
  ClaimVerification: 0x[ADDRESS]

🔗 EXPLORER LINKS:
  EventFactory:     https://shannon-explorer.somnia.network/address/0x[ADDRESS]
  BoundaryNFT:      https://shannon-explorer.somnia.network/address/0x[ADDRESS]
  ClaimVerification: https://shannon-explorer.somnia.network/address/0x[ADDRESS]
```

### **1.4 Update Flutter App Configuration**

After deployment, update the contract addresses in `lib/shared/config/contracts_config.dart`:

```dart
// Replace the placeholder addresses with your deployed addresses
static const Map<String, String> somniaTestnetContracts = {
  'EventFactory': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual address
  'BoundaryNFT': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual address
  'ClaimVerification': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual address
};
```

## 🌐 **Step 2: Network Configuration Updates**

### **2.1 Updated Network Details**

| Parameter | Somnia Testnet | Arbitrum Sepolia (Old) |
|-----------|----------------|------------------------|
| **Chain ID** | `50312` | `421614` |
| **RPC URL** | `https://dream-rpc.somnia.network` | `https://sepolia-rollup.arbitrum.io/rpc` |
| **Explorer** | `https://shannon-explorer.somnia.network/` | `https://sepolia.arbiscan.io` |
| **Currency** | `STT` | `ETH` |
| **Symbol** | `STT` | `ETH` |

### **2.2 Files Updated**

✅ **Contract Configuration:**
- `contracts/hardhat.config.js` - Added Somnia Testnet network config
- `contracts/scripts/deploy-somnia-testnet.js` - New deployment script

✅ **Flutter App Configuration:**
- `lib/shared/config/contracts_config.dart` - Updated default network to Somnia Testnet
- `lib/shared/config/wallet_connect_config.dart` - Updated supported chains
- `lib/shared/providers/reown_provider.dart` - Updated wallet connection logic

## 🧪 **Step 3: Testing the Migration**

### **3.1 Get Testnet STT Tokens**

1. Visit the [Somnia Testnet Faucet](https://testnet.somnia.network/)
2. Connect your wallet (`0x1570a891556eF3A181658EaD5AA409B21C7Cd42d`)
3. Request STT tokens for gas fees

### **3.2 Test Contract Deployment**

```bash
# Test deployment (dry run)
npx hardhat run scripts/deploy-somnia-testnet.js --network somniaTestnet --dry-run

# Verify contracts on explorer
# Check: https://shannon-explorer.somnia.network/address/[YOUR_CONTRACT_ADDRESS]
```

### **3.3 Test Flutter App**

1. **Connect Wallet:**
   - Open the Flutter app
   - Connect wallet (should automatically switch to Somnia Testnet)
   - Verify chain ID shows `50312`

2. **Test Event Creation:**
   - Create a test event
   - Verify transaction appears on [Shannon Explorer](https://shannon-explorer.somnia.network/)
   - Check transaction uses STT for gas fees

3. **Test Event Joining:**
   - Join the created event
   - Verify NFT minting works correctly

## 🔍 **Step 4: Debugging & Verification**

### **4.1 Common Issues & Solutions**

| Issue | Solution |
|-------|----------|
| **"Insufficient STT"** | Get more STT from [faucet](https://testnet.somnia.network/) |
| **"Wrong Network"** | App should auto-switch, but manually switch to Somnia Testnet |
| **"Contract Not Found"** | Verify contract addresses are updated in `contracts_config.dart` |
| **"Transaction Failed"** | Check gas price (2 gwei recommended for Somnia Testnet) |

### **4.2 Debug Logs to Watch**

```dart
// Look for these logs in Flutter console:
✅ "Successfully set Somnia Testnet as default chain"
✅ "Wallet connected: [ADDRESS] on chain eip155:50312"
✅ "Event creation transaction sent: [TX_HASH]"
```

### **4.3 Verification Checklist**

- [ ] Contracts deployed successfully to Somnia Testnet
- [ ] Contract addresses updated in Flutter app
- [ ] Wallet connects to Somnia Testnet (Chain ID: 50312)
- [ ] Event creation works with STT gas fees
- [ ] Transactions appear on Shannon Explorer
- [ ] All functionality works as before (just on different network)

## 📊 **Step 5: Network Comparison**

### **5.1 Gas Costs**

| Network | Gas Price | Gas Limit | Estimated Cost |
|---------|-----------|-----------|----------------|
| **Somnia Testnet** | 2 gwei | 2,000,000 | ~0.004 STT |
| **Arbitrum Sepolia** | 0.1 gwei | 1,500,000 | ~0.00015 ETH |

### **5.2 Performance**

- **Somnia Testnet**: Fast block times, low latency
- **Arbitrum Sepolia**: Optimized for rollup efficiency

## 🚀 **Step 6: Production Deployment**

### **6.1 Mainnet Migration (Future)**

When ready for mainnet:

1. Update `contracts_config.dart` to use `somniaMainnet` as default
2. Deploy contracts to Somnia Mainnet (Chain ID: 5031)
3. Update contract addresses
4. Switch from STT to SOMI tokens

### **6.2 Environment Variables for Production**

```bash
# Production .env
PRIVATE_KEY=your_production_private_key
SOMNIA_MAINNET_RPC_URL=https://api.infra.mainnet.somnia.network/
```

## 📝 **Step 7: Migration Summary**

### **What Changed:**
- ✅ Network: Arbitrum Sepolia → Somnia Testnet
- ✅ Chain ID: 421614 → 50312
- ✅ Currency: ETH → STT
- ✅ Explorer: Arbiscan → Shannon Explorer
- ✅ RPC: Arbitrum → Somnia

### **What Stayed the Same:**
- ✅ All smart contract functionality
- ✅ All Flutter app features
- ✅ All user interactions
- ✅ All AR/VR capabilities
- ✅ All NFT minting logic

## 🎯 **Next Steps After Migration**

1. **Test thoroughly** on Somnia Testnet
2. **Get user feedback** on the new network
3. **Monitor gas costs** and optimize if needed
4. **Plan mainnet deployment** when ready
5. **Update documentation** with new network details

---

## 📞 **Support & Resources**

- **Somnia Documentation**: [https://docs.somnia.network/developer/network-info](https://docs.somnia.network/developer/network-info)
- **Testnet Faucet**: [https://testnet.somnia.network/](https://testnet.somnia.network/)
- **Explorer**: [https://shannon-explorer.somnia.network/](https://shannon-explorer.somnia.network/)
- **Discord**: Join Somnia Discord for developer support

---

**Status: ✅ READY FOR DEPLOYMENT**

Your project is now fully configured for Somnia Testnet migration!


