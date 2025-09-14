const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying contracts to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  if (balance < ethers.parseEther("0.1")) {
    console.log("⚠️  Warning: Low balance. You may need STT tokens for deployment.");
    console.log("💧 Get test tokens from: https://testnet.somnia.network/");
  }
  
  // Deploy EventFactory
  console.log("\n📋 Deploying EventFactory...");
  const EventFactory = await ethers.getContractFactory("EventFactory");
  const eventFactory = await EventFactory.deploy();
  await eventFactory.waitForDeployment();
  console.log("✅ EventFactory deployed to:", await eventFactory.getAddress());
  
  // Deploy BoundaryNFT
  console.log("\n📋 Deploying BoundaryNFT...");
  const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
  const boundaryNFT = await BoundaryNFT.deploy(await eventFactory.getAddress());
  await boundaryNFT.waitForDeployment();
  console.log("✅ BoundaryNFT deployed to:", await boundaryNFT.getAddress());
  
  // Deploy ClaimVerification
  console.log("\n📋 Deploying ClaimVerification...");
  const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
  const claimVerification = await ClaimVerification.deploy();
  await claimVerification.waitForDeployment();
  console.log("✅ ClaimVerification deployed to:", await claimVerification.getAddress());
  
  // Save deployment info
  const deploymentInfo = {
    network: "somniaTestnet",
    deployer: deployer.address,
    chainId: 50312,
    deployedAt: new Date().toISOString(),
    contracts: {
      EventFactory: await eventFactory.getAddress(),
      ClaimVerification: await claimVerification.getAddress(),
      BoundaryNFT: await boundaryNFT.getAddress(),
    },
    deploymentTx: {
      EventFactory: eventFactory.deploymentTransaction().hash,
      ClaimVerification: claimVerification.deploymentTransaction().hash,
      BoundaryNFT: boundaryNFT.deploymentTransaction().hash,
    },
    gasUsed: {
      EventFactory: eventFactory.deploymentTransaction().gasLimit?.toString() || "N/A",
      ClaimVerification: claimVerification.deploymentTransaction().gasLimit?.toString() || "N/A",
      BoundaryNFT: boundaryNFT.deploymentTransaction().gasLimit?.toString() || "N/A",
    },
    rpcUrl: "https://dream-rpc.somnia.network",
    explorerUrl: "https://shannon-explorer.somnia.network",
    currency: "STT",
    abis: {}
  };
  
  // Write deployment info to file
  const fs = require('fs');
  const path = require('path');
  
  const deploymentPath = path.join(__dirname, '../deployments/somnia-testnet-deployment-complete.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  
  console.log("\n🎉 Deployment completed successfully!");
  console.log("📄 Deployment info saved to:", deploymentPath);
  console.log("\n📋 Contract Addresses:");
  console.log("  EventFactory:", await eventFactory.getAddress());
  console.log("  BoundaryNFT:", await boundaryNFT.getAddress());
  console.log("  ClaimVerification:", await claimVerification.getAddress());
  console.log("\n🔗 Explorer: https://shannon-explorer.somnia.network");
  console.log("\n⚠️  IMPORTANT: Update the contract addresses in your Flutter app!");
  console.log("   - lib/shared/config/contracts_config.dart");
  console.log("   - lib/shared/contracts/abis/contract_addresses.json");
  console.log("   - lib/shared/services/web3_service.dart");
  console.log("   - lib/shared/services/smart_contract_service.dart");
  console.log("   - lib/shared/services/nft_service.dart");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });

