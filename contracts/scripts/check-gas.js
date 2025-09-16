const { ethers } = require("hardhat");

async function main() {
  console.log("🔍 Checking Somnia Testnet gas information...");
  
  try {
    // Get current block
    const block = await ethers.provider.getBlock("latest");
    console.log("📦 Latest block number:", block.number);
    console.log("⛽ Base fee per gas:", ethers.formatUnits(block.baseFeePerGas || 0, "gwei"), "gwei");
    
    // Try to get gas price (this might not work on all networks)
    try {
      const feeData = await ethers.provider.getFeeData();
      console.log("💰 Fee data:");
      console.log("  - Gas price:", ethers.formatUnits(feeData.gasPrice || 0, "gwei"), "gwei");
      console.log("  - Max fee per gas:", ethers.formatUnits(feeData.maxFeePerGas || 0, "gwei"), "gwei");
      console.log("  - Max priority fee per gas:", ethers.formatUnits(feeData.maxPriorityFeePerGas || 0, "gwei"), "gwei");
    } catch (e) {
      console.log("⚠️ Could not get fee data:", e.message);
    }
    
    // Get account balance
    const [deployer] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(deployer.address);
    console.log("💰 Account balance:", ethers.formatEther(balance), "STT");
    
  } catch (error) {
    console.error("❌ Error checking gas info:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


