# API Requirements for Chain Info Provider

This document outlines the requirements for a new API provider to replace the current Etherscan-based implementation. The current system relies heavily on fetching historical token transaction data, which is not available via standard JSON-RPC nodes.

## Core Requirements

### 1. Service Type: Indexer / Account History API
**CRITICAL**: The provider MUST offer an "Indexer" or "History" API. A standard JSON-RPC provider (like basic Infura/Alchemy) is **NOT** sufficient because it does not support querying "all transactions for an address".

The API must support:
- Fetching **ERC-20 token transfer events** for a specific wallet address.
- Filtering by **contract address** (to see only transfers of a specific token, e.g., USDT).
- Pagination support (or block-range filtering).

### 2. Required Data Points
For each transaction/transfer, the API must return:
- **Transaction Hash** (`hash`)
- **Sender Address** (`from`)
- **Recipient Address** (`to`)
- **Block Number** (`blockNumber`) - Used for sorting and anchoring.
- **Transaction Index** (`transactionIndex`) - Used for deterministic sorting within a block.
- **Timestamp** (`timeStamp`)
- **Value** (`value`) - The amount transferred (in raw units/wei).
- **Token Decimals** (`tokenDecimal`) - Required to normalize the amount.

### 3. Chain Support
The provider must support EVM-compatible chains, specifically:
- **Binance Smart Chain (BSC)** (Chain ID: 56)
- **Ethereum Mainnet** (Chain ID: 1)
- *(Optional)* Polygon, Arbitrum, Optimism (for future proofing).

### 4. Specific Endpoints Needed

#### A. Token Transaction History (High Priority)
Equivalent to Etherscan's `module=account&action=tokentx`.
- **Input**: Wallet Address, Contract Address, Start Block.
- **Output**: List of transfers with the fields listed in Section 2.

#### B. Event Logs (Medium Priority)
Equivalent to `eth_getLogs` (often available via standard RPC, but better if indexed).
- **Input**: Contract Address, Topics (Topic 0 = Transfer Event Signature, Topic 2 = Recipient Address).
- **Output**: Log data to verify inbound transfers.

#### C. Current Block Number (Low Priority)
Equivalent to `eth_blockNumber`.
- Standard JSON-RPC method, widely available.

## Integration Considerations

### Compatibility
- **Best Case**: The provider offers an API compatible with the Etherscan V2 spec (e.g., BscScan, PolygonScan). This requires minimal code changes (just URL updates).
- **Alternative**: If the provider uses a different format (e.g., Covalent, Moralis, Alchemy Enhanced APIs), we will need to write a generic `ChainService` adapter to map their response to our `ReceivedTransaction` model.

### Rate Limits & Cost
- **Current Issue**: The motivation for change is cost/paid access.
- **Requirement**: The new provider should have a generous **Free Tier** or low-cost plan that supports the app's polling frequency (currently retries every 3s on rate limit).

## Potential Candidates to Investigate
1.  **Covalent (GoldRush)**: Excellent for multi-chain history.
2.  **Moralis**: Strong "Streams" and history APIs.
3.  **Alchemy**: Has "Transfers API" (Asset Transfers) which is very powerful and might fit.
4.  **Tatum**: Multi-chain API.
5.  **BitQuery**: specialized in indexed data.
6.  **Blockscout**: Open-source explorer, often has free APIs for various chains.

## Summary Checklist for Evaluation
- [ ] Supports BSC & Ethereum?
- [ ] Has "Get ERC20 Transfers by Address" endpoint?
- [ ] Returns `tokenDecimal` in the response? (If not, we need to fetch it separately).
- [ ] Free tier limits (Requests per second/day)?
- [ ] Documentation quality?
