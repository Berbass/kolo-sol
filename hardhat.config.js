require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry"); // This is the key line

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      evmVersion: "cancun",
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // The plugin automatically syncs paths so you don't need to manually change them
};
