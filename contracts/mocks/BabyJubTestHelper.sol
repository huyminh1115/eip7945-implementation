// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "../BabyJub.sol";

/**
 * @dev Helper contract that exposes BabyJub operations to Hardhat tests.
 */
contract BabyJubTestHelper {
    using BabyJub for BabyJub.Point;

    function basePoint() external pure returns (BabyJub.Point memory) {
        return BabyJub.base();
    }

    function identity() external pure returns (BabyJub.Point memory) {
        return BabyJub.id();
    }

    function mulBase(
        uint256 scalar
    ) external view returns (BabyJub.Point memory) {
        return BabyJub.mul(BabyJub.base(), scalar);
    }

    function mulPoint(
        BabyJub.Point calldata point,
        uint256 scalar
    ) external view returns (BabyJub.Point memory) {
        return BabyJub.mul(point, scalar);
    }

    function addPoints(
        BabyJub.Point calldata a,
        BabyJub.Point calldata b
    ) external view returns (BabyJub.Point memory) {
        return BabyJub.add(a, b);
    }

    function negatePoint(
        BabyJub.Point calldata p
    ) external pure returns (BabyJub.Point memory) {
        return BabyJub.neg(p);
    }

    function eqPoints(
        BabyJub.Point calldata a,
        BabyJub.Point calldata b
    ) external pure returns (bool) {
        return a.x == b.x && a.y == b.y;
    }
}
