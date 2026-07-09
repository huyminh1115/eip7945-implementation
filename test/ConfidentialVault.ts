import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { AbiCoder } from "ethers";

const abiCoder = new AbiCoder();

const EPOCH_LENGTH = 20n;
const DECIMALS = 4;
const RATIO_DECIMALS = 2;

type Point = { x: bigint; y: bigint };

async function readPointPair(
  contract: any,
  key: "pending" | "acc",
  owner: `0x${string}`
) {
  const first = await contract.read[key]([owner, 0n]);
  const second = await contract.read[key]([owner, 1n]);
  return [first, second] as [Point, Point];
}

async function increaseToNextEpoch() {
  const publicClient = await hre.viem.getPublicClient();
  const testClient = await hre.viem.getTestClient();
  const blockNumber = await publicClient.getBlockNumber();
  const blocksUntilNext = Number(
    EPOCH_LENGTH - (blockNumber % EPOCH_LENGTH) || EPOCH_LENGTH
  );
  await testClient.mine({ blocks: blocksUntilNext });
}

function encodeTransferValue(points: [Point, Point, Point]) {
  return abiCoder.encode(
    [
      "tuple(uint256,uint256)",
      "tuple(uint256,uint256)",
      "tuple(uint256,uint256)",
    ],
    points.map((p) => [p.x, p.y])
  ) as `0x${string}`;
}

