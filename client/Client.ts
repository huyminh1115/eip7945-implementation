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
  createTransferFromInput,
  readBalanceWithOnchainData,
  randomBabyJubScalar,
  SolidityPointInput,
  generateBurnProof,
  flattenProof,
  generateCalldata,
  convertSolidityPointToArrayString,
  calculatePublicKeyHash,
  generateTransferProof,
  generateTransferFromProof,
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
  private walletAccount: Account;
  private babyJubAccount: BabyJubAccount;
  private MAX: bigint;
  private abiCoder: AbiCoder;

  constructor(account: Account, MAX?: bigint, babyJubAccount?: BabyJubAccount) {
    try {
      // Noop: placeholder for optional event listeners (kept for compatibility)
    } catch (error: any) {
      console.log(
        "Event listener setup skipped for Ethers.js compatibility:",
        error?.message
      );
    }

    this.walletAccount = account;
    this.babyJubAccount = babyJubAccount ?? generateBabyJubAccount();
    this.MAX = MAX ?? BigInt(4294967295); // Default MAX value
    this.abiCoder = new AbiCoder();
  }

  get privateKey(): bigint {
    return this.babyJubAccount.privateKey;
  }

  get publicKey(): SolidityPointInput {
    return this.babyJubAccount.publicKey;
  }

  /**
   * Register account with PrivacyToken contract using Schnorr signature
   * @param PrivacyToken The contract instance
   */
  async registerAccount(PrivacyToken: PrivacyTokenContract) {
    return PrivacyToken.write.registerAccount([this.publicKey], {
      account: this.walletAccount,
    });
  }

  /**
   * Mint tokens by sending ETH to the contract
   * @param PrivacyToken The contract instance
   * @param amount The amount of ETH to send (in ETH units, e.g., "1.0")
   */
  async mint(PrivacyToken: PrivacyTokenContract, amount: string) {
    const valueWei = parseEther(String(amount));
    return PrivacyToken.write.mint({
      value: valueWei,
      account: this.walletAccount,
    });
  }

  /**
   * Burn tokens and receive ETH back
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   * @param amount The amount of tokens to burn (in token units)
   */
  async burn(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient,
    amount: string
  ) {
    const accountData = await this.simulateAccount(PrivacyToken, publicClient);
    const cur_b = readBalanceWithOnchainData(accountData, this.privateKey);
    const counter = await PrivacyToken.read.counter([
      this.walletAccount.address as `0x${string}`,
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

    const res = await PrivacyToken.write.burn(
      [BigInt(amount), proofEncoded as `0x${string}`],
      {
        account: this.walletAccount,
      }
    );
    return { res, calldata };
  }

  /**
   * Perform confidential transfer using EIP-7945 interface
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   * @param amount The amount of tokens to transfer (in token units)
   * @param receiverAddress The address of the receiver
   */
  async confidentialTransfer(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient,
    amount: string,
    receiverAddress: string
  ) {
    const accountData = await this.simulateAccount(PrivacyToken, publicClient);
    const cur_b = readBalanceWithOnchainData(accountData, this.privateKey);
    const counter = await PrivacyToken.read.counter([
      this.walletAccount.address as `0x${string}`,
    ]);
    const MAX = await PrivacyToken.read.MAX();

    if (!cur_b) {
      throw new Error("Current balance is undefined");
    }

    // Get receiver's public key from the contract
    const receiverPublicKey = await PrivacyToken.read.addressToPublicKey([
      getAddress(receiverAddress) as `0x${string}`,
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
      [
        receiverAddress as `0x${string}`,
        transferValue as `0x${string}`,
        proofEncoded as `0x${string}`,
      ],
      {
        account: this.walletAccount,
      }
    );
  }

  /**
   * Approve confidential allowance from caller (owner) to spender address
   * Decreases owner's confidential balance immediately and adds allowance.
   */
  async confidentialApprove(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient,
    amount: string,
    spenderAddress: string
  ) {
    const accountData = await this.simulateAccount(PrivacyToken, publicClient);
    const cur_b = readBalanceWithOnchainData(accountData, this.privateKey);
    const counter = await PrivacyToken.read.counter([
      this.walletAccount.address as `0x${string}`,
    ]);
    const MAX = await PrivacyToken.read.MAX();

    if (!cur_b) {
      throw new Error("Current balance is undefined");
    }

    // Get spender's public key from the contract
    const spenderPublicKey = await PrivacyToken.read.addressToPublicKey([
      getAddress(spenderAddress) as `0x${string}`,
    ]);

    if (
      !spenderPublicKey ||
      !Array.isArray(spenderPublicKey) ||
      spenderPublicKey.length !== 2
    ) {
      throw new Error("Spender public key not registered");
    }

    const [x, y] = spenderPublicKey;
    if (x === 0n && y === 0n) {
      throw new Error("Spender public key not registered");
    }

    const r = randomBabyJubScalar(true);

    const [C_owner, C_spender, D] = createTransferInput(
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
      CS: convertToBabyJubPointsArrayString(C_owner),
      D: convertToBabyJubPointsArrayString(D),
      CRe: convertToBabyJubPointsArrayString(C_spender),
      y: convertSolidityPointToArrayString(this.publicKey), // owner
      yR: convertSolidityPointToArrayString({ x, y }), // spender
      CL: convertSolidityPointToArrayString(accountData[0]), // owner CL
      CR: convertSolidityPointToArrayString(accountData[1]), // owner CR
      counter: counter.toString(), // public
    });
    const calldata = await generateCalldata(proof.proof, proof.publicSignals);
    const proofFlat = flattenProof(calldata.pA, calldata.pB, calldata.pC);

    // Format points for encoding
    const C_owner_formatted = formatPoint(C_owner);
    const C_spender_formatted = formatPoint(C_spender);
    const D_formatted = formatPoint(D);

    // Encode approve value as bytes (same layout as transfer)
    const approveValue = this.abiCoder.encode(
      [
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
      ],
      [
        [C_owner_formatted.x, C_owner_formatted.y],
        [C_spender_formatted.x, C_spender_formatted.y],
        [D_formatted.x, D_formatted.y],
      ]
    );

    // Encode proof as bytes
    const proofEncoded = this.abiCoder.encode(["uint256[8]"], [proofFlat]);

    return PrivacyToken.write.confidentialApprove(
      [
        spenderAddress as `0x${string}`,
        approveValue as `0x${string}`,
        proofEncoded as `0x${string}`,
      ],
      { account: this.walletAccount }
    );
  }

  /**
   * Spender transfers tokens from "fromAddress" to "toAddress" using allowance
   */
  async confidentialTransferFrom(
    PrivacyToken: PrivacyTokenContract,
    fromAddress: string,
    toAddress: string,
    amount: string
  ) {
    // Fetch pubkeys
    const [fromPk, spenderPk, toPk] = await Promise.all([
      PrivacyToken.read.addressToPublicKey([
        getAddress(fromAddress) as `0x${string}`,
      ]),
      PrivacyToken.read.addressToPublicKey([
        this.walletAccount.address as `0x${string}`,
      ]),
      PrivacyToken.read.addressToPublicKey([
        getAddress(toAddress) as `0x${string}`,
      ]),
    ]);

    if (
      !Array.isArray(fromPk) ||
      !Array.isArray(spenderPk) ||
      !Array.isArray(toPk)
    ) {
      throw new Error("Missing public keys for transferFrom participants");
    }

    const r = randomBabyJubScalar(true);

    // Build commitments
    const [C_from, C_spender, C_to, D] = createTransferFromInput(
      convertToBabyJubPoints({ x: fromPk[0], y: fromPk[1] }),
      convertToBabyJubPoints({ x: spenderPk[0], y: spenderPk[1] }),
      convertToBabyJubPoints({ x: toPk[0], y: toPk[1] }),
      BigInt(amount),
      r
    );

    // get current allowance
    const allowance = await this.readOwnerAllowance(PrivacyToken, fromAddress);
    const accountData = allowance.spender; // this client is the spender
    const cur_allowance = readBalanceWithOnchainData(
      [accountData.CL, accountData.CR],
      this.privateKey
    );

    if (!cur_allowance) {
      throw new Error("Current allowance is undefined");
    }

    // Spender counter for proof
    const counterSpender = await PrivacyToken.read.counter([
      this.walletAccount.address as `0x${string}`,
    ]);
    const MAX = this.MAX;

    // Proof
    const proof = await generateTransferFromProof({
      sk: this.privateKey.toString(),
      bRem: (cur_allowance - Number(amount)).toString(),
      sAmount: amount.toString(),
      r: r.toString(),
      y: convertSolidityPointToArrayString({
        x: spenderPk[0],
        y: spenderPk[1],
      }), // spender
      yR: convertSolidityPointToArrayString({
        // receiver/to
        x: toPk[0],
        y: toPk[1],
      }),
      yF: convertSolidityPointToArrayString({ x: fromPk[0], y: fromPk[1] }), // from
      CL: convertSolidityPointToArrayString(accountData.CL), // current allowance of spender
      CR: convertSolidityPointToArrayString(accountData.CR), // current allowance of spender
      CS: convertToBabyJubPointsArrayString(C_spender), // C_spender
      CRe: convertToBabyJubPointsArrayString(C_to), // C_receive / to
      CFr: convertToBabyJubPointsArrayString(C_from), // C_from
      D: convertToBabyJubPointsArrayString(D),
      counter: counterSpender.toString(),
      MAX: MAX.toString(),
    });
    const calldata = await generateCalldata(proof.proof, proof.publicSignals);

    const proofFlat = flattenProof(calldata.pA, calldata.pB, calldata.pC);

    // Encode 4 tuples: (C_from, C_spender, C_to, D)
    const C_from_f = formatPoint(C_from);
    const C_spender_f = formatPoint(C_spender);
    const C_to_f = formatPoint(C_to);
    const D_f = formatPoint(D);

    const encodedValue = this.abiCoder.encode(
      [
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
        "tuple(uint256,uint256)",
      ],
      [
        [C_from_f.x, C_from_f.y],
        [C_spender_f.x, C_spender_f.y],
        [C_to_f.x, C_to_f.y],
        [D_f.x, D_f.y],
      ]
    );
    const proofEncoded = this.abiCoder.encode(["uint256[8]"], [proofFlat]);

    return PrivacyToken.write.confidentialTransferFrom(
      [
        getAddress(fromAddress) as `0x${string}`,
        getAddress(toAddress) as `0x${string}`,
        encodedValue as `0x${string}`,
        proofEncoded as `0x${string}`,
      ],
      { account: this.walletAccount }
    );
  }
  /**
   * Simulate account state for current epoch
   * @param PrivacyToken The contract instance
   * @param publicClient The public client for reading blockchain data
   */
  async simulateAccount(
    PrivacyToken: PrivacyTokenContract,
    publicClient: PublicClient
  ) {
    const [epochLength, blockNumber] = await Promise.all([
      PrivacyToken.read.epochLength(),
      publicClient.getBlockNumber(),
    ]);
    const epoch = blockNumber / epochLength;

    const accounts = await PrivacyToken.read.simulateAccounts([
      [this.walletAccount.address as `0x${string}`],
      epoch,
    ]);
    const accountData = accounts[0];
    return accountData;
  }

  /**
   * Roll over account to next epoch
   * @param PrivacyToken The contract instance
   */
  async rollOver(PrivacyToken: PrivacyTokenContract) {
    return PrivacyToken.write.rollOver(
      [getAddress(this.walletAccount.address) as `0x${string}`],
      {
        account: this.walletAccount,
      }
    );
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
    const accountData = await this.simulateAccount(PrivacyToken, publicClient);
    return readBalanceWithOnchainData(accountData, this.privateKey);
  }

  async getCurrentAllowedAmount(
    PrivacyToken: PrivacyTokenContract
  ): Promise<number | undefined> {
    const accountData = await PrivacyToken.read.readAllowedAmount([
      this.walletAccount.address as `0x${string}`,
    ]);

    return readBalanceWithOnchainData(accountData, this.privateKey);
  }

  /**
   * Get confidential balance using EIP-7945 interface
   * @param PrivacyToken The contract instance
   */
  async getConfidentialBalance(PrivacyToken: PrivacyTokenContract) {
    return PrivacyToken.read.confidentialBalanceOf([
      this.walletAccount.address as `0x${string}`,
    ]);
  }

  /**
   * Check if account is registered
   * @param PrivacyToken The contract instance
   */
  async isRegistered(PrivacyToken: PrivacyTokenContract) {
    return PrivacyToken.read.registered([
      this.walletAccount.address as `0x${string}`,
    ]);
  }

  /**
   * Read and decode confidential allowance between owner and spender.
   * Returns decoded amounts for owner and spender parts (if this client can decrypt).
   */
  async readSpenderAllowance(
    PrivacyToken: PrivacyTokenContract,
    spenderAddress: string
  ): Promise<{
    owner: { CL: SolidityPointInput; CR: SolidityPointInput };
    spender: { CL: SolidityPointInput; CR: SolidityPointInput };
  }> {
    const bytes = await PrivacyToken.read.confidentialAllowance([
      this.walletAccount.address as `0x${string}`,
      getAddress(spenderAddress) as `0x${string}`,
    ]);

    if (!bytes || bytes === "0x") {
      throw new Error("Allowance not found");
    }

    // Decode 8 uint256 values: CL_owner.x, CL_owner.y, CR_owner.x, CR_owner.y,
    //                          CL_spender.x, CL_spender.y, CR_spender.x, CR_spender.y
    const decoded = this.abiCoder.decode(
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
      bytes as `0x${string}`
    ) as bigint[];

    const CL_owner = { x: BigInt(decoded[0]), y: BigInt(decoded[1]) };
    const CR_owner = { x: BigInt(decoded[2]), y: BigInt(decoded[3]) };
    const CL_spender = { x: BigInt(decoded[4]), y: BigInt(decoded[5]) };
    const CR_spender = { x: BigInt(decoded[6]), y: BigInt(decoded[7]) };

    return {
      owner: { CL: CL_owner, CR: CR_owner },
      spender: { CL: CL_spender, CR: CR_spender },
    };
  }

  /**
   * Read and decode confidential allowance between owner and spender.
   * Returns decoded amounts for owner and spender parts (if this client can decrypt).
   */
  async readOwnerAllowance(
    PrivacyToken: PrivacyTokenContract,
    ownerAddress: string
  ): Promise<{
    owner: { CL: SolidityPointInput; CR: SolidityPointInput };
    spender: { CL: SolidityPointInput; CR: SolidityPointInput };
  }> {
    const bytes = await PrivacyToken.read.confidentialAllowance([
      getAddress(ownerAddress) as `0x${string}`,
      this.walletAccount.address as `0x${string}`,
    ]);

    if (!bytes || bytes === "0x") {
      throw new Error("Allowance not found");
    }

    // Decode 8 uint256 values: CL_owner.x, CL_owner.y, CR_owner.x, CR_owner.y,
    //                          CL_spender.x, CL_spender.y, CR_spender.x, CR_spender.y
    const decoded = this.abiCoder.decode(
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
      bytes as `0x${string}`
    ) as bigint[];

    const CL_owner = { x: BigInt(decoded[0]), y: BigInt(decoded[1]) };
    const CR_owner = { x: BigInt(decoded[2]), y: BigInt(decoded[3]) };
    const CL_spender = { x: BigInt(decoded[4]), y: BigInt(decoded[5]) };
    const CR_spender = { x: BigInt(decoded[6]), y: BigInt(decoded[7]) };

    return {
      owner: { CL: CL_owner, CR: CR_owner },
      spender: { CL: CL_spender, CR: CR_spender },
    };
  }

  async readBalanceWithInput(CL: SolidityPointInput, CR: SolidityPointInput) {
    return readBalanceWithOnchainData([CL, CR], this.privateKey);
  }

  /**
   * Revoke allowance for a spender
   * @param PrivacyToken The contract instance
   * @param spenderAddress The address of the spender to revoke allowance for
   */
  async revokeAllowance(
    PrivacyToken: PrivacyTokenContract,
    spenderAddress: string
  ) {
    return PrivacyToken.write.revokeAllowance(
      [getAddress(spenderAddress) as `0x${string}`],
      { account: this.walletAccount }
    );
  }
}

export default Client;
