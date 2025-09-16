# ✅ **Somnia Testnet Deployment Checklist**

## 🚀 **Pre-Deployment Setup**

### **1. Environment Preparation**
- [ ] **Wallet Address**: `0x1570a891556eF3A181658EaD5AA409B21C7Cd42d` ✅
- [ ] **Private Key**: `3009eef2ac66c793320e1ee0cecdd2aec069aceb0f161b0b13e88857b9a7cbf7` ✅
- [ ] **Network**: Somnia Testnet (Chain ID: 50312) ✅
- [ ] **RPC URL**: `https://dream-rpc.somnia.network` ✅
- [ ] **Explorer**: `https://shannon-explorer.somnia.network/` ✅

### **2. Get Testnet Tokens**
- [ ] Visit [Somnia Testnet Faucet](https://testnet.somnia.network/)
- [ ] Connect wallet `0x1570a891556eF3A181658EaD5AA409B21C7Cd42d`
- [ ] Request STT tokens for gas fees
- [ ] Verify balance shows STT tokens

## 🔧 **Contract Deployment**

### **3. Deploy Smart Contracts**

**Option A: Using the provided script (Recommended)**
```bash
# Run the deployment script
./deploy-to-somnia.bat
```

**Option B: Manual deployment**
```bash
cd contracts
npm install
npx hardhat compile
npx hardhat run scripts/deploy-somnia-testnet.js --network somniaTestnet
```

### **4. Record Contract Addresses**
After successful deployment, copy these addresses:

- [ ] **EventFactory**: `0x[ADDRESS]`
- [ ] **BoundaryNFT**: `0x[ADDRESS]`
- [ ] **ClaimVerification**: `0x[ADDRESS]`

## 📱 **Flutter App Configuration**

### **5. Update Contract Addresses**
Update `lib/shared/config/contracts_config.dart`:

```dart
static const Map<String, String> somniaTestnetContracts = {
  'EventFactory': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual
  'BoundaryNFT': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual
  'ClaimVerification': '0x[YOUR_DEPLOYED_ADDRESS]', // Replace with actual
};
```

### **6. Verify Network Configuration**
Confirm these settings in `contracts_config.dart`:

- [ ] **Default Network**: `somniaTestnet` ✅
- [ ] **Chain ID**: `50312` ✅
- [ ] **RPC URL**: `https://dream-rpc.somnia.network` ✅
- [ ] **Currency**: `STT` ✅
- [ ] **Explorer**: `https://shannon-explorer.somnia.network/` ✅

## 🧪 **Testing Phase**

### **7. Wallet Connection Test**
- [ ] Open Flutter app
- [ ] Connect wallet (should auto-switch to Somnia Testnet)
- [ ] Verify chain ID shows `50312`
- [ ] Verify currency shows `STT`

### **8. Event Creation Test**
- [ ] Create a test event
- [ ] Verify transaction appears on [Shannon Explorer](https://shannon-explorer.somnia.network/)
- [ ] Check transaction uses STT for gas fees
- [ ] Verify event is created successfully

### **9. Event Joining Test**
- [ ] Join the created event
- [ ] Verify NFT minting works
- [ ] Check NFT appears in wallet
- [ ] Verify all AR/VR features work

## 🔍 **Verification Checklist**

### **10. Network Verification**
- [ ] **Chain ID**: 50312 (Somnia Testnet)
- [ ] **Currency**: STT (Somnia Test Token)
- [ ] **Gas Price**: ~2 gwei
- [ ] **Explorer**: Shannon Explorer working
- [ ] **RPC**: Connection stable

### **11. Functionality Verification**
- [ ] **Wallet Connection**: Works with Somnia Testnet
- [ ] **Event Creation**: Creates events on blockchain
- [ ] **Event Joining**: Users can join events
- [ ] **NFT Minting**: NFTs are minted correctly
- [ ] **AR Features**: All AR functionality works
- [ ] **Transaction History**: Visible on explorer

### **12. Error Handling Verification**
- [ ] **Wrong Network**: App prompts to switch to Somnia Testnet
- [ ] **Insufficient STT**: Clear error message with faucet link
- [ ] **Transaction Failures**: Proper error handling
- [ ] **Network Issues**: Graceful degradation

## 📊 **Performance Monitoring**

### **13. Gas Cost Analysis**
- [ ] **Event Creation**: ~0.004 STT
- [ ] **Event Joining**: ~0.002 STT
- [ ] **NFT Minting**: ~0.001 STT
- [ ] **Total per User**: ~0.007 STT

### **14. Network Performance**
- [ ] **Transaction Speed**: < 30 seconds
- [ ] **Block Confirmation**: < 2 minutes
- [ ] **App Responsiveness**: Smooth UI
- [ ] **Error Rate**: < 5%

## 🚀 **Post-Deployment**

### **15. Documentation Updates**
- [ ] Update README with Somnia Testnet info
- [ ] Update deployment guide
- [ ] Document any issues found
- [ ] Create user guide for Somnia Testnet

### **16. Monitoring Setup**
- [ ] Monitor contract interactions
- [ ] Track gas usage patterns
- [ ] Monitor error rates
- [ ] Set up alerts for failures

## 🎯 **Success Criteria**

### **17. Migration Success**
- [ ] **All functionality works** on Somnia Testnet
- [ ] **No regression** from Arbitrum Sepolia version
- [ ] **User experience** is identical
- [ ] **Performance** is acceptable
- [ ] **Costs** are reasonable

### **18. Ready for Production**
- [ ] **Thoroughly tested** on Somnia Testnet
- [ ] **User feedback** collected
- [ ] **Performance optimized**
- [ ] **Documentation complete**
- [ ] **Team trained** on new network

---

## 📞 **Support Resources**

- **Somnia Documentation**: [https://docs.somnia.network/developer/network-info](https://docs.somnia.network/developer/network-info)
- **Testnet Faucet**: [https://testnet.somnia.network/](https://testnet.somnia.network/)
- **Explorer**: [https://shannon-explorer.somnia.network/](https://shannon-explorer.somnia.network/)
- **Discord**: Join Somnia Discord for developer support

---

**Status: 🚀 READY FOR DEPLOYMENT**

Your project is fully configured for Somnia Testnet migration!


