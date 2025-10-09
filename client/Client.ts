import { getAddress, getBytes, concat, AbiCoder } from "ethers";
import { Account, parseEther, WalletClient } from "viem";
import { GetContractReturnType } from "@nomicfoundation/hardhat-viem/types";
import { PrivacyToken$Type } from "../artifacts/contracts/PrivacyToken.sol/PrivacyToken";
import {
  BabyJubAccount,
  generateBabyJubAccount,
  convertToBabyJubPoints,
  formatPoint,
  createTransferInput,
  readBalanceWithOnchainData,
  randomBabyJubScalar,
  SolidityPointInput,
  generateBurnProof,
  flattenProof,
  generateCalldata,
  convertSolidityPointToArrayString,
  calculatePublicKeyHash,
  generateTransferProof,
  convertToBabyJubPointsArrayString,
  schnorrChallenge,
  randomScalar,
} from "./ultis";

// Use the generated contract type from artifacts
type PrivacyTokenContract = GetContractReturnType<PrivacyToken$Type["abi"]>;

type PublicClient = {
  getBlockNumber: () => Promise<bigint>;
};

function toUnitsByDecimals(
  amount: string | number | bigint,
  decimals: number
): bigint {
  if (typeof amount === "bigint") return amount;
  if (typeof amount === "number") {
    const s = amount.toString();
    return toUnitsByDecimals(s, decimals);
  }
  const [intPart, fracPartRaw = ""] = amount.split(".");
  const fracPart = (fracPartRaw + "0".repeat(decimals)).slice(0, decimals);
  const normalized = `${intPart}${fracPart}`.replace(/^0+/, "");
  return BigInt(normalized === "" ? "0" : normalized);
}

class Client {
  account: BabyJubAccount;
  MAX: bigint;
  abiCoder: AbiCoder;
  currentAddress: string | null = null;

  constructor(MAX: bigint, account?: BabyJubAccount) {
    try {
      // Noop: placeholder for optional event listeners (kept for compatibility)
    } catch (error: any) {
      console.log(
        "Event listener setup skipped for Ethers.js compatibility:",
        error?.message
      );
    }

    this.account = account ?? generateBabyJubAccount();
    this.MAX = MAX;
    this.abiCoder = new AbiCoder();
  }

  get privateKey(): bigint {
    return this.account.privateKey;
  }

  get publicKey(): SolidityPointInput {
    return this.account.publicKey;
  }

  /**
   * Register account with PrivacyToken contract using Schnorr signature
   * @param PrivacyToken The contract instance
   * @param account The wallet account to use for the transaction
   */
  async registerAccount(PrivacyToken: PrivacyTokenContract, account: Account) {
    const contractAddress = getAddress(PrivacyToken.address);
    const senderAddress = getAddress(account.address);
    const { c, s } = schnorrChallenge(
      contractAddress,
      senderAddress,
      this.publicKey,
      this.privateKey
    );

    // Store the address for later use
    this.currentAddress = senderAddress;

    return PrivacyToken.write.registerAccount([this.publicKey, c, s], {
      account,
    });
  }

  /**
   * Mint tokens by sending ETH to the contract
   * @param PrivacyToken The contract instance
   * @param account The wallet account to use for the transaction
   * @param amount The amount of ETH to send (in ETH units, e.g., "1.0")
   */
  async mint(
    PrivacyToken: PrivacyTokenContract,
    account: Account,
    amount: string
  ) {
    const valueWei = parseEther(String(amount));
    return PrivacyToken.write.mint({
      value: valueWei,
      account,
    });
  }

  /**
   * Burn tokens and receive ETH back
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   * @param account The wallet account to use for the transaction
   * @param amount The amount of tokens to burn (in token units)
   */
  async burn(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient,
    account: Account,
    amount: string
  ) {
    const accountData = await this.stimulateAccount(PrivacyToken, publicClient);
    const cur_b = readBalanceWithOnchainData(accountData, this.privateKey);
    const counter = await PrivacyToken.read.counter([
      account.address as `0x${string}`,
    ]);

    if (!cur_b) {
      throw new Error("Current balance is undefined");
    }

    const proof = await generateBurnProof({
      y: convertSolidityPointToArrayString(this.publicKey), // public
      sk: this.privateKey.toString(),
      CL: convertSolidityPointToArrayString(accountData[0]), // public
      CR: convertSolidityPointToArrayString(accountData[1]), // public
      b: amount, // public
      cur_b: cur_b.toString(),
      counter: counter.toString(), // public
    });
    const calldata = await generateCalldata(proof.proof, proof.publicSignals);

    const proofFlat = flattenProof(calldata.pA, calldata.pB, calldata.pC);

    // Encode proof as bytes for PrivacyToken
    const proofEncoded = this.abiCoder.encode(["uint256[8]"], [proofFlat]);

    const res = await PrivacyToken.write.burn([BigInt(amount), proofEncoded], {
      account,
    });
    return { res, calldata };
  }

