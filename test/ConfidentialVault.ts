import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { AbiCoder } from "ethers";
import {
  convertSolidityPointToArrayString,
  convertToBabyJubPoints,
  convertToBabyJubPointsArrayString,
  createTransferInput,
  generateBabyJubAccount,
  generateCalldata,
  generateTransferProof,
  getF,
  initializeBabyJub,
  type BabyJubAccount,
} from "../client/ultis";
import { flattenProof } from "../client/ultis/jubjub-util";

const abiCoder = new AbiCoder();
const EPOCH_LENGTH = 20n;
const DECIMALS = 4;
const MAX = 4294967295n;
const TRANSFER_AMOUNT = 100n;
type Point = { x: bigint; y: bigint };

function pointObject(point: Point | readonly [bigint, bigint]): Point {
  return Array.isArray(point) ? { x: point[0], y: point[1] } : point;
}

function encodeTransferValue(points: readonly Point[]) {
  return abiCoder.encode(
    ["tuple(uint256,uint256)", "tuple(uint256,uint256)", "tuple(uint256,uint256)"],
    points.map((point) => [point.x, point.y]),
  ) as `0x${string}`;
}

async function makeAssetTransferProof(
  asset: any,
  senderAddress: `0x${string}`,
  sender: BabyJubAccount,
  receiver: BabyJubAccount,
  amount: bigint,
  remaining: bigint,
  randomness: bigint,
) {
  const accountData = [
    await asset.read.acc([senderAddress, 0n]),
    await asset.read.acc([senderAddress, 1n]),
  ] as const;
  const counter = await asset.read.counter([senderAddress]);
  const [cSend, cReceive, d] = createTransferInput(
    convertToBabyJubPoints(sender.publicKey),
    convertToBabyJubPoints(receiver.publicKey),
    amount,
    randomness,
  );
  const proof = await generateTransferProof({
    MAX: MAX.toString(),
    sk: sender.privateKey.toString(),
    sAmount: amount.toString(),
    bRem: remaining.toString(),
    r: randomness.toString(),
    y: convertSolidityPointToArrayString(sender.publicKey),
    yR: convertSolidityPointToArrayString(receiver.publicKey),
    CL: convertSolidityPointToArrayString(pointObject(accountData[0])),
    CR: convertSolidityPointToArrayString(pointObject(accountData[1])),
    CS: convertToBabyJubPointsArrayString(cSend),
    CRe: convertToBabyJubPointsArrayString(cReceive),
    D: convertToBabyJubPointsArrayString(d),
    counter: counter.toString(),
  });
  const calldata = await generateCalldata(proof.proof, proof.publicSignals);
  return {
    transferValue: encodeTransferValue([cSend, cReceive, d].map((point) => ({ x: BigInt(getF().toObject(point[0]).toString()), y: BigInt(getF().toObject(point[1]).toString()) }))),
    proof: abiCoder.encode(["uint256[8]"], [flattenProof(calldata.pA, calldata.pB, calldata.pC)]) as `0x${string}`,
  };
}

async function nextEpoch() {
  const publicClient = await hre.viem.getPublicClient();
  const testClient = await hre.viem.getTestClient();
  const currentBlock = await publicClient.getBlockNumber();
  await testClient.mine({ blocks: Number(EPOCH_LENGTH - (currentBlock % EPOCH_LENGTH) || EPOCH_LENGTH) });
}

