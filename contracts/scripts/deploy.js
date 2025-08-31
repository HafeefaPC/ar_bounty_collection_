const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Deploying TOKON contracts to network:", network.name);
  
  // Use the specified wallet address and private key
  const walletAddress = "0x84efBdc3146C76066591496A34e08b4e12fe8d2F";
  const privateKey = "0x069b34ec0c3ade510c6a11a73dc37926d99d75163ecd64f3be006d581fcf2c09";
  
  // Create wallet instance
  const wallet = new ethers.Wallet(privateKey, ethers.provider);
  console.log("Deploying contracts with wallet:", wallet.address);
  console.log("Wallet balance:", (await ethers.provider.getBalance(wallet.address)).toString());
  
  // Check if wallet has enough balance
  const balance = await ethers.provider.getBalance(wallet.address);
  if (balance < ethers.parseEther("0.1")) {
    console.log("⚠️  Warning: Wallet balance is low. Make sure you have enough funds for deployment.");
  }

  try {
    // Step 1: Deploy EventFactory first (no dependencies)
    console.log("\n📋 Step 1: Deploying EventFactory...");
    const EventFactory = await ethers.getContractFactory("EventFactory", wallet);
    const eventFactory = await EventFactory.deploy();
    await eventFactory.waitForDeployment();
    
    const eventFactoryAddress = await eventFactory.getAddress();
    console.log("✅ EventFactory deployed to:", eventFactoryAddress);

    // Step 2: Deploy ClaimVerification (no dependencies)
    console.log("\n🔐 Step 2: Deploying ClaimVerification...");
    const ClaimVerification = await ethers.getContractFactory("ClaimVerification", wallet);
    const claimVerification = await ClaimVerification.deploy();
    await claimVerification.waitForDeployment();
    
    const claimVerificationAddress = await claimVerification.getAddress();
    console.log("✅ ClaimVerification deployed to:", claimVerificationAddress);

    // Step 3: Deploy BoundaryNFT with EventFactory address dependency
    console.log("\n🎨 Step 3: Deploying BoundaryNFT...");
    const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT", wallet);
    const boundaryNFT = await BoundaryNFT.deploy(eventFactoryAddress);
    await boundaryNFT.waitForDeployment();
    
    const boundaryNFTAddress = await boundaryNFT.getAddress();
    console.log("✅ BoundaryNFT deployed to:", boundaryNFTAddress);

    // Step 4: Set up roles and permissions
    console.log("\n🔑 Step 4: Setting up roles and permissions...");
    
    // Grant ORGANIZER_ROLE on EventFactory to BoundaryNFT contract
    const ORGANIZER_ROLE = await eventFactory.ORGANIZER_ROLE();
    await eventFactory.grantRole(ORGANIZER_ROLE, boundaryNFTAddress);
    console.log("✅ Granted ORGANIZER_ROLE to BoundaryNFT contract");

    // Grant MINTER_ROLE on BoundaryNFT to EventFactory
    const MINTER_ROLE = await boundaryNFT.MINTER_ROLE();
    await boundaryNFT.grantRole(MINTER_ROLE, eventFactoryAddress);
    console.log("✅ Granted MINTER_ROLE to EventFactory");

    // Set deployer wallet as trusted signer in ClaimVerification
    await claimVerification.setTrustedSigner(wallet.address, true);
    console.log("✅ Set deployer wallet as trusted signer in ClaimVerification");

    // Grant ORACLE_ROLE and VERIFIER_ROLE to deployer wallet
    const ORACLE_ROLE = await claimVerification.ORACLE_ROLE();
    const VERIFIER_ROLE = await claimVerification.VERIFIER_ROLE();
    await claimVerification.grantRole(ORACLE_ROLE, wallet.address);
    await claimVerification.grantRole(VERIFIER_ROLE, wallet.address);
    console.log("✅ Granted ORACLE_ROLE and VERIFIER_ROLE to deployer wallet");

    // Step 5: Deployment Summary
    console.log("\n🎉 === DEPLOYMENT SUCCESSFUL ===");
    console.log("Network:", network.name);
    console.log("Deployer Wallet:", wallet.address);
    console.log("EventFactory:", eventFactoryAddress);
    console.log("BoundaryNFT:", boundaryNFTAddress);
    console.log("ClaimVerification:", claimVerificationAddress);
    
    // Save deployment addresses to a file
    const fs = require('fs');
    const deploymentInfo = {
      network: network.name,
      deployer: wallet.address,
      contracts: {
        EventFactory: eventFactoryAddress,
        BoundaryNFT: boundaryNFTAddress,
        ClaimVerification: claimVerificationAddress
      },
      deployedAt: new Date().toISOString(),
      chainId: network.config.chainId,
      deploymentTx: {
        EventFactory: eventFactory.deploymentTransaction().hash,
        BoundaryNFT: boundaryNFT.deploymentTransaction().hash,
        ClaimVerification: claimVerification.deploymentTransaction().hash
      }
    };
    
    // Create deployments directory if it doesn't exist
    if (!fs.existsSync('./deployments')) {
      fs.mkdirSync('./deployments');
    }
    
    fs.writeFileSync(
      `./deployments/${network.name}-deployment.json`,
      JSON.stringify(deploymentInfo, null, 2)
    );
    
    console.log(`\n📁 Deployment info saved to ./deployments/${network.name}-deployment.json`);
    
    // Step 6: Wait for confirmations and verify (for non-local networks)
    if (network.name !== "localhost" && network.name !== "hardhat") {
      console.log("\n⏳ Waiting for block confirmations...");
      await eventFactory.deploymentTransaction().wait(6);
      await boundaryNFT.deploymentTransaction().wait(6);
      await claimVerification.deploymentTransaction().wait(6);
      
      console.log("\n🔍 Verifying contracts on block explorer...");
      try {
        await hre.run("verify:verify", {
          address: eventFactoryAddress,
          constructorArguments: [],
        });
        
        await hre.run("verify:verify", {
          address: boundaryNFTAddress,
          constructorArguments: [eventFactoryAddress],
        });
        
        await hre.run("verify:verify", {
          address: claimVerificationAddress,
          constructorArguments: [],
        });
        
        console.log("✅ All contracts verified successfully!");
      } catch (error) {
        console.log("⚠️  Contract verification failed:", error.message);
      }
    }

    console.log("\n🎯 Deployment completed successfully!");
    console.log("You can now use these contract addresses in your Flutter app.");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

// Handle errors gracefully
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment script failed:", error);
    process.exit(1);
  });