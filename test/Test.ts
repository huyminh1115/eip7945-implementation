import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { PublicClient, TestClient, parseEther } from "viem";
import Client from "../client/Client";
import {
  initializeBabyJub,
  generateBabyJubAccount,
  readBalanceWithOnchainData,
} from "../client/ultis";

describe("Test PrivacyToken", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  const EPOCH_LENGTH = 20n;
  const DECIMALS = 4;
  const MAX = 4294967295n; // 2^32 - 1

  async function increaseToNextEpoch(
    publicClient: PublicClient,
    testClient: TestClient
  ) {
    const blockNumber = await publicClient.getBlockNumber();
    const blockUntilNextEpoch = EPOCH_LENGTH - (blockNumber % EPOCH_LENGTH);

    await testClient.mine({ blocks: Number(blockUntilNextEpoch) });
  }

  before(async function () {
    await initializeBabyJub();
  });

  async function setupAll() {
    // Contracts are deployed using the first signer/account by default
    const accounts = await hre.viem.getWalletClients();

    // Deploy PrivacyToken contract with name and symbol
    const PrivacyToken = await hre.viem.deployContract("PrivacyToken", [
      "PrivacyToken", // name
      "PRIV", // symbol
      DECIMALS, // decimals
      EPOCH_LENGTH, // epochLength
    ]);

    const publicClient = await hre.viem.getPublicClient();
    const testClient = await hre.viem.getTestClient();

    return {
      PrivacyToken,
      accounts,
      publicClient,
      testClient,
    };
  }

  describe("PrivacyToken core flows", function () {
    it("1) Register account, mint tokens and check balance after rollover", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 1 ETH
      const mintAmount = "1";
      const expectedBalance = Number(mintAmount) * 10 ** DECIMALS;

      const alice = new Client(accounts[1].account, MAX);

      // Register account with Schnorr signature
      await alice.registerAccount(PrivacyToken);

      // Mint 1 ETH => 10^DECIMALS units
      await alice.mint(PrivacyToken, mintAmount);

      // Move to next epoch so pending -> acc
      await increaseToNextEpoch(publicClient, testClient);

      const bal = await alice.getCurrentBalance(PrivacyToken, publicClient);
      expect(bal).to.equal(expectedBalance);
    });

    it("2) Register two accounts, mint, and confidentialTransfer", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 2 ETH mint, transfer 1 token
      const mintAmount = "2";
      const transferAmount = 10 ** DECIMALS;
      const expectedInitialBalance = Number(mintAmount) * 10 ** DECIMALS;
      const expectedFinalBalance = expectedInitialBalance - transferAmount;

      const alice = new Client(accounts[1].account, MAX);
      const bob = new Client(accounts[2].account, MAX);

      // Register both accounts
      await alice.registerAccount(PrivacyToken);
      await bob.registerAccount(PrivacyToken);

      // Mint 2 ETH to sender => 2 * 10^DECIMALS
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      const beforeTransferBal = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(beforeTransferBal).to.equal(expectedInitialBalance);

      // Transfer 1.0000 unit equivalent => 10^DECIMALS
      await alice.confidentialTransfer(
        PrivacyToken,
        publicClient,
        String(transferAmount),
        accounts[2].account.address
      );

      // Sender balance decreases immediately
      const afterTransferBal = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(afterTransferBal).to.equal(expectedFinalBalance);

      await increaseToNextEpoch(publicClient, testClient);
      const receiverBal = await bob.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(receiverBal).to.equal(expectedFinalBalance);
    });

    it("3) Register, mint, burn tokens and check balance decreases after rollover", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 2 ETH mint, burn 1 token
      const mintAmount = "2";
      const burnAmount = 10 ** DECIMALS;
      const expectedInitialBalance = Number(mintAmount) * 10 ** DECIMALS;
      const expectedFinalBalance = expectedInitialBalance - burnAmount;

      const alice = new Client(accounts[1].account, MAX);

      // Register account
      await alice.registerAccount(PrivacyToken);

      // Mint 2 ETH => 2 * 10^DECIMALS
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      const balBeforeBurn = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balBeforeBurn).to.equal(expectedInitialBalance);

      // Burn 1 * 10^DECIMALS units; balance remains same this epoch
      await alice.burn(PrivacyToken, publicClient, String(burnAmount));

      const balSameEpoch = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balSameEpoch).to.equal(expectedInitialBalance);

      // After next epoch, burn applies and balance decreases
      await increaseToNextEpoch(publicClient, testClient);
      const balAfterBurn = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balAfterBurn).to.equal(expectedFinalBalance);
    });

    it("4) EIP-7945 metadata methods", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 1 ETH mint
      const mintAmount = "1";

      const alice = new Client(accounts[1].account, MAX);

      // Test token metadata
      const name = await PrivacyToken.read.name();
      expect(name).to.equal("PrivacyToken");

      const symbol = await PrivacyToken.read.symbol();
      expect(symbol).to.equal("PRIV");

      const decimals = await PrivacyToken.read.decimals();
      expect(decimals).to.equal(DECIMALS);

      // Register account and mint tokens
      await alice.registerAccount(PrivacyToken);
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      // Test confidentialBalanceOf returns encoded balance data
      const confidentialBalance = await alice.getConfidentialBalance(
        PrivacyToken
      );
      expect(confidentialBalance).to.not.be.empty;
      expect(confidentialBalance.length).to.be.greaterThan(0);
    });

    it("5) Registration requirements and validation", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 1 ETH for failed mint, 2 ETH for successful mint, 1 token transfer
      const failedMintAmount = "1";
      const successfulMintAmount = "2";
      const transferAmount = 10 ** DECIMALS;
      const expectedFinalBalance =
        Number(successfulMintAmount) * 10 ** DECIMALS - transferAmount;

      const alice = new Client(accounts[1].account, MAX);
      const bob = new Client(accounts[2].account, MAX);

      // Attempt to mint without registration (should revert)
      await expect(
        alice.mint(PrivacyToken, failedMintAmount)
      ).to.be.rejectedWith("Account not registered");

      // Register account1
      await alice.registerAccount(PrivacyToken);

      // Verify account is registered
      const isRegistered = await alice.isRegistered(PrivacyToken);
      expect(isRegistered).to.be.true;

      // Now mint should work
      await alice.mint(PrivacyToken, successfulMintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      // Register account2
      await bob.registerAccount(PrivacyToken);

      // Attempt to transfer to unregistered account (should revert)
      await expect(
        alice.confidentialTransfer(
          PrivacyToken,
          publicClient,
          String(transferAmount),
          accounts[3].account.address // accounts[3] is not registered
        )
      ).to.be.rejectedWith("Receiver public key not registered");

      // Transfer to registered account should work
      await alice.confidentialTransfer(
        PrivacyToken,
        publicClient,
        String(transferAmount),
        accounts[2].account.address
      );

      // Verify transfer worked
      const senderBal = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(senderBal).to.equal(expectedFinalBalance);
    });

    it("6) Approve allowance from A to B and verify A balance and allowance", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 2 ETH mint, 1 token approve
      const mintAmount = "2";
      const approveAmount = 10 ** DECIMALS;
      const expectedInitialBalance = Number(mintAmount) * 10 ** DECIMALS;
      const expectedFinalBalance = expectedInitialBalance - approveAmount;

      const alice = new Client(accounts[1].account, MAX);
      const bob = new Client(accounts[2].account, MAX);

      // Register both accounts
      await alice.registerAccount(PrivacyToken);
      await bob.registerAccount(PrivacyToken);

      // Mint 2 ETH to A and rollover
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      const beforeApproveBal = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(beforeApproveBal).to.equal(expectedInitialBalance);

      // Approve 1 * 10^DECIMALS from A to B
      const approveUnits = String(approveAmount);
      await alice.confidentialApprove(
        PrivacyToken,
        publicClient,
        approveUnits,
        accounts[2].account.address
      );

      // A's balance should decrease immediately by approved amount
      const afterApproveBal = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(afterApproveBal).to.equal(expectedFinalBalance);

      // Allowance bytes should be non-empty
      const allowanceBytes = await PrivacyToken.read.confidentialAllowance([
        accounts[1].account.address as `0x${string}`,
        accounts[2].account.address as `0x${string}`,
      ]);
      expect(allowanceBytes).to.not.be.empty;
      // Should not be just 0x
      expect(allowanceBytes).to.not.equal("0x");

      // Decode and verify allowance equals approved amount for both owner and spender parts
      const { owner, spender } = await alice.readSpenderAllowance(
        PrivacyToken,
        accounts[2].account.address
      );

      const ownerBalance = await alice.readBalanceWithInput(owner.CL, owner.CR);
      expect(ownerBalance).to.equal(expectedFinalBalance);

      const spenderBalance = await bob.readBalanceWithInput(
        spender.CL,
        spender.CR
      );
      expect(spenderBalance).to.equal(expectedFinalBalance);
    });

    it("7) Approve then transferFrom: B moves tokens from A to C", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 2 ETH mint, 1 token approve and transfer
      const mintAmount = "2";
      const approveAmount = 10 ** DECIMALS;
      const expectedInitialBalance = Number(mintAmount) * 10 ** DECIMALS;
      const expectedAfterApproveBalance =
        expectedInitialBalance - approveAmount;
      const expectedAfterTransferBalance = approveAmount;
      const expectedFinalAllowance = 0;

      const alice = new Client(accounts[1].account, MAX);
      const bob = new Client(accounts[2].account, MAX);
      const charlie = new Client(accounts[3].account, MAX);

      // Register accounts A, B, C
      await alice.registerAccount(PrivacyToken);
      await bob.registerAccount(PrivacyToken);
      await charlie.registerAccount(PrivacyToken);

      // Fund A with 2 ETH and rollover
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      // Approve 1 unit from A to B
      const approveUnits = String(approveAmount);
      await alice.confidentialApprove(
        PrivacyToken,
        publicClient,
        approveUnits,
        accounts[2].account.address
      );

      // Verify allowance equals approveUnits
      const { owner: ownerBefore, spender: spenderBefore } =
        await alice.readSpenderAllowance(
          PrivacyToken,
          accounts[2].account.address
        );
      const ownerBeforeAmt = await alice.readBalanceWithInput(
        ownerBefore.CL,
        ownerBefore.CR
      );
      const spenderBeforeAmt = await bob.readBalanceWithInput(
        spenderBefore.CL,
        spenderBefore.CR
      );
      expect(ownerBeforeAmt).to.equal(expectedAfterApproveBalance);
      expect(spenderBeforeAmt).to.equal(expectedAfterApproveBalance);

      // B transferFrom A to C for 1 unit
      await bob.confidentialTransferFrom(
        PrivacyToken,
        accounts[1].account.address, // from A
        accounts[3].account.address, // to C
        approveUnits
      );

      // Allowance should be decreased to 0 immediately
      const { owner: ownerAfter, spender: spenderAfter } =
        await alice.readSpenderAllowance(
          PrivacyToken,
          accounts[2].account.address
        );
      const ownerAfterAmt = await alice.readBalanceWithInput(
        ownerAfter.CL,
        ownerAfter.CR
      );
      const spenderAfterAmt = await bob.readBalanceWithInput(
        spenderAfter.CL,
        spenderAfter.CR
      );
      expect(ownerAfterAmt).to.equal(expectedFinalAllowance);
      expect(spenderAfterAmt).to.equal(expectedFinalAllowance);

      // After next epoch, C receives amount
      await increaseToNextEpoch(publicClient, testClient);
      const balanceC = await charlie.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balanceC).to.equal(expectedAfterTransferBalance);
    });

    it("8) Approve, partial transferFrom, revokeAllowance, and check balances", async function () {
      const { PrivacyToken, accounts, publicClient, testClient } =
        await loadFixture(setupAll);

      // Test input: 3 ETH mint, 2 token approve, 1 token transfer, then revoke
      const mintAmount = "3";
      const approveAmount = 2 * 10 ** DECIMALS; // 2 tokens
      const transferAmount = 10 ** DECIMALS; // 1 token
      const expectedInitialBalance = Number(mintAmount) * 10 ** DECIMALS;
      const expectedAfterApproveBalance =
        expectedInitialBalance - approveAmount;
      const expectedAfterRevokeBalance =
        expectedAfterApproveBalance + (approveAmount - transferAmount); // Owner gets back remaining allowance

      const alice = new Client(accounts[1].account, MAX);
      const bob = new Client(accounts[2].account, MAX);
      const charlie = new Client(accounts[3].account, MAX);

      // Register accounts A, B, C
      await alice.registerAccount(PrivacyToken);
      await bob.registerAccount(PrivacyToken);
      await charlie.registerAccount(PrivacyToken);

      // Fund A with 3 ETH and rollover
      await alice.mint(PrivacyToken, mintAmount);
      await increaseToNextEpoch(publicClient, testClient);

      // Check initial balance
      const initialBalance = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(initialBalance).to.equal(expectedInitialBalance);

      // Approve 2 units from A to B
      const approveUnits = String(approveAmount);
      await alice.confidentialApprove(
        PrivacyToken,
        publicClient,
        approveUnits,
        accounts[2].account.address
      );

      // Verify A's balance decreased by approved amount
      const afterApproveBalance = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(afterApproveBalance).to.equal(expectedAfterApproveBalance);

      // Verify allowance exists and equals approved amount
      const { owner: ownerBefore, spender: spenderBefore } =
        await alice.readSpenderAllowance(
          PrivacyToken,
          accounts[2].account.address
        );
      const ownerBeforeAmt = await alice.readBalanceWithInput(
        ownerBefore.CL,
        ownerBefore.CR
      );
      const spenderBeforeAmt = await bob.readBalanceWithInput(
        spenderBefore.CL,
        spenderBefore.CR
      );
      // The allowance should equal the full approved amount
      expect(ownerBeforeAmt).to.equal(approveAmount);
      expect(spenderBeforeAmt).to.equal(approveAmount);

      // B transferFrom A to C for 1 unit (partial use of allowance)
      const transferUnits = String(transferAmount);
      await bob.confidentialTransferFrom(
        PrivacyToken,
        accounts[1].account.address, // from A
        accounts[3].account.address, // to C
        transferUnits
      );

      // Verify allowance decreased by transferred amount
      const { owner: ownerAfter, spender: spenderAfter } =
        await alice.readSpenderAllowance(
          PrivacyToken,
          accounts[2].account.address
        );
      const ownerAfterAmt = await alice.readBalanceWithInput(
        ownerAfter.CL,
        ownerAfter.CR
      );
      const spenderAfterAmt = await bob.readBalanceWithInput(
        spenderAfter.CL,
        spenderAfter.CR
      );
      // After transferFrom, the remaining allowance should be approveAmount - transferAmount
      const expectedRemainingAllowance = approveAmount - transferAmount;
      expect(ownerAfterAmt).to.equal(expectedRemainingAllowance);
      expect(spenderAfterAmt).to.equal(expectedRemainingAllowance);

      // A revokes remaining allowance
      await alice.revokeAllowance(PrivacyToken, accounts[2].account.address);

      // Verify A's balance increased by remaining allowance amount
      const afterRevokeBalance = await alice.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(afterRevokeBalance).to.equal(expectedAfterRevokeBalance);

      // Verify allowance is now zero/empty
      const allowanceBytes = await PrivacyToken.read.confidentialAllowance([
        accounts[1].account.address as `0x${string}`,
        accounts[2].account.address as `0x${string}`,
      ]);
      // After revoke, allowance should be empty or contain only zeros
      expect(allowanceBytes).to.not.be.undefined;
      // Check if it's empty or contains only zeros
      if (allowanceBytes !== "0x") {
        // If not empty, it should contain encoded zeros
        const { AbiCoder } = await import("ethers");
        const abiCoder = new AbiCoder();
        const decoded = abiCoder.decode(
          [
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "uint256",
            "uint256",
          ],
          allowanceBytes as `0x${string}`
        ) as bigint[];
        // All values should be 0
        expect(decoded.every((val) => val === 0n)).to.be.true;
      }

      // After next epoch, C should have received the transferred amount
      await increaseToNextEpoch(publicClient, testClient);
      const balanceC = await charlie.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balanceC).to.equal(transferAmount);
    });
  });
});
