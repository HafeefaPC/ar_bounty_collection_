const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying ClaimVerification only to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("📝 Deploying contracts with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  if (balance < ethers.parseEther("0.05")) {
    throw new Error("Insufficient balance for ClaimVerification deployment. Need at least 0.05 STT.");
  }
  
  // Deploy ClaimVerification
  console.log("\n📋 Deploying ClaimVerification...");
  const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
  
  // Estimate gas first
  const gasEstimate = await ClaimVerification.getDeployTransaction().then(tx => 
    ethers.provider.estimateGas(tx)
  );
  console.log("📊 Estimated gas:", gasEstimate.toString());
  
  const claimVerification = await ClaimVerification.deploy({
    gasLimit: gasEstimate * 110n / 100n, // 10% buffer
  });
  await claimVerification.waitForDeployment();
  const claimVerificationAddress = await claimVerification.getAddress();
  console.log("✅ ClaimVerification deployed to:", claimVerificationAddress);
  
  // Update deployment info with complete addresses
  const deploymentInfo = {
    network: "somniaTestnet",
    deployer: deployer.address,
    chainId: 50312,
    deployedAt: new Date().toISOString(),
    status: "Complete - All contracts deployed successfully",
    contracts: {
      EventFactory: "0x1F2F71fa673a38CBC5848985A74713bDfB584578",
      BoundaryNFT: "0xf7bECe16CC3182C1890eC722cbd0E29aC61F888D", // From previous partial deployment
      ClaimVerification: claimVerificationAddress,
    },
    deploymentTx: {
      EventFactory: "Previous deployment",
      BoundaryNFT: "Previous deployment", 
      ClaimVerification: claimVerification.deploymentTransaction().hash,
    },
    rpcUrl: "https://dream-rpc.somnia.network",
    explorerUrl: "https://shannon-explorer.somnia.network",
    currency: "STT",
    gasUsed: {
      ClaimVerification: gasEstimate.toString(),
    }
  };
  
  // Write deployment info to file
  const fs = require('fs');
  const path = require('path');
  
  const deploymentPath = path.join(__dirname, '../deployments/somnia-testnet-deployment-complete.json');
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  
  console.log("\n🎉 ClaimVerification deployment completed!");
  console.log("📄 Deployment info saved to:", deploymentPath);
  console.log("\n📋 All Contract Addresses:");
  console.log("  EventFactory:", "0x1F2F71fa673a38CBC5848985A74713bDfB584578");
  console.log("  BoundaryNFT:", "0xf7bECe16CC3182C1890eC722cbd0E29aC61F888D");
  console.log("  ClaimVerification:", claimVerificationAddress);
  
  // Final balance check
  const finalBalance = await ethers.provider.getBalance(deployer.address);
  console.log("\n💰 Final balance:", ethers.formatEther(finalBalance), "STT");
  
  console.log("\n🔗 Explorer: https://shannon-explorer.somnia.network");
  console.log("\n⚠️  IMPORTANT: Update the contract addresses in your Flutter app!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });