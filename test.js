// scripts/mintToken.js

const hre = require("hardhat");
const { ethers } = require('ethers');

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log(
    "Deploying contracts with the account:",
    deployer.address
  );

//   console.log("Account balance:", (await deployer.getBalance()).toString());

  const TokenContract = await hre.ethers.getContractFactory("PropertyPulseToken", deployer);
  const token = TokenContract.attach("0xd55a65036d6569f386D61c9c9D94A004eB2513cd"); 

  const tokenId = 2; 
  const value = 1; 
  const data = ethers.zeroPadValue(ethers.toUtf8Bytes("Data"), 32); 
  const PropertyData = {
    realEstateAddress: "Sandy Vista Mills,Destineyhaven,Ohio 98253",
    yearBuilt: 1969,
    lotSizeSquareFeet: 1998,
    buildingName: "Eleanora Bayer Co"
  }

  const yearBuiltString = (PropertyData.yearBuilt).toString();
  const paddedYearBuiltString = ethers.zeroPadValue(ethers.hexlify(ethers.toUtf8Bytes(yearBuiltString)), 32); 

  const lotSizeSquareFeetString = (PropertyData.lotSizeSquareFeet).toString();
  const paddedLotSizeSquareString = ethers.zeroPadValue(ethers.hexlify(ethers.toUtf8Bytes(lotSizeSquareFeetString)), 32);



    // Truncate strings to ensure they fit within the 32-byte limit
    const truncatedRealEstateAddress = ethers.id(PropertyData.realEstateAddress).substring(0, 31);
    const truncatedBuildingName = ethers.id(PropertyData.buildingName).substring(0, 31);
  
  
    // Serialize each field of PropertyData
    const serializedRealEstateAddress = ethers.encodeBytes32String(truncatedRealEstateAddress);
    const serializedYearBuilt = ethers.getBytes(paddedYearBuiltString);
    const serializedLotSizeSquareFeet = ethers.getBytes(paddedLotSizeSquareString);
    const serializedBuildingName = ethers.encodeBytes32String(truncatedBuildingName);
  
    // Concatenate all serialized fields into a single bytes array
    const dataBytes = ethers.concat([
      serializedRealEstateAddress,
      serializedYearBuilt,
      serializedLotSizeSquareFeet,
      serializedBuildingName
    ]);

  const tx = await token.mint(deployer.address, tokenId, value, dataBytes);
  await tx.wait();

  console.log(`Minted ${value} tokens of ID ${tokenId}`);


//   const [tokenData,, realEstateAddress,yearBuilt, lotSizeSquareFeet, buildingName] = await token.getTokenData(tokenId);
//   console.log(`Real Estate Address: ${realEstateAddress}`);
//   console.log(`Year Built: ${yearBuilt}`);
//   console.log(`Lot Size Square Feet: ${lotSizeSquareFeet}`);
//   console.log(`Building Name: ${buildingName}`);

}
  
main()
 .then(() => process.exit(0))
 .catch((error) => {
    console.error(error);
    process.exit(1);
  });


