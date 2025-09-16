const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting deployment to Somnia Testnet...");
  console.log("📋 Network Configuration:");
  console.log("  - Network: Somnia Testnet");
  console.log("  - Chain ID: 50312");
  console.log("  - RPC URL: https://dream-rpc.somnia.network");
  console.log("  - Explorer: https://shannon-explorer.somnia.network/");
  console.log("  - Currency: STT");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("👤 Deploying contracts with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.utils.formatEther(balance), "STT");
  
  if (balance.lt(ethers.utils.parseEther("0.1"))) {
    console.log("⚠️  WARNING: Low balance! You may need more STT for gas fees.");
    console.log("💧 Get testnet STT from: https://testnet.somnia.network/");
  }

  const deploymentResults = {};

  try {
    // 1. Deploy EventFactory
    console.log("\n📦 Deploying EventFactory contract...");
    const EventFactory = await ethers.getContractFactory("EventFactory");
    const eventFactory = await EventFactory.deploy();
    await eventFactory.deployed();
    
    console.log("✅ EventFactory deployed to:", eventFactory.address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + eventFactory.address);
    
    deploymentResults.EventFactory = {
      address: eventFactory.address,
      transactionHash: eventFactory.deployTransaction.hash,
      blockNumber: eventFactory.deployTransaction.blockNumber
    };

    // 2. Deploy BoundaryNFT
    console.log("\n📦 Deploying BoundaryNFT contract...");
    const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
    const boundaryNFT = await BoundaryNFT.deploy();
    await boundaryNFT.deployed();
    
    console.log("✅ BoundaryNFT deployed to:", boundaryNFT.address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + boundaryNFT.address);
    
    deploymentResults.BoundaryNFT = {
      address: boundaryNFT.address,
      transactionHash: boundaryNFT.deployTransaction.hash,
      blockNumber: boundaryNFT.deployTransaction.blockNumber
    };

    // 3. Deploy ClaimVerification
    console.log("\n📦 Deploying ClaimVerification contract...");
    const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
    const claimVerification = await ClaimVerification.deploy();
    await claimVerification.deployed();
    
    console.log("✅ ClaimVerification deployed to:", claimVerification.address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + claimVerification.address);
    
    deploymentResults.ClaimVerification = {
      address: claimVerification.address,
      transactionHash: claimVerification.deployTransaction.hash,
      blockNumber: claimVerification.deployTransaction.blockNumber
    };

    // 4. Set up contract relationships
    console.log("\n🔗 Setting up contract relationships...");
    
    // Set BoundaryNFT address in EventFactory
    console.log("  - Setting BoundaryNFT address in EventFactory...");
    const setBoundaryNFTTx = await eventFactory.setBoundaryNFT(boundaryNFT.address);
    await setBoundaryNFTTx.wait();
    console.log("  ✅ BoundaryNFT address set in EventFactory");
    
    // Set ClaimVerification address in EventFactory
    console.log("  - Setting ClaimVerification address in EventFactory...");
    const setClaimVerificationTx = await eventFactory.setClaimVerification(claimVerification.address);
    await setClaimVerificationTx.wait();
    console.log("  ✅ ClaimVerification address set in EventFactory");

    // 5. Save deployment results
    const fs = require('fs');
    const path = require('path');
    
    const deploymentData = {
      network: "somniaTestnet",
      chainId: 50312,
      deployer: deployer.address,
      deploymentTime: new Date().toISOString(),
      contracts: deploymentResults
    };
    
    const deploymentPath = path.join(__dirname, '..', 'deployments', 'somnia-testnet-deployment.json');
    fs.writeFileSync(deploymentPath, JSON.stringify(deploymentData, null, 2));
    
    console.log("\n🎉 Deployment completed successfully!");
    console.log("📄 Deployment data saved to:", deploymentPath);
    
    // 6. Display summary
    console.log("\n📋 DEPLOYMENT SUMMARY:");
    console.log("=" .repeat(50));
    console.log("🌐 Network: Somnia Testnet (Chain ID: 50312)");
    console.log("👤 Deployer:", deployer.address);
    console.log("⏰ Time:", new Date().toISOString());
    console.log("");
    console.log("📦 CONTRACT ADDRESSES:");
    console.log("  EventFactory:     " + eventFactory.address);
    console.log("  BoundaryNFT:      " + boundaryNFT.address);
    console.log("  ClaimVerification: " + claimVerification.address);
    console.log("");
    console.log("🔗 EXPLORER LINKS:");
    console.log("  EventFactory:     https://shannon-explorer.somnia.network/address/" + eventFactory.address);
    console.log("  BoundaryNFT:      https://shannon-explorer.somnia.network/address/" + boundaryNFT.address);
    console.log("  ClaimVerification: https://shannon-explorer.somnia.network/address/" + claimVerification.address);
    console.log("");
    console.log("💡 NEXT STEPS:");
    console.log("  1. Update your Flutter app configuration with these addresses");
    console.log("  2. Test contract interactions on Somnia Testnet");
    console.log("  3. Get STT from faucet if needed: https://testnet.somnia.network/");
    console.log("=" .repeat(50));

  } catch (error) {
    console.error("❌ Deployment failed:", error);
    console.error("🔍 Error details:", error.message);
    
    if (error.message.includes("insufficient funds")) {
      console.log("💡 Solution: Get more STT from the faucet: https://testnet.somnia.network/");
    } else if (error.message.includes("network")) {
      console.log("💡 Solution: Check your RPC connection to Somnia Testnet");
    } else if (error.message.includes("gas")) {
      console.log("💡 Solution: Try increasing gas limit or gas price");
    }
    
    process.exit(1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });





