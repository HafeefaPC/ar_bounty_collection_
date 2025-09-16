const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying minimal contract to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("👤 Deploying with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  try {
    // Deploy without any gas options first
    console.log("\n📦 Deploying MinimalContract...");
    const MinimalContract = await ethers.getContractFactory("MinimalContract");
    const minimalContract = await MinimalContract.deploy();
    await minimalContract.waitForDeployment();
    
    const address = await minimalContract.getAddress();
    console.log("✅ MinimalContract deployed to:", address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + address);
    
    // Test the contract
    console.log("\n🧪 Testing contract functionality...");
    const value = await minimalContract.getValue();
    console.log("✅ Contract value:", value.toString());
    
    console.log("\n🎉 Deployment and test completed successfully!");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


