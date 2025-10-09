// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "./BabyJub.sol";
import "./Verifier/Verifier.sol";
import "./interfaces/IERC7945.sol";

contract PrivacyToken is IERC7945 {
    using BabyJub for BabyJub.Point;

    uint8 immutable public DECIMALS;
    uint256 constant public MAX = 4294967295; // 2^32 - 1
    address constant LOCK_ADDRESS = 0x0000000000000000000000000000000000000001;
    Verifier public verifier;

    // 0: CL
    // 1: CR
    mapping(address => BabyJub.Point[2]) public acc; // main account mapping
    mapping(address => BabyJub.Point[2]) public pending; // storage for pending transfers
    mapping(address => uint256) public lastRollOver;
    mapping(address => uint256) public counter;

    // EIP-7945: Confidential allowance mapping
    // Maps from (owner, spender) to encrypted allowance value
    mapping(address => mapping(address => bytes)) public confidentialAllowances;

    // EIP-7945: Address to public key mapping
    // Maps from address to BabyJub.Point public key
    mapping(address => BabyJub.Point) public addressToPublicKey;
    mapping(address => bool) public isRegistered;

    // EIP-7945: Token metadata
    string public tokenName;
    string public tokenSymbol;

    uint256 public epochLength;
    uint256 public lastGlobalUpdate = 0; 
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
    function registerAccount(BabyJub.Point memory publicKey, uint256 c, uint256 s) public {
        require(publicKey.isOnCurve(), "Invalid public key");
        // allows y to participate. c, s should be a Schnorr signature on "this"
        BabyJub.Point memory K = BabyJub.base().mul(s).add(BabyJub.neg(BabyJub.mul(publicKey, c)));        
        uint256 challenge = uint256(keccak256(abi.encode(address(this), msg.sender, publicKey, K))) % BabyJub.SUBGROUP_ORDER;
        require(challenge == c, "Invalid registration signature!");

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

    function mint() public  payable {
        require(registered(msg.sender), "Account not registered");

        uint256 amount = msg.value;
        uint256 mintedAmount = amount * 10 ** DECIMALS / 10 ** 18;
        _totalSupply += mintedAmount;
        require(_totalSupply <= MAX, "Total supply exceeds maximum");

        BabyJub.Point memory publicKey = addressToPublicKey[msg.sender];
        _rollOver(msg.sender);

        pending[msg.sender][0] = BabyJub.add(pending[msg.sender][0], BabyJub.mul(BabyJub.base(), mintedAmount));
    }

    function rollOver(address account) public {
        _rollOver(account);
    }

    function _rollOver(address account) internal {
        uint256 e = block.number / epochLength;

        if (lastRollOver[account] < e) {
            BabyJub.Point[2][2] memory scratch = [acc[account], pending[account]];
            acc[account][0] = BabyJub.add(scratch[0][0], scratch[1][0]);
            acc[account][1] = BabyJub.add(scratch[0][1], scratch[1][1]);

            pending[account][0] = BabyJub.id();
            pending[account][1] = BabyJub.id();

            lastRollOver[account] = e;
        }
    }

    function simulateAccounts(address[] memory accountAddresses, uint256 epoch) view public returns (BabyJub.Point[2][] memory accountBalances) {

        uint256 size = accountAddresses.length;
        accountBalances = new BabyJub.Point[2][](size);

        for (uint256 i = 0; i < size; i++) {
            accountBalances[i] = acc[accountAddresses[i]];

            if (lastRollOver[accountAddresses[i]] < epoch) {

                BabyJub.Point[2] memory pendingData = pending[accountAddresses[i]];

                accountBalances[i][0] = BabyJub.add(accountBalances[i][0], pendingData[0]);
                accountBalances[i][1] = BabyJub.add(accountBalances[i][1], pendingData[1]);

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

        require(0 <= bTransfer && bTransfer <= MAX, "Transfer amount out of range.");

        BabyJub.Point[2] memory scratch = pending[msg.sender];

        BabyJub.Point memory burnAmount = BabyJub.neg(BabyJub.mul(BabyJub.base(), bTransfer));
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

        require(verifier.verifyBurnProof(proof, _pubSignals), "Burn proof verification failed!");

        // transfer eth to msg.sender
        uint256 transferAmount = bTransfer * 10 ** 18 / 10 ** DECIMALS;
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
    function confidentialBalanceOf(address owner) 
        public view override returns (bytes memory confidentialBalance) 
    {
        if(!registered(owner)) {
            return new bytes(0);
        }

        address[] memory ownerArray = new address[](1);
        ownerArray[0] = owner;
        BabyJub.Point[2] memory currentBalance = simulateAccounts(ownerArray, block.number / epochLength)[0];
        
        // Encode the balance as bytes
        // In a full implementation, this would be encrypted under the public key
        return abi.encode(currentBalance[0].x, currentBalance[0].y, currentBalance[1].x, currentBalance[1].y);
    }

    /**
     * @dev Transfers confidential tokens to another address
     * @param _to The address to transfer to
     * @param _confidentialTransferValue The encrypted transfer value
     * @return success True if the transfer was successful
     */
    function confidentialTransfer(
        address _to,
        // encode C_send, C_receive, D
        bytes memory _confidentialTransferValue, 
        bytes memory _proof
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

        // decode confidential transfer value
        uint256[4] memory transferValue = abi.decode(_confidentialTransferValue, (uint256[4]));
        // decode C_send, C_receive, D
        BabyJub.Point[3] memory points = abi.decode(_confidentialTransferValue, (BabyJub.Point[3]));
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

        require(verifier.verifyTransferProof(proof, _pubSignals), "Transfer proof verification failed!");

        acc[msg.sender][0] = BabyJub.add(acc[msg.sender][0], C_send.neg());
        acc[msg.sender][1] = BabyJub.add(acc[msg.sender][1], D.neg());

        pending[_to][0] = BabyJub.add(pending[_to][0], C_receive);
        pending[_to][1] = BabyJub.add(pending[_to][1], D);

        counter[msg.sender]++;
        
        emit ConfidentialTransfer(address(0), msg.sender, _to, _confidentialTransferValue);
        return true;
    }

    /**
     * @dev Transfers confidential tokens from one address to another (with allowance)
     * @param _from The address to transfer from
     * @param _to The address to transfer to
     * @param _confidentialTransferValue The encrypted transfer value
     * @param _proof The zero-knowledge proof of the transfer
     * @return success True if the transfer was successful
     */
    function confidentialTransferFrom(
        address _from,
        address _to,
        bytes memory _confidentialTransferValue, 
        bytes memory _proof
    ) public override returns (bool success) {
        // For now, this is not implemented as it requires allowance management
        // This would need to be implemented with confidential allowance tracking
        revert("confidentialTransferFrom not implemented");
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
        bytes memory _confidentialValue, 
        bytes memory _proof
    ) public override returns (bool success) {
        // For now, this is not implemented as it requires allowance management
        // This would need to be implemented with confidential allowance tracking
        revert("confidentialApprove not implemented");
    }

    /**
     * @dev Returns the confidential allowance for a spender
     * @param _owner The address of the owner
     * @param _spender The address of the spender
     * @return _confidentialValue The encrypted allowance value
     */
    function confidentialAllowance(address _owner, address _spender)
        public view override returns (bytes memory _confidentialValue) {
        // For now, this is not implemented as it requires allowance management
        // This would need to be implemented with confidential allowance tracking
        return new bytes(0);
    }

    /**
     * @dev Returns the confidential total supply
     * @return The encrypted total supply
     */
    function confidentialTotalSupply() public view override returns (bytes memory) {
        // For now, this is not implemented as it requires encryption of total supply
        // This would need to be implemented with proper encryption
        return new bytes(0);
    }
}
