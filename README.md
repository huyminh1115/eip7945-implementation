## PrivacyToken - EIP-7945 Implementation

This project implements a privacy-preserving token contract based on EIP-7945 (Confidential Transactions Supported Token) using Zether protocol on BabyJub with Circom proofs.

- **EIP-7945 Compliance**: Implements the standard interface for confidential token contracts ([link](https://ethereum-magicians.org/t/eip-7945-confidential-transactions-supported-token/))
- **Zether Protocol**: Based on [paper](https://eprint.iacr.org/2019/191.pdf) (page 13) with BabyJub curve
- **Zero-Knowledge Proofs**: Circom circuits for confidential transfers, burns, and approvals
- **Solidity contracts**: `contracts/PrivacyToken.sol`, `contracts/BabyJub.sol`, `contracts/Verifier/`
- **TypeScript client**: `client/Client.ts` with simplified API
- **Test suite**: `test/Test.ts` with comprehensive EIP-7945 flow tests

### Quickstart

1. Install dependencies

```bash
npm install
```

2. Compile contracts

```bash
npx hardhat compile
```

3. Run tests

```bash
npx hardhat test
```

### Requirements

- Node.js 18+
- npm (or pnpm/yarn)
- For circuit work: `circom` and `snarkjs` (see `circom/README`)

### How it works (high-level)

- **EIP-7945 Interface**: Standard methods for confidential transactions (`confidentialTransfer`, `confidentialApprove`, `confidentialTransferFrom`, `confidentialBalanceOf`)
- **Epoch-based accounting**: Pending changes are applied when the next epoch starts (`epochLength` blocks)
- **Zero-Knowledge Proofs**: Circom circuits attest to valid balance updates without revealing amounts
- **Confidential Allowances**: Support for third-party transfers with encrypted allowance tracking

### Client API

The `Client` class provides a simplified interface for interacting with the PrivacyToken contract:

```typescript
// Create client with wallet account
const client = new Client(walletAccount, MAX);

// Register account with Schnorr signature
await client.registerAccount(privacyToken);

// Mint tokens by sending ETH
await client.mint(privacyToken, "1.0"); // 1 ETH

// Confidential transfer
await client.confidentialTransfer(
  privacyToken,
  publicClient,
  "1000",
  receiverAddress
);

// Approve allowance
await client.confidentialApprove(
  privacyToken,
  publicClient,
  "500",
  spenderAddress
);

// Transfer from (spender)
await client.confidentialTransferFrom(
  privacyToken,
  fromAddress,
  toAddress,
  "100"
);

// Read balances and allowances
const balance = await client.getCurrentBalance(privacyToken, publicClient);
const allowanceData = await client.readSpenderAllowance(
  privacyToken,
  spenderAddress
);
```

### Circom workflow

Pre-built artifacts for transfer/burn/transferFrom are included under `circom/`. To rebuild or modify circuits:

```bash
# inside ./circom
make compile name=circom-file-name
make power power=power name=circom-file-name
make solidity name=circom-file-name
```

### Project structure

- `contracts/` — Solidity sources (PrivacyToken, BabyJub, Verifiers)
- `contracts/interfaces/` — EIP-7945 interface definitions
- `circom/` — circuits, proving/verifying keys, wasm, Makefile
- `client/` — TypeScript client with simplified API
- `test/` — Hardhat tests for EIP-7945 flows (register, mint, transfer, approve, transferFrom)

### Common tasks

```bash
# Compile contracts
npx hardhat compile

# Run tests with gas report
npx hardhat test
```

### Testing notes

The test suite covers all EIP-7945 core flows:

1. **Account Registration**: Schnorr signature-based account setup
2. **Minting**: ETH → token conversion with epoch-based accounting
3. **Confidential Transfers**: Private transfers between registered accounts
4. **Burning**: Token → ETH conversion with balance reduction
5. **Metadata**: EIP-7945 standard methods (name, symbol, decimals, confidentialBalanceOf)
6. **Registration Validation**: Error handling for unregistered accounts
7. **Confidential Approvals**: Allowance management with encrypted values
8. **TransferFrom**: Third-party transfers using allowances

**Key behaviors**:

- Balances move from `pending` → `acc` at the next epoch
- Transfers debit sender immediately; receiver credited after next epoch
- Burns schedule balance reduction for next epoch
- Approvals decrease owner balance immediately; allowances track encrypted amounts for both owner and spender