describe("ConfidentialVault", function () {
  async function deployVaultFixture() {
    const accounts = await hre.viem.getWalletClients();

    const mockAsset = await hre.viem.deployContract("MockPrivacyTokenAsset", [
      EPOCH_LENGTH,
    ]);
    const helper = await hre.viem.deployContract("BabyJubTestHelper", []);

    const blackHoleAccount = accounts[0].account.address as `0x${string}`;
    const blackHolePoint = await helper.read.basePoint();

    const vault = await hre.viem.deployContract("ConfidentialVault", [
      "Confidential Vault",
      "CVLT",
      DECIMALS,
      EPOCH_LENGTH,
      mockAsset.address,
      blackHoleAccount,
      blackHolePoint,
      RATIO_DECIMALS,
    ]);

    await mockAsset.write.forceRegister([blackHoleAccount, blackHolePoint], {
      account: accounts[0].account,
    });

    return {
      accounts,
      mockAsset,
      helper,
      vault,
      blackHoleAccount,
      blackHolePoint,
    };
  }

  it("scales deposit ciphertexts and forwards them to the asset", async function () {
    const { accounts, mockAsset, helper, vault, blackHoleAccount } =
      await loadFixture(deployVaultFixture);

    const depositor = accounts[1];
    const userPoint = await helper.read.mulBase([2n]);

    await vault.write.registerAccount([userPoint], {
      account: depositor.account,
    });
    await mockAsset.write.forceRegister(
      [depositor.account.address as `0x${string}`, userPoint],
      { account: accounts[0].account }
    );

    await vault.write.activate({ account: accounts[0].account });

    const sendPoint = await helper.read.mulBase([3n]);
    const receivePoint = await helper.read.mulBase([4n]);
    const randomnessPoint = await helper.read.identity();

    const depositValue = encodeTransferValue([
      sendPoint,
      receivePoint,
      randomnessPoint,
    ]);

    await vault.write.confidentialDeposit([depositValue, "0x"], {
      account: depositor.account,
    });

    const pendingUser = await readPointPair(
      vault,
      "pending",
      depositor.account.address as `0x${string}`
    );
    const pendingBlackHole = await readPointPair(
      vault,
      "pending",
      blackHoleAccount
    );

    const ratio = await vault.read.ratio();
    const scaledSend = await helper.read.mulPoint([sendPoint, ratio]);
    const scaledReceive = await helper.read.mulPoint([receivePoint, ratio]);
    const scaledRandomness = await helper.read.mulPoint([
      randomnessPoint,
      ratio,
    ]);

    expect(await helper.read.eqPoints([pendingUser[0], scaledSend])).to.be.true;
    expect(await helper.read.eqPoints([pendingUser[1], scaledRandomness])).to.be
      .true;
    expect(await helper.read.eqPoints([pendingBlackHole[0], scaledReceive])).to
      .be.true;
    expect(await helper.read.eqPoints([pendingBlackHole[1], scaledRandomness]))
      .to.be.true;

    const transferEvents =
      await mockAsset.getEvents.ConfidentialTransferWithSender();
    expect(transferEvents.length).to.equal(1);
    const eventArgs = transferEvents[0].args;
    if (!eventArgs || !eventArgs.sender || !eventArgs.receiver) {
      throw new Error("Event args are undefined");
    }
    expect(eventArgs.sender.toLowerCase()).to.equal(
      depositor.account.address.toLowerCase()
    );
    expect(eventArgs.receiver.toLowerCase()).to.equal(
      blackHoleAccount.toLowerCase()
    );
  });

  it("redeems shares via withdraw after shares roll over", async function () {
    const { accounts, mockAsset, helper, vault, blackHoleAccount } =
      await loadFixture(deployVaultFixture);

    const depositor = accounts[1];
    const userPoint = await helper.read.mulBase([5n]);

    await vault.write.registerAccount([userPoint], {
      account: depositor.account,
    });
    await mockAsset.write.forceRegister(
      [depositor.account.address as `0x${string}`, userPoint],
      { account: accounts[0].account }
    );

    await vault.write.activate({ account: accounts[0].account });

    const sendPoint = await helper.read.mulBase([6n]);
    const receivePoint = await helper.read.mulBase([7n]);
    const randomnessPoint = await helper.read.identity();
    const transferValue = encodeTransferValue([
      sendPoint,
      receivePoint,
      randomnessPoint,
    ]);

    await vault.write.confidentialDeposit([transferValue, "0x"], {
      account: depositor.account,
    });
    await increaseToNextEpoch();
    await vault.write.rollOver([depositor.account.address as `0x${string}`], {
      account: depositor.account,
    });
    await vault.write.rollOver([blackHoleAccount], {
      account: accounts[0].account,
    });

    const beforeWithdrawUserAcc = await readPointPair(
      vault,
      "acc",
      depositor.account.address as `0x${string}`
    );
    const beforeWithdrawBlackHoleAcc = await readPointPair(
      vault,
      "acc",
      blackHoleAccount
    );

    const ratio = await vault.read.ratio();
    const scaledReceive = await helper.read.mulPoint([receivePoint, ratio]);
    const scaledRandomness = await helper.read.mulPoint([
      randomnessPoint,
      ratio,
    ]);
    const scaledSend = await helper.read.mulPoint([sendPoint, ratio]);
    const negReceive = await helper.read.negatePoint([scaledReceive]);
    const negRandom = await helper.read.negatePoint([scaledRandomness]);
    const negSend = await helper.read.negatePoint([scaledSend]);

    await vault.write.confidentialWithdraw([transferValue, "0x"], {
      account: depositor.account,
    });

    const finalUserAcc = await readPointPair(
      vault,
      "acc",
      depositor.account.address as `0x${string}`
    );
    const finalBlackHoleAcc = await readPointPair(
      vault,
      "acc",
      blackHoleAccount
    );

    const expectedUserCL = await helper.read.addPoints([
      beforeWithdrawUserAcc[0],
      negReceive,
    ]);
    const expectedUserCR = await helper.read.addPoints([
      beforeWithdrawUserAcc[1],
      negRandom,
    ]);
    const expectedBlackHoleCL = await helper.read.addPoints([
      beforeWithdrawBlackHoleAcc[0],
      negSend,
    ]);
    const expectedBlackHoleCR = await helper.read.addPoints([
      beforeWithdrawBlackHoleAcc[1],
      negRandom,
    ]);

    expect(await helper.read.eqPoints([finalUserAcc[0], expectedUserCL])).to.be
      .true;
    expect(await helper.read.eqPoints([finalUserAcc[1], expectedUserCR])).to.be
      .true;
    expect(
      await helper.read.eqPoints([finalBlackHoleAcc[0], expectedBlackHoleCL])
    ).to.be.true;
    expect(
      await helper.read.eqPoints([finalBlackHoleAcc[1], expectedBlackHoleCR])
    ).to.be.true;

    const transferEvents =
      await mockAsset.getEvents.ConfidentialTransferWithSender();
    expect(transferEvents.length).to.be.greaterThanOrEqual(1);
    const lastEvent = transferEvents[transferEvents.length - 1];
    const lastEventArgs = lastEvent.args;
    if (!lastEventArgs || !lastEventArgs.sender || !lastEventArgs.receiver) {
      throw new Error("Event args are undefined");
    }
    expect(lastEventArgs.sender.toLowerCase()).to.equal(
      blackHoleAccount.toLowerCase()
    );
    expect(lastEventArgs.receiver.toLowerCase()).to.equal(
      depositor.account.address.toLowerCase()
    );
  });
});
