require("@nomiclabs/hardhat-waffle");
require("hardhat-typechain");
require("solidity-coverage");
require("hardhat-preprocessor");
require('hardhat-contract-sizer');
require("@nomiclabs/hardhat-ethers");
const {removeConsoleLog} = require("hardhat-preprocessor");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.7.3",
  preprocess: {
    eachLine: removeConsoleLog((hre) => hre.network.name !== 'hardhat' && hre.network.name !== 'localhost'),
  },

};

