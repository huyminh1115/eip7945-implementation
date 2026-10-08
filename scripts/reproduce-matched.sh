#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test "$(node --version)" = "v22.16.0" || { echo "Use Node 22.16.0 for the matched campaign." >&2; exit 1; }
test -x node_modules/.bin/hardhat || { echo "Run make setup first." >&2; exit 1; }
test "$(node -p 'require("hardhat/package.json").version')" = "2.26.3" || { echo "Hardhat 2.26.3 is required." >&2; exit 1; }
for artifact in circom/transfer_js/transfer.wasm circom/transfer_1.zkey circom/updateRate_js/updateRate.wasm circom/updateRate.zkey; do
  test -f "$artifact" || { echo "Missing $artifact; see PAPER_REPRODUCTION.md" >&2; exit 1; }
done
BENCHMARK_RESULTS_DIR="${BENCHMARK_RESULTS_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/fisat-matched.zk.XXXXXX")}"
mkdir -p "$BENCHMARK_RESULTS_DIR"
test ! -e "$BENCHMARK_RESULTS_DIR/zether-matched-gas.json" || { echo "Refusing to overwrite matched observations." >&2; exit 1; }
export BENCHMARK_RESULTS_DIR
export BENCHMARK_TRIALS=30
export TS_NODE_TRANSPILE_ONLY=true
node_modules/.bin/hardhat compile --config hardhat.paper.config.ts
node_modules/.bin/hardhat run scripts/benchmark-matched.mjs --config hardhat.paper.config.ts --network hardhat
printf 'Results saved in %s\n' "$BENCHMARK_RESULTS_DIR"
