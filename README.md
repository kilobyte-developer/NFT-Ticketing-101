# Advanced NFT Ticketing Smart Contract

A comprehensive ERC-721 smart contract for event ticketing with built-in anti-counterfeiting, resale controls, royalty system, and QR code verification.

## 🚀 Features

- **ERC-721 NFT Tickets**: Each ticket is a unique, non-fungible token
- **Anti-Counterfeiting**: Blockchain-verified tickets prevent duplication
- **Resale Controls**: Configurable maximum resales per ticket
- **Royalty System**: Automatic royalty payments to organizers on resales (ERC-2981 compliant)
- **QR Code Integration**: Secure check-in system with tamper-proof verification
- **Terms & Conditions**: Built-in acceptance tracking for legal compliance
- **Multi-Attendee Support**: Single ticket can cover multiple attendees
- **Organizer Dashboard**: Tools for event management and attendee check-in

## 📋 Prerequisites

Before you begin, ensure you have:

- **Node.js** (v16 or higher)
- **npm** or **yarn** package manager
- **MetaMask** or another Web3 wallet
- **Test ETH** for deployment (get from faucets for testnets)
- **Hardhat** or **Truffle** for deployment (recommended: Hardhat)

## 🛠️ Setup Instructions

### 1. Initialize Your Project

```bash
mkdir nft-ticketing-contract
cd nft-ticketing-contract
npm init -y
```

### 2. Install Dependencies

```bash
# Install Hardhat and OpenZeppelin contracts
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install @openzeppelin/contracts

# Initialize Hardhat project
npx hardhat init
# Choose "Create a JavaScript project" or "Create a TypeScript project"
```

### 3. Add the Smart Contract

Create the contract file:
```bash
mkdir -p contracts
# Copy the AdvancedTicketNFT.sol file to contracts/AdvancedTicketNFT.sol
```

### 4. Configure Hardhat

Update `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // Polygon Mumbai Testnet (Recommended for testing)
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 35000000000, // 35 gwei
    },
    // Polygon Mainnet
    polygon: {
      url: `https://polygon-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
      gasPrice: 35000000000,
    },
    // Ethereum Sepolia Testnet
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    },
    // Ethereum Mainnet
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY],
    }
  },
  etherscan: {
    apiKey: {
      polygon: process.env.POLYGONSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
    }
  }
};
```

### 5. Environment Variables

Create `.env` file in your project root:

```bash
# Your wallet private key (NEVER share this!)
PRIVATE_KEY=your_wallet_private_key_here

# Alchemy API keys (get from https://alchemy.com)
ALCHEMY_API_KEY=your_alchemy_api_key_here

# Block explorer API keys for contract verification
POLYGONSCAN_API_KEY=your_polygonscan_api_key_here
ETHERSCAN_API_KEY=your_etherscan_api_key_here
```

**⚠️ SECURITY WARNING**: Never commit your `.env` file to version control!

### 6. Create Deployment Script

Create `scripts/deploy.js`:

```javascript
const hre = require("hardhat");

