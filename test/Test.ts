import { loadFixture } from "@nomicfoundation/hardhat-toolbox-viem/network-helpers";
import { expect } from "chai";
import hre from "hardhat";
import { PublicClient, TestClient, parseEther } from "viem";
import Client from "../client/Client";
import { initializeBabyJub, generateBabyJubAccount } from "../client/ultis";

describe("Test PrivacyToken", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.

  const EPOCH_LENGTH = 20n;
  const DECIMALS = 4;
  const MAX = 4294967295n; // 2^32 - 1

  const client1PrivateKey =
    "989684980841917356420192175194090137718385886803255486827734521826538409888";

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

    // Generate test accounts with proper BabyJub keys
    const zetherAccount1 = generateBabyJubAccount(client1PrivateKey);
    const zetherAccount2 = generateBabyJubAccount();

    const publicClient = await hre.viem.getPublicClient();
    const testClient = await hre.viem.getTestClient();

    return {
      PrivacyToken,
      accounts,
      zetherAccount1,
      zetherAccount2,
      publicClient,
      testClient,
    };
  }

  describe("PrivacyToken core flows", function () {
    it("1) Register account, mint tokens and check balance after rollover", async function () {
      const {
        PrivacyToken,
        accounts,
        zetherAccount1,
        publicClient,
        testClient,
      } = await loadFixture(setupAll);

      const client1 = new Client(MAX, zetherAccount1);

      // Register account with Schnorr signature
      await client1.registerAccount(PrivacyToken, accounts[1].account);

      // Mint 1 ETH => 10^DECIMALS units
      await client1.mint(PrivacyToken, accounts[1].account, "1");

      // Move to next epoch so pending -> acc
      await increaseToNextEpoch(publicClient, testClient);

      const bal = await client1.getCurrentBalance(PrivacyToken, publicClient);
      expect(bal).to.equal(10 ** DECIMALS);
    });

    it("2) Register two accounts, mint, and confidentialTransfer", async function () {
      const {
        PrivacyToken,
        accounts,
        zetherAccount1,
        zetherAccount2,
        publicClient,
        testClient,
      } = await loadFixture(setupAll);

      const client1 = new Client(MAX, zetherAccount1);
      const client2 = new Client(MAX, zetherAccount2);

      // Register both accounts
      await client1.registerAccount(PrivacyToken, accounts[1].account);
      await client2.registerAccount(PrivacyToken, accounts[2].account);

      // Store the receiver address for client2
      client2.currentAddress = accounts[2].account.address;

      // Mint 2 ETH to sender => 2 * 10^DECIMALS
      await client1.mint(PrivacyToken, accounts[1].account, "2");
      await increaseToNextEpoch(publicClient, testClient);

      const beforeTransferBal1 = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(beforeTransferBal1).to.equal(2 * 10 ** DECIMALS);

      // Transfer 1.0000 unit equivalent => 10^DECIMALS
      await client1.confidentialTransfer(
        PrivacyToken,
        publicClient,
        accounts[1].account,
        String(1 * 10 ** DECIMALS),
        accounts[2].account.address
      );

      // Sender balance decreases immediately
      const afterTransferBal1 = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(afterTransferBal1).to.equal(1 * 10 ** DECIMALS);

      await increaseToNextEpoch(publicClient, testClient);
      const receiverBal = await client2.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(receiverBal).to.equal(1 * 10 ** DECIMALS);
    });

    it("3) Register, mint, burn tokens and check balance decreases after rollover", async function () {
      const {
        PrivacyToken,
        accounts,
        zetherAccount1,
        publicClient,
        testClient,
      } = await loadFixture(setupAll);

      const client1 = new Client(MAX, zetherAccount1);

      // Register account
      await client1.registerAccount(PrivacyToken, accounts[1].account);

      // Mint 2 ETH => 2 * 10^DECIMALS
      await client1.mint(PrivacyToken, accounts[1].account, "2");
      await increaseToNextEpoch(publicClient, testClient);

      const balBeforeBurn = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balBeforeBurn).to.equal(2 * 10 ** DECIMALS);

      // Burn 1 * 10^DECIMALS units; balance remains same this epoch
      await client1.burn(
        PrivacyToken,
        publicClient,
        accounts[1].account,
        String(10 ** DECIMALS)
      );

      const balSameEpoch = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balSameEpoch).to.equal(2 * 10 ** DECIMALS);

      // After next epoch, burn applies and balance decreases
      await increaseToNextEpoch(publicClient, testClient);
      const balAfterBurn = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(balAfterBurn).to.equal(1 * 10 ** DECIMALS);
    });

    it("4) EIP-7945 metadata methods", async function () {
      const {
        PrivacyToken,
        accounts,
        zetherAccount1,
        publicClient,
        testClient,
      } = await loadFixture(setupAll);

      const client1 = new Client(MAX, zetherAccount1);

      // Test token metadata
      const name = await PrivacyToken.read.name();
      expect(name).to.equal("PrivacyToken");

      const symbol = await PrivacyToken.read.symbol();
      expect(symbol).to.equal("PRIV");

      const decimals = await PrivacyToken.read.decimals();
      expect(decimals).to.equal(DECIMALS);

      // Register account and mint tokens
      await client1.registerAccount(PrivacyToken, accounts[1].account);
      await client1.mint(PrivacyToken, accounts[1].account, "1");
      await increaseToNextEpoch(publicClient, testClient);

      // Test confidentialBalanceOf returns encoded balance data
      const confidentialBalance = await client1.getConfidentialBalance(
        PrivacyToken,
        accounts[1].account
      );
      expect(confidentialBalance).to.not.be.empty;
      expect(confidentialBalance.length).to.be.greaterThan(0);
    });

    it("5) Registration requirements and validation", async function () {
      const {
        PrivacyToken,
        accounts,
        zetherAccount1,
        zetherAccount2,
        publicClient,
        testClient,
      } = await loadFixture(setupAll);

      const client1 = new Client(MAX, zetherAccount1);
      const client2 = new Client(MAX, zetherAccount2);

      // Attempt to mint without registration (should revert)
      await expect(
        client1.mint(PrivacyToken, accounts[1].account, "1")
      ).to.be.rejectedWith("Account not registered");

      // Register account1
      await client1.registerAccount(PrivacyToken, accounts[1].account);

      // Verify account is registered
      const isRegistered = await client1.isRegistered(
        PrivacyToken,
        accounts[1].account
      );
      expect(isRegistered).to.be.true;

      // Now mint should work
      await client1.mint(PrivacyToken, accounts[1].account, "2");
      await increaseToNextEpoch(publicClient, testClient);

      // Register account2
      await client2.registerAccount(PrivacyToken, accounts[2].account);

      // Attempt to transfer to unregistered account (should revert)
      await expect(
        client1.confidentialTransfer(
          PrivacyToken,
          publicClient,
          accounts[1].account,
          String(10 ** DECIMALS),
          accounts[3].account.address // accounts[3] is not registered
        )
      ).to.be.rejectedWith("Receiver public key not registered");

      // Transfer to registered account should work
      await client1.confidentialTransfer(
        PrivacyToken,
        publicClient,
        accounts[1].account,
        String(10 ** DECIMALS),
        accounts[2].account.address
      );

      // Verify transfer worked
      const senderBal = await client1.getCurrentBalance(
        PrivacyToken,
        publicClient
      );
      expect(senderBal).to.equal(1 * 10 ** DECIMALS);
    });
  });
});
