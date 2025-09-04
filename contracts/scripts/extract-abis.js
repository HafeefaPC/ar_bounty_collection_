const fs = require('fs');
const path = require('path');

async function main() {
  console.log("📄 Extracting contract ABIs...");
  
  const abiDir = path.join(__dirname, '../artifacts/src');
  const outputDir = path.join(__dirname, '../abis');
  const flutterAbiDir = path.join(__dirname, '../../lib/shared/contracts/abis');
  
  // Create output directories
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }
  
  if (!fs.existsSync(flutterAbiDir)) {
    fs.mkdirSync(flutterAbiDir, { recursive: true });
  }
  
  const contracts = [
    'EventFactory',
    'BoundaryNFT', 
    'ClaimVerification'
  ];
  
  const extractedABIs = {};
  
  for (const contractName of contracts) {
    try {
      const artifactPath = path.join(abiDir, `${contractName}.sol/${contractName}.json`);
      
      if (!fs.existsSync(artifactPath)) {
        console.log(`⚠️  Warning: Artifact not found for ${contractName}`);
        continue;
      }
      
      const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
      
      // Save ABI to contracts/abis directory
      const abiFile = path.join(outputDir, `${contractName}.json`);
      fs.writeFileSync(abiFile, JSON.stringify(artifact.abi, null, 2));
      
      // Save ABI to Flutter app directory
      const flutterAbiFile = path.join(flutterAbiDir, `${contractName}.json`);
      fs.writeFileSync(flutterAbiFile, JSON.stringify(artifact.abi, null, 2));
      
      extractedABIs[contractName] = artifact.abi;
      
      console.log(`✅ Extracted ABI for ${contractName}`);
      console.log(`   Functions: ${artifact.abi.filter(item => item.type === 'function').length}`);
      console.log(`   Events: ${artifact.abi.filter(item => item.type === 'event').length}`);
      
    } catch (error) {
      console.error(`❌ Error extracting ABI for ${contractName}:`, error.message);
    }
  }
  
  // Create a combined ABI file
  const combinedAbiFile = path.join(outputDir, 'all-contracts.json');
  fs.writeFileSync(combinedAbiFile, JSON.stringify(extractedABIs, null, 2));
  
  // Create Flutter-compatible contract info file
  const contractInfo = {
    contracts: extractedABIs,
    extractedAt: new Date().toISOString(),
    version: "1.0.0"
  };
  
  const flutterContractInfoFile = path.join(flutterAbiDir, 'contract_info.json');
  fs.writeFileSync(flutterContractInfoFile, JSON.stringify(contractInfo, null, 2));
  
  console.log("\n🎉 ABI extraction completed!");
  console.log(`📁 ABIs saved to: ${outputDir}`);
  console.log(`📱 Flutter ABIs saved to: ${flutterAbiDir}`);
  console.log(`📄 Combined ABI file: ${combinedAbiFile}`);
  
  // Display summary
  console.log("\n📊 Summary:");
  Object.keys(extractedABIs).forEach(contractName => {
    const abi = extractedABIs[contractName];
    const functions = abi.filter(item => item.type === 'function').length;
    const events = abi.filter(item => item.type === 'event').length;
    console.log(`  ${contractName}: ${functions} functions, ${events} events`);
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ ABI extraction failed:", error);
    process.exit(1);
  });