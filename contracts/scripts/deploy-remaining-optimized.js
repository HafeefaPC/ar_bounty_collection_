const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying remaining contracts to Somnia Testnet (Optimized)...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  // Use existing EventFactory address
  const eventFactoryAddress = "0x1F2F71fa673a38CBC5848985A74713bDfB584578";
  console.log("🔗 Using existing EventFactory at:", eventFactoryAddress);
  
  // Deploy BoundaryNFT with gas optimization
  console.log("\n📋 Deploying BoundaryNFT (Optimized)...");
  try {
    const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
    
    // Estimate gas first
    const gasEstimate = await BoundaryNFT.getDeployTransaction(eventFactoryAddress).then(tx => 
      ethers.provider.estimateGas(tx)
    );
    console.log("📊 Estimated gas for BoundaryNFT:", gasEstimate.toString());
    
    // Deploy with optimized gas settings
    const boundaryNFT = await BoundaryNFT.deploy(eventFactoryAddress, {
      gasLimit: gasEstimate * 110n / 100n, // 10% buffer
    });
    await boundaryNFT.waitForDeployment();
    const boundaryNFTAddress = await boundaryNFT.getAddress();
    console.log("✅ BoundaryNFT deployed to:", boundaryNFTAddress);
    
    // Check remaining balance
    const newBalance = await ethers.provider.getBalance(deployer.address);
    console.log("💰 Remaining balance:", ethers.formatEther(newBalance), "STT");
    
    // Deploy ClaimVerification if we have enough balance
    if (newBalance > ethers.parseEther("0.1")) {
      console.log("\n📋 Deploying ClaimVerification...");
      try {
        const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
        
        // Estimate gas first
        const claimGasEstimate = await ClaimVerification.getDeployTransaction().then(tx => 
          ethers.provider.estimateGas(tx)
        );
        console.log("📊 Estimated gas for ClaimVerification:", claimGasEstimate.toString());
        
        const claimVerification = await ClaimVerification.deploy({
          gasLimit: claimGasEstimate * 110n / 100n, // 10% buffer
        });
        await claimVerification.waitForDeployment();
        const claimVerificationAddress = await claimVerification.getAddress();
        console.log("✅ ClaimVerification deployed to:", claimVerificationAddress);
        
        // Create complete deployment info
        const deploymentInfo = {
          network: "somniaTestnet",
          deployer: deployer.address,
          chainId: 50312,
          deployedAt: new Date().toISOString(),
          status: "Complete - All contracts deployed successfully",
          contracts: {
            EventFactory: eventFactoryAddress,
            BoundaryNFT: boundaryNFTAddress,
            ClaimVerification: claimVerificationAddress,
          },
          deploymentTx: {
            EventFactory: "Previous deployment",
            BoundaryNFT: boundaryNFT.deploymentTransaction().hash,
            ClaimVerification: claimVerification.deploymentTransaction().hash,
          },
          rpcUrl: "https://dream-rpc.somnia.network",
          explorerUrl: "https://shannon-explorer.somnia.network",
          currency: "STT",
          gasUsed: {
            BoundaryNFT: gasEstimate.toString(),
            ClaimVerification: claimGasEstimate.toString(),
          }
        };
        
        // Write deployment info to file
        const fs = require('fs');
        const path = require('path');
        
        const deploymentPath = path.join(__dirname, '../deployments/somnia-testnet-deployment-complete.json');
        fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
        
        console.log("\n🎉 All contracts deployed successfully!");
        console.log("📄 Deployment info saved to:", deploymentPath);
        console.log("\n📋 Final Contract Addresses:");
        console.log("  EventFactory:", eventFactoryAddress);
        console.log("  BoundaryNFT:", boundaryNFTAddress);
        console.log("  ClaimVerification:", claimVerificationAddress);
        
      } catch (claimError) {
        console.log("⚠️  ClaimVerification deployment failed:", claimError.message);
        
        // Create partial deployment info
        const partialInfo = {
          network: "somniaTestnet",
          deployer: deployer.address,
          chainId: 50312,
          deployedAt: new Date().toISOString(),
          status: "Partial - ClaimVerification pending",
          contracts: {
            EventFactory: eventFactoryAddress,
            BoundaryNFT: boundaryNFTAddress,
            ClaimVerification: "NOT_DEPLOYED - Insufficient balance after BoundaryNFT",
          },
          rpcUrl: "https://dream-rpc.somnia.network",
          explorerUrl: "https://shannon-explorer.somnia.network",
          currency: "STT",
        };
        
        const fs = require('fs');
        const path = require('path');
        const deploymentPath = path.join(__dirname, '../deployments/somnia-testnet-partial-deployment.json');
        fs.writeFileSync(deploymentPath, JSON.stringify(partialInfo, null, 2));
        
        console.log("\n⚠️  Partial deployment completed!");
        console.log("📋 Deployed Contracts:");
        console.log("  EventFactory:", eventFactoryAddress);
        console.log("  BoundaryNFT:", boundaryNFTAddress);
        console.log("  ClaimVerification: PENDING");
        console.log("\n💡 To deploy ClaimVerification later, get more STT and run:");
        console.log("   npx hardhat run scripts/deploy-claim-verification-only.js --network somniaTestnet");
      }
    } else {
      console.log("⚠️  Insufficient balance for ClaimVerification deployment");
      console.log("💡 Get more STT tokens from: https://testnet.somnia.network/");
    }
    
  } catch (error) {
    console.error("❌ BoundaryNFT deployment failed:", error.message);
    throw error;
  }
  
  // Final balance check
  const finalBalance = await ethers.provider.getBalance(deployer.address);
  console.log("\n💰 Final balance:", ethers.formatEther(finalBalance), "STT");
  
  console.log("\n🔗 Explorer: https://shannon-explorer.somnia.network");
  console.log("\n⚠️  IMPORTANT: Update the contract addresses in your Flutter app!");
  console.log("   - lib/shared/config/contracts_config.dart");
  console.log("   - lib/shared/contracts/abis/contract_addresses.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });