import hre from "hardhat";
import { groth16 } from "snarkjs";
console.log("debug start", Boolean(groth16));
const accounts = await hre.viem.getWalletClients();
console.log("accounts", accounts.length);
