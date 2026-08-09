#!/usr/bin/env node
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { groth16, zKey } from "snarkjs";

const TRIALS = 30;
const root = path.resolve(import.meta.dirname, "..");
const circomDir = path.join(root, "circom");
const outputDir = process.env.BENCHMARK_RESULTS_DIR ?? path.join(os.homedir(), ".cache", "confidential-vault-benchmarks");
fs.mkdirSync(outputDir, { recursive: true });
const workspace = fs.mkdtempSync(path.join(os.tmpdir(), "confidential-vault-proof-benchmark-"));

const updateRateInput = {
  y: [
    "21847968061825297417219090225605021230077606664375979689919232609498569628310",
    "19655704534932545550903049736104505487372785233094657404723345615117009132870",
  ],
  AL: [
    "19913089679697415007456171286850173965941594722394544287682681932370624161554",
    "16691783016056440127596135679558445801614876225350623617988464024160202937103",
  ],
  AR: [
    "21250303381939017779044479110401165095087251070101601897839228014167614956565",
    "8631462370285116201251094250575472240420777528927167005944178639952184516419",
  ],
  SL: [
    "21024102262674999567442865209181863983219561274716314977301055184471906226002",
    "6280655499514562410886684255856339417484049148346211722108814120278049876970",
  ],
  SR: [
    "14877774218458610039080554039154811625655974620646956480198563046257336714749",
    "344491186362969621141690228901407503308681391025433473292162645611300200348",
  ],
  rtp: "33",
  sk: "989684980841917356420192175194090137718385886803255486827734521826538409888",
  s: "10000",
  a: "300",
  r: "100",
};

function mean(values) {
  return values.reduce((total, value) => total + value, 0) / values.length;
}

function sampleStddev(values) {
  const average = mean(values);
  return Math.sqrt(values.reduce((total, value) => total + (value - average) ** 2, 0) / (values.length - 1));
}

function writeInput(name, source) {
  const inputPath = path.join(workspace, `${name}.input.json`);
  fs.writeFileSync(inputPath, JSON.stringify(source));
  return inputPath;
}

function prepareWitness(name, input) {
  const inputPath = typeof input === "string" ? input : writeInput(name, input);
  const witnessPath = path.join(workspace, `${name}.wtns`);
  execFileSync(
    process.execPath,
    [path.join(circomDir, `${name}_js`, "generate_witness.js"), path.join(circomDir, `${name}_js`, `${name}.wasm`), inputPath, witnessPath],
    { cwd: circomDir, stdio: "inherit" },
  );
  return witnessPath;
}

async function benchmarkCircuit(name, input) {
  const witnessPath = prepareWitness(name, input);
  const zkey = path.join(circomDir, `${name}.zkey`);
  const verificationKey = await zKey.exportVerificationKey(zkey);

  const proveTimesMs = [];
  let finalProof;
  let finalPublicSignals;
  for (let trial = 0; trial < TRIALS; trial += 1) {
    const started = process.hrtime.bigint();
    const { proof, publicSignals } = await groth16.prove(zkey, witnessPath);
    proveTimesMs.push(Number(process.hrtime.bigint() - started) / 1e6);
    finalProof = proof;
    finalPublicSignals = publicSignals;
  }

  const verifyTimesMs = [];
  for (let trial = 0; trial < TRIALS; trial += 1) {
    const started = process.hrtime.bigint();
    const verified = await groth16.verify(verificationKey, finalPublicSignals, finalProof);
    verifyTimesMs.push(Number(process.hrtime.bigint() - started) / 1e6);
    if (!verified) throw new Error(`${name}: generated proof did not verify`);
  }

  return {
    proveMs: proveTimesMs,
    verifyMs: verifyTimesMs,
    statistics: {
      proveMeanMs: mean(proveTimesMs),
      proveSampleStddevMs: sampleStddev(proveTimesMs),
      verifyMeanMs: mean(verifyTimesMs),
      verifySampleStddevMs: sampleStddev(verifyTimesMs),
    },
  };
}

const results = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  methodology: {
    trials: TRIALS,
    warmups: 0,
    proveInterval: "groth16.prove only; witnesses were generated before timing",
    verifyInterval: "groth16.verify only; verification key, proof, and public signals were loaded before timing",
    standardDeviation: "sample (n - 1)",
  },
  host: {
    platform: process.platform,
    arch: process.arch,
    node: process.version,
    cpus: os.cpus(),
    totalMemoryBytes: os.totalmem(),
  },
  circuits: {
    transfer: await benchmarkCircuit("transfer", path.join(circomDir, "inputs", "transfer_input.json")),
    burn: await benchmarkCircuit("burn", path.join(circomDir, "inputs", "burn_input.json")),
    updateRate: await benchmarkCircuit("updateRate", updateRateInput),
  },
};

const outputPath = path.join(outputDir, "proof-timings.json");
fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
console.log(`Wrote proof benchmark observations to ${outputPath}`);
for (const [name, result] of Object.entries(results.circuits)) {
  const stats = result.statistics;
  console.log(`${name}: prove ${stats.proveMeanMs.toFixed(2)} ± ${stats.proveSampleStddevMs.toFixed(2)} ms; verify ${stats.verifyMeanMs.toFixed(2)} ± ${stats.verifySampleStddevMs.toFixed(2)} ms`);
}
