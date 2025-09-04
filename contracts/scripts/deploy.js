const { ethers } = require("hardhat");
const fs = require('fs');
const path = require('path');

async function main() {
  console.log("🚀 Starting TOKON contracts deployment...");
  console.log("Network:", network.name);
  console.log("Chain ID:", network.config.chainId);
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  
  // Check deployer balance
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");
  
  if (balance < ethers.parseEther("0.1")) {
    console.log("⚠️  Warning: Low balance. Make sure you have enough funds for deployment.");
  }

  const deploymentInfo = {
    network: network.name,
    deployer: deployer.address,
    chainId: network.config.chainId,
    deployedAt: new Date().toISOString(),
    contracts: {},
    deploymentTx: {},
    gasUsed: {},
    abis: {}
  };

  try {
    // Step 1: Deploy EventFactory
    console.log("\n📋 Step 1: Deploying EventFactory...");
    const EventFactory = await ethers.getContractFactory("EventFactory");
    const eventFactory = await EventFactory.deploy();
    await eventFactory.waitForDeployment();
    
    const eventFactoryAddress = await eventFactory.getAddress();
    const eventFactoryTx = eventFactory.deploymentTransaction();
    const eventFactoryReceipt = await eventFactoryTx.wait();
    
    console.log("✅ EventFactory deployed to:", eventFactoryAddress);
    console.log("   Gas used:", eventFactoryReceipt.gasUsed.toString());
    console.log("   Transaction hash:", eventFactoryTx.hash);
    
    deploymentInfo.contracts.EventFactory = eventFactoryAddress;
    deploymentInfo.deploymentTx.EventFactory = eventFactoryTx.hash;
    deploymentInfo.gasUsed.EventFactory = eventFactoryReceipt.gasUsed.toString();

    // Step 2: Deploy ClaimVerification
    console.log("\n🔐 Step 2: Deploying ClaimVerification...");
    const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
    const claimVerification = await ClaimVerification.deploy();
    await claimVerification.waitForDeployment();
    
    const claimVerificationAddress = await claimVerification.getAddress();
    const claimVerificationTx = claimVerification.deploymentTransaction();
    const claimVerificationReceipt = await claimVerificationTx.wait();
    
    console.log("✅ ClaimVerification deployed to:", claimVerificationAddress);
    console.log("   Gas used:", claimVerificationReceipt.gasUsed.toString());
    console.log("   Transaction hash:", claimVerificationTx.hash);
    
    deploymentInfo.contracts.ClaimVerification = claimVerificationAddress;
    deploymentInfo.deploymentTx.ClaimVerification = claimVerificationTx.hash;
    deploymentInfo.gasUsed.ClaimVerification = claimVerificationReceipt.gasUsed.toString();

    // Step 3: Deploy BoundaryNFT with EventFactory address
    console.log("\n🎨 Step 3: Deploying BoundaryNFT...");
    const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
    const boundaryNFT = await BoundaryNFT.deploy(eventFactoryAddress);
    await boundaryNFT.waitForDeployment();
    
    const boundaryNFTAddress = await boundaryNFT.getAddress();
    const boundaryNFTTx = boundaryNFT.deploymentTransaction();
    const boundaryNFTReceipt = await boundaryNFTTx.wait();
    
    console.log("✅ BoundaryNFT deployed to:", boundaryNFTAddress);
    console.log("   Gas used:", boundaryNFTReceipt.gasUsed.toString());
    console.log("   Transaction hash:", boundaryNFTTx.hash);
    
    deploymentInfo.contracts.BoundaryNFT = boundaryNFTAddress;
    deploymentInfo.deploymentTx.BoundaryNFT = boundaryNFTTx.hash;
    deploymentInfo.gasUsed.BoundaryNFT = boundaryNFTReceipt.gasUsed.toString();

    // Step 4: Set up roles and permissions
    console.log("\n🔑 Step 4: Setting up roles and permissions...");
    
    // Grant ORGANIZER_ROLE on EventFactory to BoundaryNFT contract
    const ORGANIZER_ROLE = await eventFactory.ORGANIZER_ROLE();
    const grantOrganizerTx = await eventFactory.grantRole(ORGANIZER_ROLE, boundaryNFTAddress);
    await grantOrganizerTx.wait();
    console.log("✅ Granted ORGANIZER_ROLE to BoundaryNFT contract");

    // Grant MINTER_ROLE on BoundaryNFT to EventFactory
    const MINTER_ROLE = await boundaryNFT.MINTER_ROLE();
    const grantMinterTx = await boundaryNFT.grantRole(MINTER_ROLE, eventFactoryAddress);
    await grantMinterTx.wait();
    console.log("✅ Granted MINTER_ROLE to EventFactory");

    // Set deployer wallet as trusted signer in ClaimVerification
    const setTrustedSignerTx = await claimVerification.setTrustedSigner(deployer.address, true);
    await setTrustedSignerTx.wait();
    console.log("✅ Set deployer wallet as trusted signer in ClaimVerification");

    // Grant ORACLE_ROLE and VERIFIER_ROLE to deployer wallet
    const ORACLE_ROLE = await claimVerification.ORACLE_ROLE();
    const VERIFIER_ROLE = await claimVerification.VERIFIER_ROLE();
    const grantOracleTx = await claimVerification.grantRole(ORACLE_ROLE, deployer.address);
    await grantOracleTx.wait();
    const grantVerifierTx = await claimVerification.grantRole(VERIFIER_ROLE, deployer.address);
    await grantVerifierTx.wait();
    console.log("✅ Granted ORACLE_ROLE and VERIFIER_ROLE to deployer wallet");

    // Step 5: Extract ABIs
    console.log("\n📄 Step 5: Extracting contract ABIs...");
    const abiDir = path.join(__dirname, '../artifacts/contracts/src');
    
    try {
      // EventFactory ABI
      const eventFactoryArtifact = require(path.join(abiDir, 'EventFactory.sol/EventFactory.json'));
      deploymentInfo.abis.EventFactory = eventFactoryArtifact.abi;
      
      // BoundaryNFT ABI
      const boundaryNFTArtifact = require(path.join(abiDir, 'BoundaryNFT.sol/BoundaryNFT.json'));
      deploymentInfo.abis.BoundaryNFT = boundaryNFTArtifact.abi;
      
      // ClaimVerification ABI
      const claimVerificationArtifact = require(path.join(abiDir, 'ClaimVerification.sol/ClaimVerification.json'));
      deploymentInfo.abis.ClaimVerification = claimVerificationArtifact.abi;
      
      console.log("✅ ABIs extracted successfully");
    } catch (abiError) {
      console.log("⚠️  Warning: Could not extract ABIs:", abiError.message);
    }

    // Step 6: Save deployment info
    console.log("\n💾 Step 6: Saving deployment information...");
    
    // Create deployments directory if it doesn't exist
    const deploymentsDir = path.join(__dirname, '../deployments');
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }
    
    const deploymentFile = path.join(deploymentsDir, `${network.name}-deployment-complete.json`);
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
    console.log(`📁 Deployment info saved to ${deploymentFile}`);

    // Step 7: Create ABI files for Flutter app
    console.log("\n📱 Step 7: Creating ABI files for Flutter app...");
    const flutterAbiDir = path.join(__dirname, '../../lib/shared/contracts/abis');
    if (!fs.existsSync(flutterAbiDir)) {
      fs.mkdirSync(flutterAbiDir, { recursive: true });
    }
    
    if (deploymentInfo.abis.EventFactory) {
      fs.writeFileSync(
        path.join(flutterAbiDir, 'EventFactory.json'),
        JSON.stringify(deploymentInfo.abis.EventFactory, null, 2)
      );
    }
    
    if (deploymentInfo.abis.BoundaryNFT) {
      fs.writeFileSync(
        path.join(flutterAbiDir, 'BoundaryNFT.json'),
        JSON.stringify(deploymentInfo.abis.BoundaryNFT, null, 2)
      );
    }
    
    if (deploymentInfo.abis.ClaimVerification) {
      fs.writeFileSync(
        path.join(flutterAbiDir, 'ClaimVerification.json'),
        JSON.stringify(deploymentInfo.abis.ClaimVerification, null, 2)
      );
    }
    
    // Create contract addresses file for Flutter
    const contractAddresses = {
      network: network.name,
      chainId: network.config.chainId,
      contracts: deploymentInfo.contracts
    };
    
    fs.writeFileSync(
      path.join(flutterAbiDir, 'contract_addresses.json'),
      JSON.stringify(contractAddresses, null, 2)
    );
    
    console.log("✅ ABI files created for Flutter app");

    // Step 8: Deployment Summary
    console.log("\n🎉 === DEPLOYMENT SUCCESSFUL ===");
    console.log("Network:", network.name);
    console.log("Chain ID:", network.config.chainId);
    console.log("Deployer:", deployer.address);
    console.log("\nContract Addresses:");
    console.log("  EventFactory:", eventFactoryAddress);
    console.log("  BoundaryNFT:", boundaryNFTAddress);
    console.log("  ClaimVerification:", claimVerificationAddress);
    
    console.log("\nTotal Gas Used:");
    const totalGas = Object.values(deploymentInfo.gasUsed).reduce((sum, gas) => sum + BigInt(gas), 0n);
    console.log("  Total:", totalGas.toString());

    // Step 9: Verification (for non-local networks)
    if (network.name !== "localhost" && network.name !== "hardhat") {
      console.log("\n🔍 Step 9: Verifying contracts on block explorer...");
      
      try {
        console.log("Verifying EventFactory...");
        await hre.run("verify:verify", {
          address: eventFactoryAddress,
          constructorArguments: [],
        });
        console.log("✅ EventFactory verified");
        
        console.log("Verifying ClaimVerification...");
        await hre.run("verify:verify", {
          address: claimVerificationAddress,
          constructorArguments: [],
        });
        console.log("✅ ClaimVerification verified");
        
        console.log("Verifying BoundaryNFT...");
        await hre.run("verify:verify", {
          address: boundaryNFTAddress,
          constructorArguments: [eventFactoryAddress],
        });
        console.log("✅ BoundaryNFT verified");
        
        console.log("🎉 All contracts verified successfully!");
      } catch (verifyError) {
        console.log("⚠️  Contract verification failed:", verifyError.message);
        console.log("You can verify manually later using:");
        console.log(`npx hardhat verify --network ${network.name} ${eventFactoryAddress}`);
        console.log(`npx hardhat verify --network ${network.name} ${claimVerificationAddress}`);
        console.log(`npx hardhat verify --network ${network.name} ${boundaryNFTAddress} ${eventFactoryAddress}`);
      }
    }

    console.log("\n🎯 Deployment completed successfully!");
    console.log("📱 Contract addresses and ABIs are ready for your Flutter app.");
    console.log("🔗 You can now interact with the contracts using the generated ABI files.");
    
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    
    // Save partial deployment info for debugging
    if (deploymentInfo.contracts && Object.keys(deploymentInfo.contracts).length > 0) {
      const errorFile = path.join(__dirname, '../deployments', `${network.name}-deployment-error.json`);
      fs.writeFileSync(errorFile, JSON.stringify(deploymentInfo, null, 2));
      console.log("💾 Partial deployment info saved to:", errorFile);
    }
    
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