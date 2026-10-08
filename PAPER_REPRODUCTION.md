# Matched local campaign

Use Node **22.16.0**, then run `make reproduce-matched` from the repository root. For an installed checkout, `make benchmark-matched` skips dependency installation. The script requires Hardhat **2.26.3** and performs exactly 30 restored-snapshot trials per operation; it creates a new temporary results directory and prints its path. Set `BENCHMARK_RESULTS_DIR` to a fresh directory to keep results elsewhere. Existing observations are never overwritten.

`hardhat.paper.config.ts` explicitly fixes solc 0.8.28, optimizer 200, viaIR, Cancun compiler target, IPFS metadata, Prague Hardhat execution, chain ID 31337, automatic mining, initial base fee 1 gwei, block gas limit 30 million, and a common starting date and public test mnemonic. It leaves the normal deployment configuration unchanged. The new FHE lockfile aligns Hardhat to the ZK repository's version.

All three implementations start with 10,000 raw user asset units, deposit 100 units into an empty vault at one share per asset, or fully withdraw the preceding 100-unit deposit. Rate-update fixtures contain 100 assets and 300 shares, prepared by owner-authorized minting outside measurement. ZK uses ratio precision 0 (encoded initial ratio 1 and new ratio 3); FHE uses six-decimal ratios (1,000,000 and 3,000,000). Token decimals and custody/authorization models differ; equal raw amounts are not a claim of identical token economics or security. No production contract is changed.

Every measured receipt must succeed. The harness checks share/asset outcomes after deposit and withdrawal and verifies the updated ratio after finalization. ZK ciphertext checks include pending settlement; FHE checks decrypt local mock balances. These checks happen outside the measured transaction and do not constitute a general security proof. Off-chain proving, encryption, decryption, deployment and setup are excluded from receipt gas. The same encrypted/proof input is reused after each snapshot restore; zero within-run SD is not zero between-run variance. Fresh cryptographic payload bytes may alter intrinsic gas between campaigns.

Outputs contain all gas and calldata samples, input hashes, sample statistics, exact source commit, source/lock/config SHA-256 hashes, actual compiler build settings, Hardhat/EDR versions and host metadata. Use raw means for the gas/calldata table; FHE rate gas sums the three stage means. The FHE runtime remains **mocked** and excludes coprocessor computation, real relayer/decryption latency and service fees. Matching local conditions does not establish an end-to-end production ZK–FHE performance ranking.

The gas output is `zether-matched-gas.json`. Matching generated transfer/rate WASM and proving keys are still required, as explained below. The proof-performance table is a separate historical timing experiment and is not replaced by this gas run.

# Earlier campaign commands

Run from this repository root, using Node 22.16.0 and npm:

```sh
make setup
# Prepare matching circuit artifacts as described below.
make check
make benchmark
```

`make reproduce` combines dependency installation and benchmarking when the circuit artifacts are already prepared. `make help` lists the targets. No contract, circuit, benchmark fixture, trial count, or compiler setting is changed by these helpers.

## Generated circuit prerequisites

The public repository does not track generated circuit files. Follow `circom/README` and `circom/Makefile` to compile and prepare them. The gas runner requires `circom/transfer_1.zkey` and `circom/updateRate.zkey`; the proof runner requires `circom/transfer.zkey`, `circom/burn.zkey`, and `circom/updateRate.zkey`. All three circuits need their `.r1cs`, generated witness JavaScript, and `.wasm` files under `circom/`.

The gas proofs must match the verification keys embedded in `contracts/Verifier/Verifier.sol` and `contracts/Verifier/UpdateRateVerifier.sol`. Generating new proving keys alone does not make them match those contracts. Either obtain the matching historical artifacts, or use a separate local experimental checkout to generate a new setup and update the corresponding verifiers. A new setup is a new campaign, not exact reproduction of the historical artifact hashes. These helpers deliberately do not replace verifier contracts or create a trusted setup.

`make check` checks file presence only; successful proof verification during the gas benchmark remains necessary. Missing artifacts stop the helper before compilation or measurement.

## Outputs and table construction

By default, `make benchmark` creates a fresh temporary directory and prints its path. To select a persistent location:

```sh
BENCHMARK_RESULTS_DIR=/path/to/new-results make benchmark
```

An existing output file is never overwritten by the helper. It runs the existing 30-trial gas and proof scripts and writes:

- `zether-proof-validating-gas.json`: raw receipt gas and input-byte samples, means, host metadata, and artifact hashes. Used for the ZK/OpenZeppelin panel of the paper's gas/calldata table.
- `proof-timings.json`: 30-trial proof and verification means and sample standard deviations. Witness generation and circuit setup are outside the timed intervals.
- `circuit-constraints.txt`: `snarkjs r1cs info` output for transfer, burn, and updateRate. Used with the timing JSON for the proof-performance table.

The retained gas reference is in `results/proof-validating-2026-07-30/`. Timing varies by host; new runs do not replace the published measurements. The helper does not enforce the disclosure policy or establish a security proof.
