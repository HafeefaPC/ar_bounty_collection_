const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying remaining contract to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  // Deploy ClaimVerification
  console.log("\n📋 Deploying ClaimVerification...");
  const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
  const claimVerification = await ClaimVerification.deploy();
  await claimVerification.waitForDeployment();
  console.log("✅ ClaimVerification deployed to:", await claimVerification.getAddress());
  
  // Update deployment info with all contracts
  const deploymentInfo = {
    network: "somniaTestnet",
    deployer: deployer.address,
    chainId: 50312,
    deployedAt: new Date().toISOString(),
    contracts: {
      EventFactory: "0xf51E6200829Ae27f6374662De4b1239745A59f0E", // From previous deployment
      BoundaryNFT: "0xf7bECe16CC3182C1890eC722cbd0E29aC61F888D", // From previous deployment
      ClaimVerification: await claimVerification.getAddress(),
    },
    deploymentTx: {
      ClaimVerification: claimVerification.deploymentTransaction().hash,
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
  console.log("\n📋 All Contract Addresses:");
  console.log("  EventFactory:", "0xf51E6200829Ae27f6374662De4b1239745A59f0E");
  console.log("  BoundaryNFT:", "0xf7bECe16CC3182C1890eC722cbd0E29aC61F888D");
  console.log("  ClaimVerification:", await claimVerification.getAddress());
  console.log("\n🔗 Explorer: https://shannon-explorer.somnia.network");
  console.log("\n⚠️  IMPORTANT: Update the contract addresses in your Flutter app!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });