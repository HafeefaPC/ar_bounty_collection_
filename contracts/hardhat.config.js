require("@nomicfoundation/hardhat-toolbox");

const PRIVATE_KEY = process.env.PRIVATE_KEY || "0x069b34ec0c3ade510c6a11a73dc37926d99d75163ecd64f3be006d581fcf2c09";
const AVALANCHE_RPC_URL = process.env.AVALANCHE_RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc";
const SNOWTRACE_API_KEY = process.env.SNOWTRACE_API_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    fuji: {
      url: AVALANCHE_RPC_URL,
      chainId: 43113,
      accounts: [PRIVATE_KEY],
      gas: 8000000,
      gasPrice: 25000000000, // 25 gwei
    },
    avalanche: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      chainId: 43114,
      accounts: [PRIVATE_KEY],
      gas: 8000000,
      gasPrice: 25000000000,
    }
  },
  etherscan: {
    apiKey: {
      avalancheFujiTestnet: SNOWTRACE_API_KEY,
      avalanche: SNOWTRACE_API_KEY,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  paths: {
    sources: "./src",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};