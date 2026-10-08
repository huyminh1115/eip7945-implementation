# Paper reproduction

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
