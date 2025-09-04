const { ethers } = require("hardhat");

async function main() {
  console.log("💰 Checking wallet balance...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Wallet address:", deployer.address);
  
  // Check balance
  const balance = await ethers.provider.getBalance(deployer.address);
  const balanceInEth = ethers.formatEther(balance);
  
  console.log("Balance:", balanceInEth, "ETH");
  
  // Check if balance is sufficient for deployment
  const minBalance = ethers.parseEther("0.01"); // 0.01 ETH minimum
  if (balance < minBalance) {
    console.log("⚠️  Warning: Balance is low. You need at least 0.01 ETH for deployment.");
    console.log("Please fund your wallet with some ETH from a faucet:");
    console.log("https://faucet.arbitrum.io/");
  } else {
    console.log("✅ Balance is sufficient for deployment.");
  }
  
  // Get network info
  const network = await ethers.provider.getNetwork();
  console.log("Network:", network.name);
  console.log("Chain ID:", network.chainId.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Balance check failed:", error);
    process.exit(1);
  });
