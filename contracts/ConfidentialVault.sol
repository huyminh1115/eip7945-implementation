// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "./ZKToken.sol";
import "./Verifier/UpdateRateVerifier.sol";
import "./BabyJub.sol";

/**
 * @title ConfidentialVault
 * @notice Wraps ZKToken share accounting with DarkVault-style vault logic.
 *         - Keeps the IERC-7945 surface via ZKToken inheritance.
 *         - Manages deposits/withdrawals against an external ZKToken asset.
 *         - Maintains a configurable asset/share ratio verified by SNARK proofs.
 */
contract ConfidentialVault is ZKToken {
    using BabyJub for BabyJub.Point;

    /// @notice External asset that actually custodies funds.
    ZKToken public immutable assetContract;
    /// @notice Dedicated verifier for ratio updates (mirrors DarkVault logic).
    UpdateRateVerifier public immutable updateRateVerifier;

    /// @notice Ratio precision used to scale ciphertexts into vault shares.
    uint8 public immutable RATIO_DECIMALS;
    /// @notice Address that represents the vault's vault manager address.
    address public immutable vaultManagerAddress;
    /// @notice BabyJub public key for the vault manager account.
    BabyJub.Point public vaultManagerAccount;

    /// @notice (total shares) / (total assets) encoded with RATIO_DECIMALS.
    uint256 public ratio;
    /// @notice Gate to prevent deposits before underlying assets are prepared.
    bool public isActive;

    event VaultActivated(address indexed operator);
    event VaultDeposit(address indexed depositor, bytes assetTransfer);
    event VaultWithdraw(address indexed withdrawer, bytes assetTransfer);
    event VaultRatioUpdated(uint256 newRatio);

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _epochLength,
        address _assetAddress,
        address _blackHoleAccount,
        BabyJub.Point memory _blackHole,
        uint8 _ratioDecimals
    ) ZKToken(_name, _symbol, _decimals, _epochLength) {
        require(_assetAddress != address(0), "Invalid asset address");
        require(_blackHoleAccount != address(0), "Invalid black hole");

        assetContract = ZKToken(_assetAddress);
        updateRateVerifier = new UpdateRateVerifier();

        vaultManagerAddress = _blackHoleAccount;
        vaultManagerAccount = _blackHole;

        RATIO_DECIMALS = _ratioDecimals;
        ratio = 10 ** _ratioDecimals;

        // Initialize vault-side black hole bookkeeping so share maths start from identity.
        addressToPublicKey[_blackHoleAccount] = _blackHole;
        isRegistered[_blackHoleAccount] = true;

        acc[_blackHoleAccount][0] = _blackHole;
        acc[_blackHoleAccount][1] = BabyJub.base();

        allowedAmount[_blackHoleAccount][0] = _blackHole;
        allowedAmount[_blackHoleAccount][1] = BabyJub.base();

        pending[_blackHoleAccount][0] = BabyJub.id();
        pending[_blackHoleAccount][1] = BabyJub.id();

        lastRollOver[_blackHoleAccount] = block.number / epochLength;

        isActive = false;
    }

    /**
     * @notice Activates the vault once the external ZKToken is configured.
     *         Only the designated black hole account can trigger this.
     */
    function activate() external {
        require(msg.sender == vaultManagerAddress, "Only black hole");
        require(!isActive, "Already activated");
        require(
            assetContract.registered(vaultManagerAddress),
            "Black hole not registered on asset"
        );

        isActive = true;
        emit VaultActivated(msg.sender);
    }

    /**
     * @notice Deposits assets into the vault.
     *         The caller must have pre-generated ciphertexts/proofs compatible
     *         with ZKToken.confidentialTransferWithSender.
     * @param _confidentialDepositValue Encoded BabyJub ciphertexts (C_send, C_receive, D).
     * @param assetProof SNARK proof authorizing the asset movement.
     */
    function confidentialDeposit(
        bytes calldata _confidentialDepositValue,
        bytes calldata assetProof
    ) external {
        require(isActive, "Vault inactive");
        require(registered(msg.sender), "Vault share account missing");
        require(
            assetContract.registered(msg.sender),
            "Asset account not registered"
        );

        _rollOver(msg.sender);
        _rollOver(vaultManagerAddress);

        BabyJub.Point[3] memory assetCiphertext = abi.decode(
            _confidentialDepositValue,
            (BabyJub.Point[3])
        );

        // Scale ciphertexts into share domain using the current ratio.
        BabyJub.Point memory scaledSend = BabyJub.mul(
            assetCiphertext[0],
            ratio
        );
        BabyJub.Point memory scaledReceive = BabyJub.mul(
            assetCiphertext[1],
            ratio
        );
        BabyJub.Point memory scaledRandomness = BabyJub.mul(
            assetCiphertext[2],
            ratio
        );

        pending[msg.sender][0] = BabyJub.add(
            pending[msg.sender][0],
            scaledSend
        );
        pending[msg.sender][1] = BabyJub.add(
            pending[msg.sender][1],
            scaledRandomness
        );

        pending[vaultManagerAddress][0] = BabyJub.add(
            pending[vaultManagerAddress][0],
            scaledReceive
        );
        pending[vaultManagerAddress][1] = BabyJub.add(
            pending[vaultManagerAddress][1],
            scaledRandomness
        );

        assetContract.confidentialTransferWithSender(
            msg.sender,
            vaultManagerAddress,
            _confidentialDepositValue,
            assetProof
        );

        emit VaultDeposit(msg.sender, _confidentialDepositValue);
    }

    /**
     * @notice Withdraws assets from the vault.
     *         The caller supplies ciphertexts/proofs that move assets from the
     *         black hole account back to their address inside the asset token.
     * @param _confidentialWithdrawValue Encoded BabyJub ciphertexts (C_send, C_receive, D).
     * @param assetProof SNARK proof authorizing the asset movement.
     */
    function confidentialWithdraw(
        bytes calldata _confidentialWithdrawValue,
        bytes calldata assetProof
    ) external {
        require(isActive, "Vault inactive");
        require(registered(msg.sender), "Vault share account missing");
        require(
            assetContract.registered(msg.sender),
            "Asset account not registered"
        );

        _rollOver(vaultManagerAddress);
        _rollOver(msg.sender);

        BabyJub.Point[3] memory assetCiphertext = abi.decode(
            _confidentialWithdrawValue,
            (BabyJub.Point[3])
        );

        assetContract.confidentialTransferWithSender(
            vaultManagerAddress,
            msg.sender,
            _confidentialWithdrawValue,
            assetProof
        );

        BabyJub.Point memory scaledReceive = BabyJub.mul(
            assetCiphertext[1],
            ratio
        );
        BabyJub.Point memory scaledRandomness = BabyJub.mul(
            assetCiphertext[2],
            ratio
        );
        BabyJub.Point memory scaledSend = BabyJub.mul(
            assetCiphertext[0],
            ratio
        );

        acc[msg.sender][0] = BabyJub.add(
            acc[msg.sender][0],
            scaledReceive.neg()
        );
        acc[msg.sender][1] = BabyJub.add(
            acc[msg.sender][1],
            scaledRandomness.neg()
        );

        acc[vaultManagerAddress][0] = BabyJub.add(
            acc[vaultManagerAddress][0],
            scaledSend.neg()
        );
        acc[vaultManagerAddress][1] = BabyJub.add(
            acc[vaultManagerAddress][1],
            scaledRandomness.neg()
        );

        emit VaultWithdraw(msg.sender, _confidentialWithdrawValue);
    }

    /**
     * @notice Recomputes the asset/share ratio using a dedicated SNARK proof.
     * @dev Mirrors DarkVault.updateRatio with address-based state.
     * @param newRatio The freshly computed ratio (already scaled by RATIO_DECIMALS).
     * @param proof SNARK proof from UpdateRateVerifier.
     */
    function updateRatio(uint256 newRatio, bytes calldata proof) external {
        require(newRatio > 0, "Invalid ratio");

        address[] memory targets = new address[](1);
        targets[0] = vaultManagerAddress;

        uint256 currentEpoch = block.number / epochLength;
        BabyJub.Point[2] memory curShare = simulateAccounts(
            targets,
            currentEpoch
        )[0];

        BabyJub.Point[2] memory curAsset = assetContract.simulateAccounts(
            targets,
            block.number / assetContract.epochLength()
        )[0];

        uint256[11] memory pubSignals = [
            vaultManagerAccount.x,
            vaultManagerAccount.y,
            curAsset[0].x,
            curAsset[0].y,
            curAsset[1].x,
            curAsset[1].y,
            curShare[0].x,
            curShare[0].y,
            curShare[1].x,
            curShare[1].y,
            newRatio
        ];

        uint256[8] memory decodedProof = abi.decode(proof, (uint256[8]));
        uint256[2] memory proofA = [decodedProof[0], decodedProof[1]];
        uint256[2][2] memory proofB = [
            [decodedProof[2], decodedProof[3]],
            [decodedProof[4], decodedProof[5]]
        ];
        uint256[2] memory proofC = [decodedProof[6], decodedProof[7]];
        require(
            updateRateVerifier.verifyProof(proofA, proofB, proofC, pubSignals),
            "Update rate proof failed"
        );

        ratio = newRatio;
        emit VaultRatioUpdated(newRatio);
    }
}
