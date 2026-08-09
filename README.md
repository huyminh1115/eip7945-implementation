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
- For circuit work: `circom` and `snarkjs` (see [`circom/README`](circom/README))

### Reproduce the standalone-paper benchmarks (Tables 4 and 5)

Use this procedure for the validated **local** Zether measurements. It pins the toolchain, records every observation outside the repository, and leaves the compiler settings in [`hardhat.config.ts`](hardhat.config.ts) unchanged (solc 0.8.28, optimizer 200 runs, `viaIR: true`). Do not override compiler settings on the command line.

1. From this directory, pin Node.js and install the lockfile dependencies:

   ```bash
   export NVM_DIR="$HOME/.nvm"
   . "$NVM_DIR/nvm.sh"
   nvm install 22.16.0
   nvm use 22.16.0
   node --version # v22.16.0
   npm ci
   npx hardhat compile
   ```

2. Create a new dated, local-only result directory. Do **not** write to the protected attested directory used for the published Zama campaign, `~/.cache/confidential-vault-benchmarks/attested-node-v22.16.0-solc-0.8.28-runs-200-viair`.

   ```bash
   RESULTS_ROOT="$HOME/benchmark-results/$(date +%F)-table4-table5"
   mkdir -p "$RESULTS_ROOT"
   ```

3. Before either campaign, verify the generated circuit artifacts. The Table 4 Zether gas runner's `updateRate` fixture requires `circom/updateRate_js/updateRate.wasm` and `circom/updateRate.zkey`; Table 5 additionally requires the corresponding `transfer` and `burn` artifacts. Generated `.wasm` and `.zkey` artifacts are unversioned and ignored, so a clean clone must generate any that are missing.

   ```bash
   for circuit in transfer burn updateRate; do
     test -f "circom/${circuit}_js/${circuit}.wasm" && test -f "circom/${circuit}.zkey" || { echo "Missing artifact for ${circuit}" >&2; exit 1; }
   done
   ```

   If the check reports a missing artifact, regenerate it by following [`circom/README`](circom/README) and the target descriptions in [`circom/Makefile`](circom/Makefile).

4. Run the proof-validating Table 4 gas campaign. The script performs exactly 30 trials per operation, reverts to the same operation-ready Hardhat snapshot before each measured transaction, and records receipt `gasUsed`, submitted-transaction calldata bytes, artifact hashes, toolchain metadata, and all raw observations in `$RESULTS_ROOT/zether-proof-validating-gas.json`. Deposit and withdrawal use the real `ZKToken` asset and a Groth16 transfer proof generated for the exact sender account state; the asset verifier checks that proof in every measured call. The same harness also measures an OpenZeppelin Contracts ERC-4626 v5.4.0 reference vault (approval and setup are excluded from the measured operation).

   ```bash
   BENCHMARK_TRIALS=30 BENCHMARK_RESULTS_DIR="$RESULTS_ROOT" npx hardhat run scripts/benchmark-gas.mjs
   ```

5. Run the Table 5 circuit timing campaign. It writes the 30 per-circuit measurements and summary statistics to `$RESULTS_ROOT/proof-timings.json`.

   ```bash
   BENCHMARK_RESULTS_DIR="$RESULTS_ROOT" node scripts/benchmark-proofs.mjs
   ```

   Proof time is `groth16.prove` only, with the witness generated before timing. Verification time is `groth16.verify` only, after the verification key, proof, and public signals are in memory. There are no warm-up trials. Timing results are therefore host-dependent; record the machine, OS, and Node version with every campaign.

#### Reference values, not cross-host guarantees

The proof-validating campaign saved in [`results/proof-validating-2026-07-30/zether-proof-validating-gas.json`](results/proof-validating-2026-07-30/zether-proof-validating-gas.json) ran on Apple M1 Pro / macOS arm64 / Node 23.11.0. Its 30-trial receipt-gas means (all sample standard deviations zero) were:

| Operation | OpenZeppelin ERC-4626 | Zether Vault | Submitted calldata |
| --- | ---: | ---: | ---: |
| deposit | 109,815 | 842,897 | 68 / 580 bytes |
| withdraw | 44,736 | 712,360 | 100 / 580 bytes |
| rate update | n/a | 335,573 | n/a / 356 bytes |

The previously reported Table 5 values were:

| Circuit    | Prove (ms, mean ± sample SD) | Verify (ms, mean ± sample SD) |
| ---------- | ---------------------------: | ----------------------------: |
| transfer   |               870.98 ± 48.35 |                   8.10 ± 0.28 |
| burn       |               420.32 ± 10.91 |                   9.31 ± 0.19 |
| updateRate |                534.74 ± 9.67 |                   9.51 ± 0.21 |

These figures are references, not expected identical results on another host. The Zether deposit and withdrawal fixtures use the real `ZKToken` asset and non-empty Groth16 transfer proofs, so the reported path includes on-chain asset-side proof verification. The ERC-4626 reference is measured under the same local harness but is not privacy-equivalent; approval and setup remain excluded, and the paper makes no percentage-overhead claim from it. Node 23.11.0 is outside Hardhat's supported Node range, so reproduce on a supported pinned Node version before treating the measurements as release-quality cross-host baselines.

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
  receiverAddress,
);

// Approve allowance
await client.confidentialApprove(
  privacyToken,
  publicClient,
  "500",
  spenderAddress,
);

// Transfer from (spender)
await client.confidentialTransferFrom(
  privacyToken,
  fromAddress,
  toAddress,
  "100",
);

// Read balances and allowances
const balance = await client.getCurrentBalance(privacyToken, publicClient);
const allowanceData = await client.readSpenderAllowance(
  privacyToken,
  spenderAddress,
);
```

### Circom workflow

Generated circuit `.wasm` and `.zkey` artifacts under `circom/` are unversioned and ignored; generate them when they are missing. To rebuild or modify circuits:

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
