#!/bin/sh
# Run from any working directory; keep generated results outside tracked evidence.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
case "${1:-}" in
  ''|--check) ;;
  *) echo "Usage: sh scripts/reproduce-paper.sh [--check]" >&2; exit 2 ;;
esac
if [ ! -x node_modules/.bin/hardhat ]; then
  echo "Dependencies missing. Run make setup first (Node 22.16.0 recommended)." >&2
  exit 1
fi
missing=0
for circuit in transfer burn updateRate; do
  for artifact in "circom/${circuit}.r1cs" "circom/${circuit}.zkey" \
    "circom/${circuit}_js/${circuit}.wasm" \
    "circom/${circuit}_js/generate_witness.js"; do
    if [ ! -f "$artifact" ]; then
      echo "Missing generated artifact: $artifact" >&2
      missing=1
    fi
  done
done
if [ ! -f circom/transfer_1.zkey ]; then
  echo "Missing generated artifact: circom/transfer_1.zkey" >&2
  missing=1
fi
if [ "$missing" -ne 0 ]; then
  echo "See PAPER_REPRODUCTION.md for the circuit and matching-verifier prerequisites." >&2
  exit 1
fi
if [ "${1:-}" = --check ]; then
  echo "Required files are present. This check does not validate proofs or run benchmarks."
  exit 0
fi
BENCHMARK_RESULTS_DIR="${BENCHMARK_RESULTS_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/fisat-zk.XXXXXX")}"
mkdir -p "$BENCHMARK_RESULTS_DIR"
for output in zether-proof-validating-gas.json proof-timings.json circuit-constraints.txt; do
  if [ -e "$BENCHMARK_RESULTS_DIR/$output" ]; then
    echo "Refusing to overwrite $BENCHMARK_RESULTS_DIR/$output. Choose a fresh directory." >&2
    exit 1
  fi
done
export BENCHMARK_RESULTS_DIR
export BENCHMARK_TRIALS=30
printf 'Writing new observations to %s\n' "$BENCHMARK_RESULTS_DIR"
node_modules/.bin/hardhat compile
node_modules/.bin/hardhat run scripts/benchmark-gas.mjs --network hardhat
node scripts/benchmark-proofs.mjs
for circuit in transfer burn updateRate; do
  printf '\n%s\n' "$circuit"
  node_modules/.bin/snarkjs r1cs info "circom/${circuit}.r1cs"
done > "$BENCHMARK_RESULTS_DIR/circuit-constraints.txt"
printf 'Results saved in %s\n' "$BENCHMARK_RESULTS_DIR"
