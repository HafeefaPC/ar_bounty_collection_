const { ethers } = require("hardhat");

async function main() {
  console.log("🧪 Testing simple contract deployment to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("👤 Deploying with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  try {
    // Deploy a simple test contract
    console.log("\n📦 Deploying SimpleTest contract...");
    const SimpleTest = await ethers.getContractFactory("SimpleTest");
    const simpleTest = await SimpleTest.deploy();
    await simpleTest.waitForDeployment();
    
    const address = await simpleTest.getAddress();
    console.log("✅ SimpleTest deployed to:", address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + address);
    
  } catch (error) {
    console.error("❌ Test deployment failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