describe("ConfidentialVault proof-validating asset transfers", function () {
  before(async function () { await initializeBabyJub(); });

  async function deployVaultFixture() {
    const accounts = await hre.viem.getWalletClients();
    const manager = accounts[0];
    const depositor = accounts[1];
    const managerKey = generateBabyJubAccount("1");
    const depositorKey = generateBabyJubAccount("2");
    const asset = await hre.viem.deployContract("ZKToken", ["Asset", "AST", DECIMALS, EPOCH_LENGTH]);
    const vault = await hre.viem.deployContract("ConfidentialVault", [
      "Confidential Vault", "CVLT", DECIMALS, EPOCH_LENGTH, asset.address,
      manager.account.address, managerKey.publicKey, 2,
    ]);
    await asset.write.registerAccount([managerKey.publicKey], { account: manager.account });
    await asset.write.registerAccount([depositorKey.publicKey], { account: depositor.account });
    await vault.write.registerAccount([depositorKey.publicKey], { account: depositor.account });
    await asset.write.mint({ account: depositor.account, value: 1n * 10n ** 18n });
    await nextEpoch();
    await asset.write.rollOver([depositor.account.address], { account: depositor.account });
    await vault.write.activate({ account: manager.account });
    return { asset, vault, manager, depositor, managerKey, depositorKey };
  }

  it("rejects empty and invalid proofs, then deposits with a valid Groth16 transfer proof", async function () {
    const { asset, vault, manager, depositor, managerKey, depositorKey } = await loadFixture(deployVaultFixture);
    const valid = await makeAssetTransferProof(asset, depositor.account.address, depositorKey, managerKey, TRANSFER_AMOUNT, 10n ** BigInt(DECIMALS) - TRANSFER_AMOUNT, 7n);
    const beforeCounter = await asset.read.counter([depositor.account.address]);
    const beforeAssetBalance = await asset.read.acc([depositor.account.address, 0n]);

    await expect(vault.write.confidentialDeposit([valid.transferValue, "0x"], { account: depositor.account })).to.be.rejected;
    const invalidProof = abiCoder.encode(["uint256[8]"], [[0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n]]) as `0x${string}`;
    await expect(vault.write.confidentialDeposit([valid.transferValue, invalidProof], { account: depositor.account })).to.be.rejectedWith("Transfer proof verification failed!");
    expect(await asset.read.counter([depositor.account.address])).to.equal(beforeCounter);

    await vault.write.confidentialDeposit([valid.transferValue, valid.proof], { account: depositor.account });
    expect(await asset.read.counter([depositor.account.address])).to.equal(beforeCounter + 1n);
    expect(await asset.read.acc([depositor.account.address, 0n])).to.not.deep.equal(beforeAssetBalance);
    const managerPending = await asset.read.pending([manager.account.address, 0n]);
    expect(managerPending).to.not.deep.equal({ x: 0n, y: 1n });
  });

  it("rejects empty and invalid proofs, then withdraws with a valid manager-side Groth16 transfer proof", async function () {
    const { asset, vault, manager, depositor, managerKey, depositorKey } = await loadFixture(deployVaultFixture);
    const deposit = await makeAssetTransferProof(asset, depositor.account.address, depositorKey, managerKey, TRANSFER_AMOUNT, 10n ** BigInt(DECIMALS) - TRANSFER_AMOUNT, 7n);
    await vault.write.confidentialDeposit([deposit.transferValue, deposit.proof], { account: depositor.account });
    await nextEpoch();
    await asset.write.rollOver([manager.account.address], { account: manager.account });
    await vault.write.rollOver([depositor.account.address], { account: depositor.account });
    await vault.write.rollOver([manager.account.address], { account: manager.account });

    const valid = await makeAssetTransferProof(asset, manager.account.address, managerKey, depositorKey, TRANSFER_AMOUNT, 0n, 11n);
    const beforeCounter = await asset.read.counter([manager.account.address]);
    const beforeManagerBalance = await asset.read.acc([manager.account.address, 0n]);
    await expect(vault.write.confidentialWithdraw([valid.transferValue, "0x"], { account: depositor.account })).to.be.rejected;
    const invalidProof = abiCoder.encode(["uint256[8]"], [[0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n]]) as `0x${string}`;
    await expect(vault.write.confidentialWithdraw([valid.transferValue, invalidProof], { account: depositor.account })).to.be.rejectedWith("Transfer proof verification failed!");
    expect(await asset.read.counter([manager.account.address])).to.equal(beforeCounter);

    await vault.write.confidentialWithdraw([valid.transferValue, valid.proof], { account: depositor.account });
    expect(await asset.read.counter([manager.account.address])).to.equal(beforeCounter + 1n);
    expect(await asset.read.acc([manager.account.address, 0n])).to.not.deep.equal(beforeManagerBalance);
    const userPending = await asset.read.pending([depositor.account.address, 0n]);
    expect(userPending).to.not.deep.equal({ x: 0n, y: 1n });
  });
});
