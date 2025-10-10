// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "./BabyJub.sol";
import "./Verifier/Verifier.sol";
import "./interfaces/IERC7945.sol";

contract PrivacyToken is IERC7945 {
    using BabyJub for BabyJub.Point;
    struct Allowance {
        BabyJub.Point CL_owner;
        BabyJub.Point CR_owner;
        BabyJub.Point CL_spender;
        BabyJub.Point CR_spender;
    }

    uint8 public immutable DECIMALS;
    uint256 public constant MAX = 4294967295; // 2^32 - 1
    Verifier public verifier;

    // 0: CL
    // 1: CR
    mapping(address => BabyJub.Point[2]) public acc; // main account mapping
    mapping(address => BabyJub.Point[2]) public pending; // storage for pending transfers
    mapping(address => mapping(address => Allowance)) public allowance;
    mapping(address => uint256) public lastRollOver;
    mapping(address => uint256) public counter;

    // EIP-7945: Address to public key mapping
    // Maps from address to BabyJub.Point public key
    mapping(address => BabyJub.Point) public addressToPublicKey;
    mapping(address => bool) public isRegistered;

    // EIP-7945: Token metadata
    string public tokenName;
    string public tokenSymbol;

    uint256 public epochLength;
    uint256 public _totalSupply;

    // EIP-7945: Events are defined in the interface

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _epochLength
    ) {
        tokenName = _name;
        tokenSymbol = _symbol;
        DECIMALS = _decimals;
        epochLength = _epochLength;

        verifier = new Verifier();
    }

    /**
     * @dev Registers an address with a public key for EIP-7945 compatibility
     * @param publicKey The BabyJub.Point public key to associate with the caller's address
     */
    function registerAccount(BabyJub.Point memory publicKey) public {
        require(publicKey.isOnCurve(), "Invalid public key");
        addressToPublicKey[msg.sender] = publicKey;
        isRegistered[msg.sender] = true;

        acc[msg.sender][0] = publicKey;
        acc[msg.sender][1] = BabyJub.base();

        pending[msg.sender][0] = BabyJub.id();
        pending[msg.sender][1] = BabyJub.id();
    }

    function registered(address account) public view returns (bool) {
        return isRegistered[account];
    }

    function isInitAllowance(
        Allowance memory _allowance
    ) public pure returns (bool) {
        return
            _allowance.CL_owner.eq(BabyJub.Point(0, 0)) &&
            _allowance.CR_owner.eq(BabyJub.Point(0, 0)) &&
            _allowance.CL_spender.eq(BabyJub.Point(0, 0)) &&
            _allowance.CR_spender.eq(BabyJub.Point(0, 0));
    }

    function mint() public payable {
        require(registered(msg.sender), "Account not registered");

        uint256 amount = msg.value;
        uint256 mintedAmount = (amount * 10 ** DECIMALS) / 10 ** 18;
        _totalSupply += mintedAmount;
        require(_totalSupply <= MAX, "Total supply exceeds maximum");

        _rollOver(msg.sender);

        pending[msg.sender][0] = BabyJub.add(
            pending[msg.sender][0],
            BabyJub.mul(BabyJub.base(), mintedAmount)
        );
    }

    function rollOver(address account) public {
        _rollOver(account);
    }

    function _rollOver(address account) internal {
        uint256 e = block.number / epochLength;

        if (lastRollOver[account] < e) {
            BabyJub.Point[2][2] memory scratch = [
                acc[account],
                pending[account]
            ];
            acc[account][0] = BabyJub.add(scratch[0][0], scratch[1][0]);
            acc[account][1] = BabyJub.add(scratch[0][1], scratch[1][1]);

            pending[account][0] = BabyJub.id();
            pending[account][1] = BabyJub.id();

            lastRollOver[account] = e;
        }
    }

    function simulateAccounts(
        address[] memory accountAddresses,
        uint256 epoch
    ) public view returns (BabyJub.Point[2][] memory accountBalances) {
        uint256 size = accountAddresses.length;
        accountBalances = new BabyJub.Point[2][](size);

        for (uint256 i = 0; i < size; i++) {
            accountBalances[i] = acc[accountAddresses[i]];

            if (lastRollOver[accountAddresses[i]] < epoch) {
                BabyJub.Point[2] memory pendingData = pending[
                    accountAddresses[i]
                ];

                accountBalances[i][0] = BabyJub.add(
                    accountBalances[i][0],
                    pendingData[0]
                );
                accountBalances[i][1] = BabyJub.add(
                    accountBalances[i][1],
                    pendingData[1]
                );
            }
        }
    }

    function burn(uint256 bTransfer, bytes memory _proof) public {
        require(registered(msg.sender), "Account not yet registered.");
        _rollOver(msg.sender);

        // decode proof
        uint256[8] memory proof = abi.decode(_proof, (uint256[8]));

        // current balance after roll over
        BabyJub.Point[2] memory currentBalance = acc[msg.sender];

        require(bTransfer <= MAX, "Transfer amount out of range.");

        BabyJub.Point[2] memory scratch = pending[msg.sender];

        BabyJub.Point memory burnAmount = BabyJub.neg(
            BabyJub.mul(BabyJub.base(), bTransfer)
        );
        pending[msg.sender][0] = BabyJub.add(scratch[0], burnAmount);

        uint256[8] memory _pubSignals = [
            addressToPublicKey[msg.sender].x,
            addressToPublicKey[msg.sender].y,
            currentBalance[0].x,
            currentBalance[0].y,
            currentBalance[1].x,
            currentBalance[1].y,
            bTransfer,
            counter[msg.sender]
        ];

        require(
            verifier.verifyBurnProof(proof, _pubSignals),
            "Burn proof verification failed!"
        );

        // transfer eth to msg.sender
        uint256 transferAmount = (bTransfer * 10 ** 18) / 10 ** DECIMALS;
        payable(msg.sender).transfer(transferAmount);

        counter[msg.sender]++;

        _totalSupply -= bTransfer;
    }

    // ============ EIP-7945 Implementation ============

    /**
     * @dev Returns the name of the token
     * @return The name of the token
     */
    function name() public view override returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Returns the symbol of the token
     * @return The symbol of the token
     */
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /**
     * @dev Returns the number of decimals the token uses
     * @return The number of decimals
     */
    function decimals() public view override returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the confidential balance of an account
     * @param owner The address of the account to query
     * @return confidentialBalance The encrypted balance data
     * @notice This function requires the owner to have a registered public key
     */
    function confidentialBalanceOf(
        address owner
    ) public view override returns (bytes memory confidentialBalance) {
        if (!registered(owner)) {
            return new bytes(0);
        }

        address[] memory ownerArray = new address[](1);
        ownerArray[0] = owner;
        BabyJub.Point[2] memory currentBalance = simulateAccounts(
            ownerArray,
            block.number / epochLength
        )[0];

        // Encode the balance as bytes
        // In a full implementation, this would be encrypted under the public key
        return
            abi.encode(
                currentBalance[0].x,
                currentBalance[0].y,
                currentBalance[1].x,
                currentBalance[1].y
            );
    }

    /**
     * @dev Transfers confidential tokens to another address
     * @param _to The address to transfer to
     * @param _confidentialTransferValue Encoded transfer data containing C_send, C_receive, and D points
     * @param _proof Zero-knowledge proof validating the transfer
     * @return success True if the transfer was successful
     */
    function confidentialTransfer(
        address _to,
        bytes calldata _confidentialTransferValue,
        bytes calldata _proof
    ) public override returns (bool success) {
        // Check if both addresses have registered public keys
        require(registered(msg.sender), "Sender public key not registered");
        require(registered(_to), "Receiver public key not registered");

        // Get the public keys for sender and receiver
        BabyJub.Point memory senderPubKey = addressToPublicKey[msg.sender];
        BabyJub.Point memory receiverPubKey = addressToPublicKey[_to];

        // roll over sender
        _rollOver(msg.sender);
        // roll over receiver
        _rollOver(_to);

        // decode proof
        uint256[8] memory proof = abi.decode(_proof, (uint256[8]));

        // decode C_send, C_receive, D
        BabyJub.Point[3] memory points = abi.decode(
            _confidentialTransferValue,
            (BabyJub.Point[3])
        );
        BabyJub.Point memory C_send = points[0];
        BabyJub.Point memory C_receive = points[1];
        BabyJub.Point memory D = points[2];

        uint256[16] memory _pubSignals = [
            senderPubKey.x,
            senderPubKey.y,
            receiverPubKey.x,
            receiverPubKey.y,
            acc[msg.sender][0].x, // updated balance after roll over
            acc[msg.sender][0].y, // updated balance after roll over
            acc[msg.sender][1].x, // updated balance after roll over
            acc[msg.sender][1].y, // updated balance after roll over
            C_send.x,
            C_send.y,
            D.x,
            D.y,
            C_receive.x,
            C_receive.y,
            counter[msg.sender],
            MAX
        ];

        require(
            verifier.verifyTransferProof(proof, _pubSignals),
            "Transfer proof verification failed!"
        );

        acc[msg.sender][0] = BabyJub.add(acc[msg.sender][0], C_send.neg());
        acc[msg.sender][1] = BabyJub.add(acc[msg.sender][1], D.neg());

        pending[_to][0] = BabyJub.add(pending[_to][0], C_receive);
        pending[_to][1] = BabyJub.add(pending[_to][1], D);

        counter[msg.sender]++;

        emit ConfidentialTransfer(
            address(0),
            msg.sender,
            _to,
            _confidentialTransferValue
        );
        return true;
    }

    /**
     * @dev Transfers confidential tokens from one address to another using allowance
     * @param _from The address to transfer from (owner)
     * @param _to The address to transfer to (recipient)
     * @param _confidentialTransferFromValue Encoded transfer data containing:
     *        - C_from: encrypted from balance
     *        - C_spender: encrypted spender balance
     *        - C_to: encrypted to balance
     *        - D: shared randomness
     * @param _proof Zero-knowledge proof validating the transfer from operation
     * @return success True if the transfer was successful
     */
    function confidentialTransferFrom(
        address _from,
        address _to,
        bytes calldata _confidentialTransferFromValue,
        bytes calldata _proof
    ) public override returns (bool success) {
        // Check if addresses have registered public keys
        require(registered(msg.sender), "Spender public key not registered");
        require(registered(_from), "From public key not registered"); // from / owner
        require(registered(_to), "To public key not registered");

        // current allowance
        Allowance memory currentAllowance = allowance[_from][msg.sender];
        // allowance must not be in init state first
        require(!isInitAllowance(currentAllowance), "Invalid allowance");

        // only need to roll over _to
        _rollOver(_to);

        // decode confidential transfer from value
        // decode C_from, C_spender, C_to, D
        BabyJub.Point[4] memory points = abi.decode(
            _confidentialTransferFromValue,
            (BabyJub.Point[4])
        );
        BabyJub.Point memory C_from = points[0];
        BabyJub.Point memory C_spender = points[1];
        BabyJub.Point memory C_to = points[2];
        BabyJub.Point memory D = points[3];

        // prevent stack too deep
        {
            // Get the public keys for owner and spender
            BabyJub.Point memory spenderPubkey = addressToPublicKey[msg.sender];
            BabyJub.Point memory fromPubkey = addressToPublicKey[_from];
            BabyJub.Point memory toPubkey = addressToPublicKey[_to];
            // decode proof
            uint256[8] memory proof = abi.decode(_proof, (uint256[8]));

            uint256[20] memory _pubSignals = [
                spenderPubkey.x,
                spenderPubkey.y,
                toPubkey.x,
                toPubkey.y,
                fromPubkey.x,
                fromPubkey.y,
                currentAllowance.CL_spender.x,
                currentAllowance.CL_spender.y,
                currentAllowance.CR_spender.x,
                currentAllowance.CR_spender.y,
                C_spender.x,
                C_spender.y,
                D.x,
                D.y,
                C_to.x,
                C_to.y,
                C_from.x,
                C_from.y,
                counter[msg.sender], // spender counter
                MAX
            ];

            require(
                verifier.verifyTransferFromProof(proof, _pubSignals),
                "Transfer from proof verification failed!"
            );
        }

        // reduce in allowance
        currentAllowance.CL_owner = BabyJub.add(
            currentAllowance.CL_owner,
            C_from.neg()
        );
        currentAllowance.CR_owner = BabyJub.add(
            currentAllowance.CR_owner,
            D.neg()
        );
        currentAllowance.CL_spender = BabyJub.add(
            currentAllowance.CL_spender,
            C_spender.neg()
        );
        currentAllowance.CR_spender = BabyJub.add(
            currentAllowance.CR_spender,
            D.neg()
        );

        // update current allowance
        allowance[_from][msg.sender] = currentAllowance;

        // increase in pending bal
        pending[_to][0] = BabyJub.add(pending[_to][0], C_to);
        pending[_to][1] = BabyJub.add(pending[_to][1], D);

        counter[msg.sender]++;

        emit ConfidentialTransfer(
            msg.sender,
            _from,
            _to,
            _confidentialTransferFromValue
        );
        return true;
    }

    /**
     * @dev Approves a spender to use a portion of confidential balance
     * @param _spender The address to approve
     * @param _confidentialValue The encrypted allowance value
     * @param _proof The zero-knowledge proof of the approval
     * @return success True if the approval was successful
     */
    function confidentialApprove(
        address _spender,
        bytes calldata _confidentialValue,
        bytes calldata _proof
    ) public override returns (bool success) {
        // Check if both addresses have registered public keys
        require(registered(msg.sender), "Sender public key not registered");
        require(registered(_spender), "Spender public key not registered");

        // current allowance
        Allowance memory currentAllowance = allowance[msg.sender][_spender];
        // allowance must be zero state first
        require(isInitAllowance(currentAllowance), "Invalid allowance");

        // Get the public keys for owner and spender
        BabyJub.Point memory ownerPubkey = addressToPublicKey[msg.sender];
        BabyJub.Point memory spenderPubkey = addressToPublicKey[_spender];

        // roll over owner
        _rollOver(msg.sender);
        // roll over spender
        _rollOver(_spender);

        // decode C_owner, C_spender, D
        BabyJub.Point[3] memory points = abi.decode(
            _confidentialValue,
            (BabyJub.Point[3])
        );
        BabyJub.Point memory C_owner = points[0];
        BabyJub.Point memory C_spender = points[1];
        BabyJub.Point memory D = points[2];

        // prevent stack too deep
        {
            // decode proof
            uint256[8] memory proof = abi.decode(_proof, (uint256[8]));

            uint256[16] memory _pubSignals = [
                ownerPubkey.x,
                ownerPubkey.y,
                spenderPubkey.x,
                spenderPubkey.y,
                acc[msg.sender][0].x, // updated balance after roll over
                acc[msg.sender][0].y, // updated balance after roll over
                acc[msg.sender][1].x, // updated balance after roll over
                acc[msg.sender][1].y, // updated balance after roll over
                C_owner.x,
                C_owner.y,
                D.x,
                D.y,
                C_spender.x,
                C_spender.y,
                counter[msg.sender],
                MAX
            ];

            require(
                verifier.verifyTransferProof(proof, _pubSignals),
                "Approve proof verification failed!"
            );
        }

        // spender/owner will reduce in balance
        acc[msg.sender][0] = BabyJub.add(acc[msg.sender][0], C_owner.neg());
        acc[msg.sender][1] = BabyJub.add(acc[msg.sender][1], D.neg());

        // set based point to allowance
        currentAllowance.CL_owner = BabyJub.id();
        currentAllowance.CR_owner = BabyJub.id();
        currentAllowance.CL_spender = BabyJub.id();
        currentAllowance.CR_spender = BabyJub.id();

        // increase in allowance
        allowance[msg.sender][_spender] = Allowance(
            BabyJub.add(currentAllowance.CL_owner, C_owner),
            BabyJub.add(currentAllowance.CR_owner, D),
            BabyJub.add(currentAllowance.CL_spender, C_spender),
            BabyJub.add(currentAllowance.CR_spender, D)
        );

        counter[msg.sender]++;

        emit ConfidentialApproval(
            msg.sender,
            _spender,
            new bytes(0),
            abi.encode(
                currentAllowance.CL_owner.x,
                currentAllowance.CL_owner.y,
                currentAllowance.CR_owner.x,
                currentAllowance.CR_owner.y,
                currentAllowance.CL_spender.x,
                currentAllowance.CL_spender.y,
                currentAllowance.CR_spender.x,
                currentAllowance.CR_spender.y
            )
        );

        return true;
    }

    /**
     * @dev Revokes allowance for a spender to prevent pre-condition conflicts
     * @notice This separate function prevents issues where:
     *         - A approves B
     *         - A tries to change approval amount
     *         - B keeps using transferFrom, preventing A from modifying allowance
     *         - Due to pre-condition checks on A's balance
     * @param _spender The address to revoke allowance for
     * @return success True if the revocation was successful
     */
    function revokeAllowance(address _spender) public returns (bool success) {
        // Check if both addresses have registered public keys
        require(registered(msg.sender), "Owner public key not registered");
        require(registered(_spender), "Spender public key not registered");

        // current allowance
        Allowance memory currentAllowance = allowance[msg.sender][_spender];
        // allowance must not be in init state first
        require(!isInitAllowance(currentAllowance), "Invalid allowance");

        // Get the public keys for owner and spender
        BabyJub.Point memory ownerPubkey = addressToPublicKey[msg.sender];
        BabyJub.Point memory spenderPubkey = addressToPublicKey[_spender];

        // roll over owner
        _rollOver(msg.sender);

        // can increase on balance immediately (don't need to worry about pre-condition, since only msg.sender can call this)
        acc[msg.sender][0] = BabyJub.add(
            acc[msg.sender][0],
            currentAllowance.CL_owner
        );
        acc[msg.sender][1] = BabyJub.add(
            acc[msg.sender][1],
            currentAllowance.CR_owner
        );

        // delete current allowance
        delete allowance[msg.sender][_spender];

        emit ConfidentialApproval(
            msg.sender,
            _spender,
            abi.encode(
                currentAllowance.CL_owner.x,
                currentAllowance.CL_owner.y,
                currentAllowance.CR_owner.x,
                currentAllowance.CR_owner.y,
                currentAllowance.CL_spender.x,
                currentAllowance.CL_spender.y,
                currentAllowance.CR_spender.x,
                currentAllowance.CR_spender.y
            ),
            new bytes(0)
        );

        return true;
    }

    /**
     * @dev Returns the confidential allowance for a spender
     * @param _owner The address of the owner
     * @param _spender The address of the spender
     * @return _confidentialValue The encrypted allowance value (owner, spender)
     */
    function confidentialAllowance(
        address _owner,
        address _spender
    ) public view override returns (bytes memory _confidentialValue) {
        Allowance memory currentAllowance = allowance[_owner][_spender];
        return
            abi.encode(
                currentAllowance.CL_owner.x,
                currentAllowance.CL_owner.y,
                currentAllowance.CR_owner.x,
                currentAllowance.CR_owner.y,
                currentAllowance.CL_spender.x,
                currentAllowance.CL_spender.y,
                currentAllowance.CR_spender.x,
                currentAllowance.CR_spender.y
            );
    }

    /**
     * @dev Returns the confidential total supply
     * @return The encrypted total supply
     */
    function confidentialTotalSupply()
        external
        view
        override
        returns (bytes memory)
    {
        // Encode total supply as bytes
        return abi.encode(_totalSupply);
    }
}
