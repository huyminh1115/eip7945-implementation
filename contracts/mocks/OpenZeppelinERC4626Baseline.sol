// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/// @dev Local-only benchmark fixture for the OpenZeppelin ERC-4626 reference.
contract BenchmarkAsset is ERC20 {
    constructor() ERC20("Benchmark Asset", "BASSET") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Unmodified OpenZeppelin ERC-4626 behavior with only constructor wiring.
contract OpenZeppelinERC4626Baseline is ERC4626 {
    constructor(ERC20 asset_) ERC20("OpenZeppelin Vault Share", "OZVS") ERC4626(asset_) {}
}