async function main() {
  console.log("Deploying AdvancedTicketNFT contract...");

  // Get the contract factory
  const AdvancedTicketNFT = await hre.ethers.getContractFactory("AdvancedTicketNFT");
  
  // Deploy the contract
  const contract = await AdvancedTicketNFT.deploy();
  
  // Wait for deployment to complete
  await contract.waitForDeployment();
  
  const contractAddress = await contract.getAddress();
  
  console.log("✅ AdvancedTicketNFT deployed to:", contractAddress);
  console.log("🔗 Network:", hre.network.name);
  
  // Wait for a few block confirmations before verification
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("⏳ Waiting for block confirmations...");
    await contract.deploymentTransaction().wait(6);
    
    // Verify the contract on block explorer
    try {
      await hre.run("verify:verify", {
        address: contractAddress,
        constructorArguments: [],
      });
      console.log("✅ Contract verified on block explorer");
    } catch (error) {
      console.log("❌ Verification failed:", error.message);
    }
  }
  
  console.log("\n📋 Contract Details:");
  console.log("Contract Address:", contractAddress);
  console.log("Network:", hre.network.name);
  console.log("Deployer:", (await hre.ethers.getSigners())[0].address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

## 🚀 Deployment

### Test Deployment (Recommended First)

1. **Get Test Tokens**:
   - For Polygon Mumbai: https://faucet.polygon.technology/
   - For Ethereum Sepolia: https://sepoliafaucet.com/

2. **Deploy to Testnet**:
```bash
# Deploy to Polygon Mumbai (recommended - lower gas fees)
npx hardhat run scripts/deploy.js --network mumbai

# Or deploy to Ethereum Sepolia
npx hardhat run scripts/deploy.js --network sepolia
```

### Production Deployment

```bash
# Deploy to Polygon Mainnet (recommended - lower gas fees)
npx hardhat run scripts/deploy.js --network polygon

# Or deploy to Ethereum Mainnet
npx hardhat run scripts/deploy.js --network mainnet
```

## 🧪 Testing

Create `test/AdvancedTicketNFT.test.js`:

```javascript
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AdvancedTicketNFT", function () {
  let contract;
  let owner;
  let organizer;
  let buyer;

  beforeEach(async function () {
    [owner, organizer, buyer] = await ethers.getSigners();
    
    const AdvancedTicketNFT = await ethers.getContractFactory("AdvancedTicketNFT");
    contract = await AdvancedTicketNFT.deploy();
    await contract.waitForDeployment();
  });

  it("Should create an event", async function () {
    await contract.connect(organizer).createEvent(
      "Test Event",
      "Test Venue",
      Math.floor(Date.now() / 1000) + 86400, // Tomorrow
      ethers.parseEther("0.1"), // 0.1 ETH
      100, // Max supply
      250, // 2.5% royalty
      2, // Max 2 resales
      "QmTestTermsHash"
    );

    const event = await contract.getEvent(0);
    expect(event.name).to.equal("Test Event");
    expect(event.organizer).to.equal(organizer.address);
  });

  it("Should mint a ticket after accepting terms", async function () {
    // Create event
    await contract.connect(organizer).createEvent(
      "Test Event",
      "Test Venue", 
      Math.floor(Date.now() / 1000) + 86400,
      ethers.parseEther("0.1"),
      100,
      250,
      2,
      "QmTestTermsHash"
    );

    // Accept terms
    await contract.connect(buyer).acceptTerms(0);

    // Mint ticket
    await contract.connect(buyer).mintTicket(
      0, // Event ID
      ["John Doe"], // Attendee names
      ["john@example.com"], // Attendee emails
      ["ID123456789"], // Attendee IDs
      "qr_hash_123", // QR code hash
      "ipfs://token-uri", // Token URI
      { value: ethers.parseEther("0.1") }
    );

    expect(await contract.balanceOf(buyer.address)).to.equal(1);
  });
});
```

Run tests:
```bash
npx hardhat test
```

## 📊 Gas Estimates

| Function | Estimated Gas | Cost (Polygon @ 35 gwei) |
|----------|---------------|---------------------------|
| Deploy Contract | ~3,500,000 | ~$0.08 |
| Create Event | ~200,000 | ~$0.005 |
| Mint Ticket | ~150,000 | ~$0.004 |
| Check-in Ticket | ~50,000 | ~$0.001 |
| Resale Ticket | ~100,000 | ~$0.002 |

## 🔧 Contract Interaction Examples

### Creating an Event

```javascript
const contract = new ethers.Contract(contractAddress, abi, signer);

await contract.createEvent(
  "My Amazing Event",           // Event name
  "Convention Center",          // Venue
  1735689600,                  // Unix timestamp (Jan 1, 2025)
  ethers.parseEther("0.05"),   // Price: 0.05 ETH
  500,                         // Max supply: 500 tickets
  250,                         // Royalty: 2.5% (250 basis points)
  3,                           // Max resales: 3
  "QmTermsHashFromIPFS"        // IPFS hash of terms
);
```

### Minting a Ticket

```javascript
// First, accept terms
await contract.acceptTerms(eventId);

// Then mint ticket
await contract.mintTicket(
  eventId,
  ["Alice Smith", "Bob Johnson"],     // Attendee names
  ["alice@email.com", "bob@email.com"], // Attendee emails  
  ["ID123456", "ID789012"],           // Attendee IDs
  "qr_code_hash_xyz",                 // QR code hash
  "ipfs://metadata-uri",              // Token metadata URI
  { value: ethers.parseEther("0.05") } // Payment
);
```

## 🔍 Contract Verification

After deployment, verify your contract on the block explorer:

```bash
npx hardhat verify --network mumbai CONTRACT_ADDRESS
```

## 📚 Additional Resources

- **OpenZeppelin Contracts**: https://docs.openzeppelin.com/contracts/
- **Hardhat Documentation**: https://hardhat.org/docs
- **ERC-721 Standard**: https://eips.ethereum.org/EIPS/eip-721
- **ERC-2981 Royalty Standard**: https://eips.ethereum.org/EIPS/eip-2981
- **Polygon Documentation**: https://docs.polygon.technology/

## 🆘 Troubleshooting

### Common Issues

1. **"Insufficient funds" error**: Make sure you have enough ETH/MATIC for gas fees
2. **"Nonce too high" error**: Reset your MetaMask account or wait for pending transactions
3. **Contract verification fails**: Wait longer for block confirmations before verifying
4. **Gas estimation fails**: Check if all function parameters are valid

### Getting Help

- Check the Hardhat documentation for deployment issues
- Use Polygon/Ethereum block explorers to debug transactions
- Test on testnets before mainnet deployment

## 📄 License

This contract is released under the MIT License.

---

**⚠️ Important Security Notes:**
- Always test on testnets first
- Never share your private keys
- Audit your contract before mainnet deployment
- Consider using a multisig wallet for contract ownership
- Keep your dependencies updated

Happy deploying! 🚀
```