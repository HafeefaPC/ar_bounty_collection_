#!/bin/bash

# 🚀 Somnia Testnet Deployment Script
# This script deploys your contracts to Somnia Testnet

echo "🚀 Starting Somnia Testnet Deployment..."
echo "========================================"

# Check if we're in the right directory
if [ ! -f "contracts/package.json" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Navigate to contracts directory
cd contracts

echo "📦 Installing dependencies..."
npm install

echo "🔧 Compiling contracts..."
npx hardhat compile

echo "🚀 Deploying to Somnia Testnet..."
echo "Using wallet: 0x1570a891556eF3A181658EaD5AA409B21C7Cd42d"
echo "Network: Somnia Testnet (Chain ID: 50312)"
echo "RPC: https://dream-rpc.somnia.network"
echo ""

# Deploy contracts
npx hardhat run scripts/deploy-somnia-testnet.js --network somniaTestnet

echo ""
echo "✅ Deployment completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Copy the deployed contract addresses from the output above"
echo "2. Update lib/shared/config/contracts_config.dart with the new addresses"
echo "3. Get STT tokens from https://testnet.somnia.network/"
echo "4. Test your Flutter app on Somnia Testnet"
echo ""
echo "🔗 Explorer: https://shannon-explorer.somnia.network/"
echo "💧 Faucet: https://testnet.somnia.network/"


