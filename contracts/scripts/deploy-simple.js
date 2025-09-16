const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying simplified contracts to Somnia Testnet...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("👤 Deploying with account:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
  
  try {
    // Use EIP-1559 gas pricing for Somnia Testnet
    const maxFeePerGas = ethers.parseUnits("15", "gwei"); // 15 gwei max fee
    const maxPriorityFeePerGas = ethers.parseUnits("2", "gwei"); // 2 gwei priority fee
    console.log("⛽ Using EIP-1559 gas pricing for Somnia Testnet");
    
    // 1. Deploy SimpleEventFactory
    console.log("\n📦 Deploying SimpleEventFactory contract...");
    const SimpleEventFactory = await ethers.getContractFactory("SimpleEventFactory");
    const simpleEventFactory = await SimpleEventFactory.deploy({
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      gasLimit: 2000000
    });
    await simpleEventFactory.waitForDeployment();
    
    const address = await simpleEventFactory.getAddress();
    console.log("✅ SimpleEventFactory deployed to:", address);
    console.log("🔗 View on explorer: https://shannon-explorer.somnia.network/address/" + address);
    
    // Test the contract
    console.log("\n🧪 Testing contract functionality...");
    const eventId = await simpleEventFactory.createEvent(
      "Test Event",
      "This is a test event",
      "TEST123",
      Math.floor(Date.now() / 1000) + 3600, // 1 hour from now
      Math.floor(Date.now() / 1000) + 7200  // 2 hours from now
    );
    console.log("✅ Test event created with ID:", eventId.toString());
    
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


