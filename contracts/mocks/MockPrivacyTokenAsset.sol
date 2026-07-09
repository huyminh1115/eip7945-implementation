// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "../BabyJub.sol";

/**
 * @dev Lightweight stand-in for PrivacyToken used only inside tests.
 *      The contract mirrors just enough of the interface that
 *      ConfidentialVault can call into it without dealing with zk proofs.
 */
contract MockPrivacyTokenAsset {
    using BabyJub for BabyJub.Point;

    uint256 public immutable epochLength;

    mapping(address => bool) private _registered;
    mapping(address => BabyJub.Point[2]) private _accounts;
    mapping(address => BabyJub.Point) public addressToPublicKey;

    event ForceRegistered(address indexed account, BabyJub.Point publicKey);
    event ConfidentialTransferWithSender(
        address indexed caller,
        address indexed sender,
        address indexed receiver,
        bytes value
    );

    constructor(uint256 _epochLength) {
        epochLength = _epochLength;
    }

    function registered(address account) external view returns (bool) {
        return _registered[account];
    }

    function forceRegister(
        address account,
        BabyJub.Point calldata publicKey
    ) external {
        _registered[account] = true;
        addressToPublicKey[account] = publicKey;
        _accounts[account][0] = publicKey;
        _accounts[account][1] = BabyJub.base();
        emit ForceRegistered(account, publicKey);
    }

    function confidentialTransferWithSender(
        address sender,
        address receiver,
        bytes calldata confidentialValue,
        bytes calldata /* proof */
    ) external returns (bool) {
        emit ConfidentialTransferWithSender(
            msg.sender,
            sender,
            receiver,
            confidentialValue
        );
        return true;
    }

    function simulateAccounts(
        address[] calldata addrs,
        uint256 /* epoch */
    ) external view returns (BabyJub.Point[2][] memory accounts) {
        accounts = new BabyJub.Point[2][](addrs.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            accounts[i] = _accounts[addrs[i]];
        }
    }
}
