const hre = require("hardhat");
const { ABI } = require("../constants");


async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  // Replace this with the actual contract address and ABI
  const propertyPulseTokenAddress = "0x41167F502A5EA1245f761422E57a6C05F8206F2D";
// 0xE21786abaC624E41d6731045F52083ED0c099DEF
  const propertyPulseTokenABI = ABI

  // Initialize contract instance
  const propertyPulseToken = new hre.ethers.Contract(propertyPulseTokenAddress, propertyPulseTokenABI, deployer);

  // Parameters for issuing a token
  const to = deployer.address; 
 const  exampleDonorID = "0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000";
  const subscriptionId = 57; 
  const gasLimit = 5000000; 
  const donID =  ethers.id(exampleDonorID);

  try {
    // Call the issue function
    const tx = await propertyPulseToken.issue(subscriptionId, gasLimit, donID);
    console.log("Issued token with Request ID:", tx.hash);


    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    console.log("Transaction mined in block:", receipt.blockNumber);

  } catch (error) {
    console.error("Failed to issue token:", error);
  }
}

main()
.then(() => process.exit(0))
.catch((error) => {
    console.error(error);
    process.exit(1);
  });