  /**
   * Perform confidential transfer using EIP-7945 interface
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   * @param account The wallet account to use for the transaction
   * @param amount The amount of tokens to transfer (in token units)
   * @param receiverAddress The address of the receiver
   */
  async confidentialTransfer(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient,
    account: Account,
    amount: string,
    receiverAddress: string
  ) {
    const accountData = await this.stimulateAccount(PrivacyToken, publicClient);
    const cur_b = readBalanceWithOnchainData(accountData, this.privateKey);
    const counter = await PrivacyToken.read.counter([
      account.address as `0x${string}`,
    ]);
    const MAX = await PrivacyToken.read.MAX();

    if (!cur_b) {
      throw new Error("Current balance is undefined");
    }

    // Get receiver's public key from the contract
    const receiverPublicKey = await PrivacyToken.read.addressToPublicKey([
      receiverAddress as `0x${string}`,
    ]);

    if (
      !receiverPublicKey ||
      !Array.isArray(receiverPublicKey) ||
      receiverPublicKey.length !== 2
    ) {
      throw new Error("Receiver public key not registered");
    }

    const [x, y] = receiverPublicKey;

    // Check if the public key is the zero point (0, 0)
    if (x === 0n && y === 0n) {
      throw new Error("Receiver public key not registered");
    }

    const r = randomBabyJubScalar(true);

    const [C_send, C_receive, D] = createTransferInput(
      convertToBabyJubPoints(this.publicKey),
      convertToBabyJubPoints({ x, y }),
      BigInt(amount),
      r
    );

    const remainAmount = cur_b - Number(amount);

    const proof = await generateTransferProof({
      // private
      sk: this.privateKey.toString(),
      r: r.toString(),
      sAmount: amount.toString(),
      bRem: remainAmount.toString(),
      // public
      MAX: MAX.toString(),
      CS: convertToBabyJubPointsArrayString(C_send),
      D: convertToBabyJubPointsArrayString(D),
      CRe: convertToBabyJubPointsArrayString(C_receive),
      y: convertSolidityPointToArrayString(this.publicKey), // public
      yR: convertSolidityPointToArrayString({ x, y }), // public
      CL: convertSolidityPointToArrayString(accountData[0]), // public
      CR: convertSolidityPointToArrayString(accountData[1]), // public
      counter: counter.toString(), // public
    });
    const calldata = await generateCalldata(proof.proof, proof.publicSignals);
    const proofFlat = flattenProof(calldata.pA, calldata.pB, calldata.pC);

    // Format points for encoding
    const C_send_formatted = formatPoint(C_send);
    const C_receive_formatted = formatPoint(C_receive);
    const D_formatted = formatPoint(D);

    // Encode confidential transfer value as bytes
    const transferValue = this.abiCoder.encode(
      [
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
      ],
      [
        [C_send_formatted.x, C_send_formatted.y],
        [C_receive_formatted.x, C_receive_formatted.y],
        [D_formatted.x, D_formatted.y],
      ]
    );

    // Encode proof as bytes
    const proofEncoded = this.abiCoder.encode(["uint256[8]"], [proofFlat]);

    return PrivacyToken.write.confidentialTransfer(
      [receiverAddress as `0x${string}`, transferValue, proofEncoded],
      {
        account,
      }
    );
  }

  /**
   * Simulate account state for current epoch
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   */
  async stimulateAccount(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient
  ) {
    if (!this.currentAddress) {
      throw new Error("Account not registered. Call registerAccount first.");
    }

    const [epochLength, blockNumber] = await Promise.all([
      PrivacyToken.read.epochLength(),
      publicClient.getBlockNumber(),
    ]);
    const epoch = blockNumber / epochLength;

    const accounts = await PrivacyToken.read.simulateAccounts([
      [this.currentAddress as `0x${string}`],
      epoch,
    ]);
    const accountData = accounts[0];
    return accountData;
  }

  /**
   * Roll over account to next epoch
   * @param PrivacyToken The contract instance
   * @param account The wallet account to use for the transaction
   */
  async rollOver(PrivacyToken: PrivacyTokenContract, account: Account) {
    return PrivacyToken.write.rollOver([account.address as `0x${string}`], {
      account,
    });
  }

  /**
   * Get current balance for current epoch
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   */
  async getCurrentBalance(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient
  ): Promise<number | undefined> {
    const accountData = await this.stimulateAccount(PrivacyToken, publicClient);
    return readBalanceWithOnchainData(accountData, this.privateKey);
  }

  /**
   * Get confidential balance using EIP-7945 interface
   * @param PrivacyToken The contract instance
   * @param account The wallet account to query
   */
  async getConfidentialBalance(
    PrivacyToken: PrivacyTokenContract,
    account: Account
  ) {
    return PrivacyToken.read.confidentialBalanceOf([
      account.address as `0x${string}`,
    ]);
  }

  /**
   * Check if account is registered
   * @param PrivacyToken The contract instance
   * @param account The wallet account to check
   */
  async isRegistered(PrivacyToken: PrivacyTokenContract, account: Account) {
    return PrivacyToken.read.registered([account.address as `0x${string}`]);
  }
}

export default Client;
