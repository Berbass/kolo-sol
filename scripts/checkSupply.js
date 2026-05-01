const hre = require("hardhat");

async function main() {
  // 1. Set the address of the contract you deployed to your local node
  const CONTRACT_ADDRESS = "0x5FbDB2315678afecb367f032d93F642f64180aa3"; 

  // 2. Get the contract instance
  // Hardhat automatically finds the ABI from your /artifacts folder
  const contract = await hre.ethers.getContractFactory("KOLO");
  const KOLO = await contract.attach(CONTRACT_ADDRESS);

  // 3. Call the totalSupply function
  try {
    const supply = await KOLO.totalSupply();
    
    // 4. Format the output (assuming 18 decimals)
    console.log("------------------------------------------");
    console.log(`Success! Connected to: ${CONTRACT_ADDRESS}`);
    console.log(`Total Supply: ${hre.ethers.formatUnits(supply, await KOLO.decimals())} KLO`);
    console.log("------------------------------------------");
  } catch (error) {
    console.error("Error: Could not fetch total supply. Ensure the address and function name are correct.");
    console.error(error.reason || error.message);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
