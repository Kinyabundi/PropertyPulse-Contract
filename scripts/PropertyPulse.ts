// Importing necessary modules using ES Module syntax
import { ethers } from 'hardhat';
const { METADATA_URL } = require("../constants");

async function main() {
  try {

     // URL from where we can extract the metadata for a Crypto Dev NFT
     const metadataURL = METADATA_URL;

    // Get the ContractFactory of the PropertyPulseToken
    const PropertyPulseToken = await ethers.getContractFactory("PropertyPulseToken");


    // Deploy the contract
    const propertyPulseToken = await PropertyPulseToken.deploy(metadataURL);

    // Wait for the deployment transaction to be mined
    await propertyPulseToken.waitForDeployment();

    console.log(`PropertyPulseToken deployed to: ${propertyPulseToken.target}`);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

main();