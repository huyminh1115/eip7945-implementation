import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { AbiCoder } from "ethers";
import hre from "hardhat";
import { groth16 } from "snarkjs";
console.log("debug", Boolean(fs), Boolean(os), Boolean(path), Boolean(process), Boolean(AbiCoder), Boolean(hre), Boolean(groth16));
