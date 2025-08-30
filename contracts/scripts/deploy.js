const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying TOKON contracts to network:", network.name);
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy EventFactory first
  console.log("\nDeploying EventFactory...");
  const EventFactory = await ethers.getContractFactory("EventFactory");
  const eventFactory = await EventFactory.deploy();
  await eventFactory.waitForDeployment();
  
  const eventFactoryAddress = await eventFactory.getAddress();
  console.log("EventFactory deployed to:", eventFactoryAddress);

  // Deploy ClaimVerification
  console.log("\nDeploying ClaimVerification...");
  const ClaimVerification = await ethers.getContractFactory("ClaimVerification");
  const claimVerification = await ClaimVerification.deploy();
  await claimVerification.waitForDeployment();
  
  const claimVerificationAddress = await claimVerification.getAddress();
  console.log("ClaimVerification deployed to:", claimVerificationAddress);

  // Deploy BoundaryNFT with EventFactory address
  console.log("\nDeploying BoundaryNFT...");
  const BoundaryNFT = await ethers.getContractFactory("BoundaryNFT");
  const boundaryNFT = await BoundaryNFT.deploy(eventFactoryAddress);
  await boundaryNFT.waitForDeployment();
  
  const boundaryNFTAddress = await boundaryNFT.getAddress();
  console.log("BoundaryNFT deployed to:", boundaryNFTAddress);

  // Grant necessary roles
  console.log("\nSetting up roles and permissions...");
  
  // Grant ORGANIZER_ROLE on EventFactory to BoundaryNFT contract
  const ORGANIZER_ROLE = await eventFactory.ORGANIZER_ROLE();
  await eventFactory.grantOrganizerRole(boundaryNFTAddress);
  console.log("Granted ORGANIZER_ROLE to BoundaryNFT contract");

  // Set deployer as trusted signer in ClaimVerification
  await claimVerification.setTrustedSigner(deployer.address, true);
  console.log("Set deployer as trusted signer in ClaimVerification");

  console.log("\n=== Deployment Summary ===");
  console.log("Network:", network.name);
  console.log("Deployer:", deployer.address);
  console.log("EventFactory:", eventFactoryAddress);
  console.log("BoundaryNFT:", boundaryNFTAddress);
  console.log("ClaimVerification:", claimVerificationAddress);
  
  // Save deployment addresses to a file
  const fs = require('fs');
  const deploymentInfo = {
    network: network.name,
    deployer: deployer.address,
    contracts: {
      EventFactory: eventFactoryAddress,
      BoundaryNFT: boundaryNFTAddress,
      ClaimVerification: claimVerificationAddress
    },
    deployedAt: new Date().toISOString(),
    chainId: network.config.chainId
  };
  
  fs.writeFileSync(
    `./deployments/${network.name}-deployment.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );
  
  console.log(`\nDeployment info saved to ./deployments/${network.name}-deployment.json`);
  
  if (network.name !== "localhost" && network.name !== "hardhat") {
    console.log("\nWaiting for block confirmations...");
    await eventFactory.deploymentTransaction().wait(6);
    await boundaryNFT.deploymentTransaction().wait(6);
    await claimVerification.deploymentTransaction().wait(6);
    
    console.log("\nVerifying contracts on Snowtrace...");
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
      
      console.log("All contracts verified successfully!");
    } catch (error) {
      console.log("Verification failed:", error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });