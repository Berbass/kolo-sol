# KOLO Project

This project contains the KOLO token contract, a stablecoin-like token pegged to EURc.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) & [npm](https://www.npmjs.com/)

## Testing

### Using Forge (Foundry)
To run the Solidity tests:
```bash
forge test
```
To show logs and traces:
```bash
forge test -vvvv
```

### Using Hardhat
To run the JavaScript/TypeScript tests:
```bash
npx hardhat test
```

## Local Deployment with Anvil

1. **Start a local node**
   Open a terminal and run Anvil. This allows you to simulate a blockchain locally.
   ```bash
   anvil
   ```
   Keep this terminal running. It will display a list of available accounts and private keys.

2. **Deploy the MockEURc contract**
   Open a _new_ terminal window. First, we need a mock EURc token to simulate reserves.

   - We will mint 1,000,000 EURc (with 6 decimals) to the deployer.
   - `1000000000000` = 1,000,000 * 10^6

   ```bash
   forge create contracts/MockEurc.sol:MockEURc \
     --broadcast \
     --rpc-url http://127.0.0.1:8545 \
     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
     --constructor-args 1000000000000
   ```
   
   Copy the `Deployed to` address from the output (e.g., `0x5FbDB2315678afecb367f032d93F642f64180aa3`).

3. **Deploy the KOLO contract**
   Now deploy KOLO using the address of the `MockEURc` you just deployed.

   You need to provide:
   - `--rpc-url`: The local Anvil RPC URL (default: `http://127.0.0.1:8545`)
   - `--private-key`: One of the private keys from the `anvil` output.
   - `--constructor-args`: The arguments for the KOLO constructor:
     1. `_eurcAddress`: The address of the `MockEURc` contract.
     2. `initialOwner`: The address that will own the KOLO contract (use the address corresponding to your private key).

   **Example Command:**
   
   Using the first default Anvil account:
   - Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
   - Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
   - Mock EURc Address: `0x5FbDB2315678afecb367f032d93F642f64180aa3` (Replace this with your actual deployment address)

   ```bash
   forge create contracts/Kolo.sol:KOLO \
     --broadcast \
     --rpc-url http://127.0.0.1:8545 \
     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
     --constructor-args 0x5FbDB2315678afecb367f032d93F642f64180aa3 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
   ```

   If successful, you will see the `Deployer`, `Deployed to`, and `Transaction hash` in the output.

   **Note:** Since you deployed `MockEURc` with the same account that owns `KOLO`, the reserves check will pass, and you can now interact with the KOLO contract (e.g., minting).
