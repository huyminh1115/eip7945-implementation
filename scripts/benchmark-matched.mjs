import { execFileSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { AbiCoder } from "ethers";
import { buildBabyjub } from "circomlibjs";
import hre from "hardhat";
import provenance from "./paper-provenance.cjs";
import assert from "node:assert/strict";

const TRIALS = Number(process.env.BENCHMARK_TRIALS ?? 30);
if (!Number.isInteger(TRIALS) || TRIALS < 2) throw new Error("BENCHMARK_TRIALS must be an integer of at least 2");
const EPOCH_LENGTH = 20n;
const DECIMALS = 4;
const MAX = 4294967295n;
const DEPOSIT_AMOUNT = 100n;
const abiCoder = new AbiCoder();
const outputDir = process.env.BENCHMARK_RESULTS_DIR ?? path.join(process.cwd(), "results", "proof-validating-gas");
const circomDir = path.resolve(process.cwd(), "circom");
const snarkjs = path.join(process.cwd(), "node_modules", ".bin", "snarkjs");

function mean(values) { return values.reduce((total, value) => total + Number(value), 0) / values.length; }
function sampleStddev(values) {
  const average = mean(values);
  return Math.sqrt(values.reduce((total, value) => total + (Number(value) - average) ** 2, 0) / (values.length - 1));
}
function encodeTransferValue(points) {
  return abiCoder.encode(
    ["tuple(uint256,uint256)", "tuple(uint256,uint256)", "tuple(uint256,uint256)"],
    points.map((point) => [point.x, point.y]),
  );
}
function encodeProof(proof) {
  return abiCoder.encode(["uint256[8]"], [[
    BigInt(proof.pi_a[0]), BigInt(proof.pi_a[1]),
    BigInt(proof.pi_b[0][1]), BigInt(proof.pi_b[0][0]),
    BigInt(proof.pi_b[1][1]), BigInt(proof.pi_b[1][0]),
    BigInt(proof.pi_c[0]), BigInt(proof.pi_c[1]),
  ]]);
}
function pointSignal(point) {
  const [x, y] = Array.isArray(point) ? point : [point.x, point.y];
  return [x.toString(), y.toString()];
}
function pointCoordinates(point) {
  const [x, y] = Array.isArray(point) ? point : [point.x, point.y];
  return { x: BigInt(x), y: BigInt(y) };
}
function artifactMetadata(file) {
  return { path: path.relative(process.cwd(), file), sha256: crypto.createHash("sha256").update(fs.readFileSync(file)).digest("hex") };
}

async function createTransferProof({ sender, receiver, senderBalance, senderSecret, amount, remaining, randomness }) {
  const babyjub = await buildBabyjub();
  const F = babyjub.F;
  const toPoint = (point) => ({ x: BigInt(F.toObject(point[0])), y: BigInt(F.toObject(point[1])) });
  const G = babyjub.Base8;
  const senderCoordinates = pointCoordinates(sender);
  const receiverCoordinates = pointCoordinates(receiver);
  const senderPoint = [F.e(senderCoordinates.x), F.e(senderCoordinates.y)];
  const receiverPoint = [F.e(receiverCoordinates.x), F.e(receiverCoordinates.y)];
  const gAmount = babyjub.mulPointEscalar(G, amount);
  const cSend = toPoint(babyjub.addPoint(gAmount, babyjub.mulPointEscalar(senderPoint, randomness)));
  const cReceive = toPoint(babyjub.addPoint(gAmount, babyjub.mulPointEscalar(receiverPoint, randomness)));
  const d = toPoint(babyjub.mulPointEscalar(G, randomness));
  const proofInput = {
    MAX: MAX.toString(), sk: senderSecret.toString(), sAmount: amount.toString(), bRem: remaining.toString(), r: randomness.toString(),
    y: pointSignal(sender), yR: pointSignal(receiver), CL: pointSignal(senderBalance[0]), CR: pointSignal(senderBalance[1]),
    CS: pointSignal(cSend), CRe: pointSignal(cReceive), D: pointSignal(d), counter: senderBalance.counter.toString(),
  };
  const proofWorkspace = fs.mkdtempSync(path.join(os.tmpdir(), "confidential-vault-transfer-proof-"));
  const proofInputPath = path.join(proofWorkspace, "input.json");
  const proofPath = path.join(proofWorkspace, "proof.json");
  const publicPath = path.join(proofWorkspace, "public.json");
  fs.writeFileSync(proofInputPath, JSON.stringify(proofInput));
  execFileSync(snarkjs, ["groth16", "fullprove", proofInputPath, path.join(circomDir, "transfer_js", "transfer.wasm"), path.join(circomDir, "transfer_1.zkey"), proofPath, publicPath], { cwd: circomDir, stdio: "inherit" });
  return { transferValue: encodeTransferValue([cSend, cReceive, d]), proofBytes: encodeProof(JSON.parse(fs.readFileSync(proofPath, "utf8"))) };
}

async function runTrials(name, createFixture) {
  console.log(`Preparing ${name} operation-ready fixture`);
  const testClient = await hre.viem.getTestClient();
  const publicClient = await hre.viem.getPublicClient();
  const fixture = await createFixture();
  let snapshot = fixture.snapshot;
  const gasUsed = [];
  const calldataBytes = [];
  const transactionInputSha256 = [];
  console.log(`Measuring ${name} across exactly ${TRIALS} restored snapshots`);
  for (let trial = 0; trial < TRIALS; trial += 1) {
    await testClient.revert({ id: snapshot });
    snapshot = await testClient.snapshot();
    const hash = await fixture.submit();
    const [receipt, transaction] = await Promise.all([publicClient.waitForTransactionReceipt({ hash }), publicClient.getTransaction({ hash })]);
    assert.equal(receipt.status, "success", `${name}: transaction failed`);
    if (fixture.validate) await fixture.validate();
    transactionInputSha256.push(crypto.createHash("sha256").update(Buffer.from(transaction.input.slice(2), "hex")).digest("hex"));
    gasUsed.push(receipt.gasUsed);
    calldataBytes.push((transaction.input.length - 2) / 2);
  }
  return { gasUsed: gasUsed.map(String), calldataBytes, transactionInputSha256, statistics: { meanGas: mean(gasUsed), sampleStddevGas: sampleStddev(gasUsed), meanCalldataBytes: mean(calldataBytes), sampleStddevCalldataBytes: sampleStddev(calldataBytes) } };
}

async function deployProofValidatingFixture() {
  const accounts = await hre.viem.getWalletClients();
  const helper = await hre.viem.deployContract("BabyJubTestHelper", []);
  const manager = accounts[0];
  const depositor = accounts[1];
  const managerPoint = await helper.read.mulBase([1n]);
  const userPoint = await helper.read.mulBase([2n]);
  const asset = await hre.viem.deployContract("ZKToken", ["Asset", "AST", DECIMALS, EPOCH_LENGTH]);
  const vault = await hre.viem.deployContract("ConfidentialVault", ["Confidential Vault", "CVLT", DECIMALS, EPOCH_LENGTH, asset.address, manager.account.address, managerPoint, 0]);
  await asset.write.registerAccount([managerPoint], { account: manager.account });
  await asset.write.registerAccount([userPoint], { account: depositor.account });
  await vault.write.registerAccount([userPoint], { account: depositor.account });
  await asset.write.mint({ account: depositor.account, value: 1n * 10n ** 18n });
  const testClient = await hre.viem.getTestClient();
  await testClient.mine({ blocks: EPOCH_LENGTH });
  await asset.write.rollOver([depositor.account.address], { account: depositor.account });
  await vault.write.activate({ account: manager.account });
  return { accounts, asset, vault, manager, depositor, managerPoint, userPoint, testClient };
}

async function assertEncryptedBalance(token, address, secret, amount) {
  const babyjub = await buildBabyjub();
  const F = babyjub.F;
  const publicClient = await hre.viem.getPublicClient();
  const epoch = await publicClient.getBlockNumber() / EPOCH_LENGTH + 1n;
  const balance = (await token.read.simulateAccounts([[address], epoch]))[0];
  const left = pointCoordinates(balance[0]); const right = pointCoordinates(balance[1]);
  const mask = babyjub.mulPointEscalar([F.e(right.x), F.e(right.y)], secret);
  const clear = babyjub.addPoint([F.e(left.x), F.e(left.y)], [F.neg(mask[0]), mask[1]]);
  const expected = babyjub.mulPointEscalar(babyjub.Base8, amount);
  assert(F.eq(clear[0], expected[0]) && F.eq(clear[1], expected[1]), `encrypted balance mismatch: ${address}, expected ${amount}`);
}

async function depositFixture() {
  const fixture = await deployProofValidatingFixture();
  const senderBalance = [await fixture.asset.read.acc([fixture.depositor.account.address, 0n]), await fixture.asset.read.acc([fixture.depositor.account.address, 1n])];
  senderBalance.counter = await fixture.asset.read.counter([fixture.depositor.account.address]);
  const proof = await createTransferProof({ sender: fixture.userPoint, receiver: fixture.managerPoint, senderBalance, senderSecret: 2n, amount: DEPOSIT_AMOUNT, remaining: 10n ** BigInt(DECIMALS) - DEPOSIT_AMOUNT, randomness: 7n });
  const snapshot = await fixture.testClient.snapshot();
  return { snapshot, submit: () => fixture.vault.write.confidentialDeposit([proof.transferValue, proof.proofBytes], { account: fixture.depositor.account }), validate: async () => {
    await assertEncryptedBalance(fixture.asset, fixture.depositor.account.address, 2n, 9900n);
    await assertEncryptedBalance(fixture.asset, fixture.manager.account.address, 1n, 100n);
    await assertEncryptedBalance(fixture.vault, fixture.depositor.account.address, 2n, 100n);
  } };
}

async function withdrawFixture() {
  const fixture = await deployProofValidatingFixture();
  const depositBalance = [await fixture.asset.read.acc([fixture.depositor.account.address, 0n]), await fixture.asset.read.acc([fixture.depositor.account.address, 1n])];
  depositBalance.counter = await fixture.asset.read.counter([fixture.depositor.account.address]);
  const depositProof = await createTransferProof({ sender: fixture.userPoint, receiver: fixture.managerPoint, senderBalance: depositBalance, senderSecret: 2n, amount: DEPOSIT_AMOUNT, remaining: 10n ** BigInt(DECIMALS) - DEPOSIT_AMOUNT, randomness: 7n });
  await fixture.vault.write.confidentialDeposit([depositProof.transferValue, depositProof.proofBytes], { account: fixture.depositor.account });
  await fixture.testClient.mine({ blocks: EPOCH_LENGTH });
  await fixture.asset.write.rollOver([fixture.manager.account.address], { account: fixture.manager.account });
  await fixture.vault.write.rollOver([fixture.depositor.account.address], { account: fixture.depositor.account });
  await fixture.vault.write.rollOver([fixture.manager.account.address], { account: fixture.manager.account });
  const senderBalance = [await fixture.asset.read.acc([fixture.manager.account.address, 0n]), await fixture.asset.read.acc([fixture.manager.account.address, 1n])];
  senderBalance.counter = await fixture.asset.read.counter([fixture.manager.account.address]);
  const proof = await createTransferProof({ sender: fixture.managerPoint, receiver: fixture.userPoint, senderBalance, senderSecret: 1n, amount: DEPOSIT_AMOUNT, remaining: 0n, randomness: 11n });
  const snapshot = await fixture.testClient.snapshot();
  return { snapshot, submit: () => fixture.vault.write.confidentialWithdraw([proof.transferValue, proof.proofBytes], { account: fixture.depositor.account }), validate: async () => {
    await assertEncryptedBalance(fixture.asset, fixture.depositor.account.address, 2n, 10000n);
    await assertEncryptedBalance(fixture.asset, fixture.manager.account.address, 1n, 0n);
    await assertEncryptedBalance(fixture.vault, fixture.depositor.account.address, 2n, 0n);
  } };
}

async function updateRateFixture() {
  const accounts = await hre.viem.getWalletClients();
  const publicClient = await hre.viem.getPublicClient();
  const testClient = await hre.viem.getTestClient();
  const manager = accounts[0];
  const helper = await hre.viem.deployContract("BabyJubTestHelper", []);
  const managerPoint = await helper.read.mulBase([2n]);
  const asset = await hre.viem.deployContract("ZKToken", ["Asset", "AST", DECIMALS, EPOCH_LENGTH]);
  const vault = await hre.viem.deployContract("ConfidentialVault", ["Confidential Vault", "CVLT", DECIMALS, EPOCH_LENGTH, asset.address, manager.account.address, managerPoint, 0]);
  await asset.write.registerAccount([managerPoint], { account: manager.account });
  await asset.write.mint({ account: manager.account, value: 100n * 10n ** 14n });
  await vault.write.mint({ account: manager.account, value: 300n * 10n ** 14n });
  await testClient.mine({ blocks: EPOCH_LENGTH });
  await asset.write.rollOver([manager.account.address], { account: manager.account });
  await vault.write.rollOver([manager.account.address], { account: manager.account });
  const epoch = await publicClient.getBlockNumber() / EPOCH_LENGTH;
  const assetBalance = (await asset.read.simulateAccounts([[manager.account.address], epoch]))[0];
  const shareBalance = (await vault.read.simulateAccounts([[manager.account.address], epoch]))[0];
  const proofInput = { y: pointSignal(managerPoint), AL: pointSignal(assetBalance[0]), AR: pointSignal(assetBalance[1]), SL: pointSignal(shareBalance[0]), SR: pointSignal(shareBalance[1]), rtp: "3", sk: "2", s: "300", a: "100", r: "0" };
  const proofWorkspace = fs.mkdtempSync(path.join(os.tmpdir(), "confidential-vault-rate-proof-"));
  const inputPath = path.join(proofWorkspace, "input.json"); const proofPath = path.join(proofWorkspace, "proof.json"); const publicPath = path.join(proofWorkspace, "public.json");
  fs.writeFileSync(inputPath, JSON.stringify(proofInput));
  execFileSync(snarkjs, ["groth16", "fullprove", inputPath, path.join(circomDir, "updateRate_js", "updateRate.wasm"), path.join(circomDir, "updateRate.zkey"), proofPath, publicPath], { cwd: circomDir, stdio: "inherit" });
  const proofBytes = encodeProof(JSON.parse(fs.readFileSync(proofPath, "utf8")));
  const snapshot = await testClient.snapshot();
  return { snapshot, submit: () => vault.write.updateRatio([3n, proofBytes], { account: manager.account }), validate: async () => assert.equal(await vault.read.ratio(), 3n) };
}

async function ozDepositFixture() {
  const accounts = await hre.viem.getWalletClients(); const testClient = await hre.viem.getTestClient();
  const asset = await hre.viem.deployContract("BenchmarkAsset", []); const vault = await hre.viem.deployContract("OpenZeppelinERC4626Baseline", [asset.address]); const user = accounts[1];
  await asset.write.mint([user.account.address, 10_000n], { account: accounts[0].account });
  await asset.write.approve([vault.address, 10_000n], { account: user.account });
  const snapshot = await testClient.snapshot();
  return { snapshot, submit: () => vault.write.deposit([100n, user.account.address], { account: user.account }), validate: async () => { assert.equal(await asset.read.balanceOf([vault.address]), 100n); assert.equal(await vault.read.balanceOf([user.account.address]), 100n); } };
}
async function ozWithdrawFixture() {
  const accounts = await hre.viem.getWalletClients(); const testClient = await hre.viem.getTestClient();
  const asset = await hre.viem.deployContract("BenchmarkAsset", []); const vault = await hre.viem.deployContract("OpenZeppelinERC4626Baseline", [asset.address]); const user = accounts[1];
  await asset.write.mint([user.account.address, 10_000n], { account: accounts[0].account });
  await asset.write.approve([vault.address, 10_000n], { account: user.account });
  await vault.write.deposit([100n, user.account.address], { account: user.account });
  const snapshot = await testClient.snapshot();
  return { snapshot, submit: () => vault.write.withdraw([100n, user.account.address, user.account.address], { account: user.account }), validate: async () => { assert.equal(await asset.read.balanceOf([vault.address]), 0n); assert.equal(await vault.read.balanceOf([user.account.address]), 0n); } };
}

async function main() {
  fs.mkdirSync(outputDir, { recursive: true });
  if (fs.existsSync(path.join(outputDir, "zether-matched-gas.json"))) throw new Error("Refusing to overwrite matched results");
  const results = {
    schemaVersion: 3, campaign: "local-matched-2026-10-09", provenance: provenance(hre), workloads: { initialUserAssets: "10000", depositAssets: "100", withdrawAssets: "100", zkAssetDecimals: 4, zkEncodedDepositRatio: "1", zkRateAssets: "100", zkRateShares: "300", note: "Deposit/withdraw use 100 raw asset units at one share per asset; rate fixtures use 300 shares and 100 assets. Token units, custody and rate encoding remain implementation-specific." }, generatedAt: new Date().toISOString(),
    methodology: { trials: TRIALS, metric: "transaction receipt gasUsed and submitted transaction input bytes", reset: "Each trial reverts to the operation-ready Hardhat snapshot before the measured transaction.", standardDeviation: "sample (n - 1)", compiler: "solc 0.8.28; optimizer enabled with 200 runs; viaIR true", zetherProofs: "Deposit and withdraw use one real Groth16 transfer proof generated against the exact operation-ready sender account state; every trial submits that proof and the ZKToken verifier validates it.", openZeppelinBaseline: "OpenZeppelin Contracts ERC4626 v5.4.0, measured by this same Hardhat harness; approvals and operation setup are excluded from the timed transaction." },
    artifacts: { transferWasm: artifactMetadata(path.join(circomDir, "transfer_js", "transfer.wasm")), transferZkey: artifactMetadata(path.join(circomDir, "transfer_1.zkey")), updateRateWasm: artifactMetadata(path.join(circomDir, "updateRate_js", "updateRate.wasm")), updateRateZkey: artifactMetadata(path.join(circomDir, "updateRate.zkey")) },
    host: { platform: process.platform, arch: process.arch, node: process.version, cpus: os.cpus(), totalMemoryBytes: os.totalmem() },
    operations: { zether: { deposit: await runTrials("Zether deposit", depositFixture), withdraw: await runTrials("Zether withdraw", withdrawFixture), updateRate: await runTrials("Zether rate update", updateRateFixture) }, openZeppelinErc4626: { deposit: await runTrials("OpenZeppelin ERC-4626 deposit", ozDepositFixture), withdraw: await runTrials("OpenZeppelin ERC-4626 withdraw", ozWithdrawFixture) } },
  };
  const outputPath = path.join(outputDir, "zether-matched-gas.json"); fs.writeFileSync(outputPath, JSON.stringify(results, null, 2));
  console.log(`Wrote raw observations to ${outputPath}`);
  for (const [family, operations] of Object.entries(results.operations)) for (const [name, result] of Object.entries(operations)) console.log(`${family}.${name}: ${result.statistics.meanGas.toFixed(0)} gas; ${result.statistics.meanCalldataBytes.toFixed(0)} calldata bytes (n=${TRIALS})`);
}
main().catch((error) => { console.error(error); process.exitCode = 1; });
