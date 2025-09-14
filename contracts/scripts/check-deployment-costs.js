const { ethers } = require("hardhat");

async function main() {
  console.log("💰 Checking deployment costs for remaining contracts...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("📝 Account:", deployer.address);
  console.log("💰 Current balance:", ethers.formatEther(balance), "STT");
  
  // Get current gas price
  const gasPrice = (await ethers.provider.getFeeData()).gasPrice;
  console.log("⛽ Current gas price:", ethers.formatUnits(gasPrice, "gwei"), "gwei");
  
  try {
    // Estimate BoundaryNFT cost
    const eventFactoryAddress = "0x1F2F71fa673a38CBC5848985A74713bDfB584578";
    const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
    const boundaryGasEstimate = await BoundaryNFT.getDeployTransaction(eventFactoryAddress).then(tx => 
      ethers.provider.estimateGas(tx)
    );
    const boundaryCost = boundaryGasEstimate * gasPrice;
    
    console.log("\n📋 BoundaryNFT:");
    console.log("  Estimated gas:", boundaryGasEstimate.toString());
    console.log("  Estimated cost:", ethers.formatEther(boundaryCost), "STT");
    console.log("  Can afford:", balance >= boundaryCost ? "✅ YES" : "❌ NO");
    
    // Estimate ClaimVerification cost
    const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
    const claimGasEstimate = await ClaimVerification.getDeployTransaction().then(tx => 
      ethers.provider.estimateGas(tx)
    );
    const claimCost = claimGasEstimate * gasPrice;
    
    console.log("\n📋 ClaimVerification:");
    console.log("  Estimated gas:", claimGasEstimate.toString());
    console.log("  Estimated cost:", ethers.formatEther(claimCost), "STT");
    console.log("  Can afford:", balance >= claimCost ? "✅ YES" : "❌ NO");
    
    console.log("\n💡 Recommendations:");
    console.log("1. Get more STT tokens from: https://testnet.somnia.network/");
    console.log("2. Current need:", ethers.formatEther(boundaryCost + claimCost), "STT for both contracts");
    console.log("3. You have EventFactory deployed already - that's the main contract!");
    
    // Create status file
    const deploymentStatus = {
      network: "somniaTestnet",
      deployer: deployer.address,
      balance: ethers.formatEther(balance),
      gasPrice: ethers.formatUnits(gasPrice, "gwei") + " gwei",
      estimates: {
        BoundaryNFT: {
          gas: boundaryGasEstimate.toString(),
          cost: ethers.formatEther(boundaryCost) + " STT",
          canAfford: balance >= boundaryCost
        },
        ClaimVerification: {
          gas: claimGasEstimate.toString(),
          cost: ethers.formatEther(claimCost) + " STT", 
          canAfford: balance >= claimCost
        }
      },
      contracts: {
        EventFactory: "0x1F2F71fa673a38CBC5848985A74713bDfB584578",
        BoundaryNFT: "PENDING",
        ClaimVerification: "PENDING"
      }
    };
    
    const fs = require('fs');
    const path = require('path');
    const statusPath = path.join(__dirname, '../deployments/deployment-cost-analysis.json');
    fs.writeFileSync(statusPath, JSON.stringify(deploymentStatus, null, 2));
    console.log("\n📄 Cost analysis saved to:", statusPath);
    
  } catch (error) {
    console.error("❌ Error estimating costs:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Script failed:", error);
    process.exit(1);
  });