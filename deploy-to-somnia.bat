@echo off
REM 🚀 Somnia Testnet Deployment Script for Windows
REM This script deploys your contracts to Somnia Testnet

echo 🚀 Starting Somnia Testnet Deployment...
echo ========================================

REM Check if we're in the right directory
if not exist "contracts\package.json" (
    echo ❌ Error: Please run this script from the project root directory
    pause
    exit /b 1
)

REM Navigate to contracts directory
cd contracts

echo 📦 Installing dependencies...
call npm install

echo 🔧 Compiling contracts...
call npx hardhat compile

echo 🚀 Deploying to Somnia Testnet...
echo Using wallet: 0x1570a891556eF3A181658EaD5AA409B21C7Cd42d
echo Network: Somnia Testnet (Chain ID: 50312)
echo RPC: https://dream-rpc.somnia.network
echo.

REM Deploy contracts
call npx hardhat run scripts/deploy.js --network somniaTestnet

echo.
echo ✅ Deployment completed!
echo.
echo 📋 Next Steps:
echo 1. Copy the deployed contract addresses from the output above
echo 2. Update lib/shared/config/contracts_config.dart with the new addresses
echo 3. Get STT tokens from https://testnet.somnia.network/
echo 4. Test your Flutter app on Somnia Testnet
echo.
echo 🔗 Explorer: https://shannon-explorer.somnia.network/
echo 💧 Faucet: https://testnet.somnia.network/
echo.
pause
