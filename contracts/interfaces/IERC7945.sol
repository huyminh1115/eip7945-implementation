// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

/**
 * @title IERC7945 - Confidential Transactions Supported Token Interface
 * @dev This interface defines the standard for confidential transaction supported tokens
 * @notice Based on EIP-7945: Confidential Transactions Supported Token
 */
interface IERC7945 {
    // ============ Optional Metadata Methods ============
    
    /**
     * @dev Returns the name of the token
     * @return The name of the token
     */
    function name() external view returns (string memory);
    
    /**
     * @dev Returns the symbol of the token
     * @return The symbol of the token
     */
    function symbol() external view returns (string memory);
    
    /**
     * @dev Returns the number of decimals the token uses
     * @return The number of decimals
     */
    function decimals() external view returns (uint8);
    
    // ============ Core Confidential Methods ============
    
    /**
     * @dev Returns the confidential balance of an account
     * @param owner The address of the account to query
     * @return confidentialBalance The encrypted balance data
     */
    function confidentialBalanceOf(address owner) 
        external view returns (bytes memory confidentialBalance);
    
    /**
     * @dev Transfers confidential tokens to another address
     * @param _to The address to transfer to
     * @param _confidentialTransferValue The encrypted transfer value
     * @param _proof The zero-knowledge proof of the transfer
     * @return success True if the transfer was successful
     */
    function confidentialTransfer(
        address _to,
        bytes memory _confidentialTransferValue, 
        bytes memory _proof
    ) external returns (bool success);
    
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
    ) external returns (bool success);
    
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
    ) external returns (bool success);
    
    /**
     * @dev Returns the confidential allowance for a spender
     * @param _owner The address of the owner
     * @param _spender The address of the spender
     * @return _confidentialValue The encrypted allowance value
     */
    function confidentialAllowance(address _owner, address _spender)
        external view returns (bytes memory _confidentialValue);
    
    // ============ Optional Total Supply Method ============
    
    /**
     * @dev Returns the confidential total supply
     * @return The encrypted total supply
     */
    function confidentialTotalSupply() external view returns (bytes memory);
    
    // ============ Events ============
    
    /**
     * @dev Emitted when confidential tokens are transferred
     * @param _spender The address that initiated the transfer (0x0 for direct transfers)
     * @param _from The address tokens were transferred from
     * @param _to The address tokens were transferred to
     * @param _confidentialTransferValue The encrypted transfer value
     */
    event ConfidentialTransfer(
        address indexed _spender,
        address indexed _from, 
        address indexed _to, 
        bytes _confidentialTransferValue
    );
    
    /**
     * @dev Emitted when confidential allowance is approved
     * @param _owner The address of the owner
     * @param _spender The address of the spender
     * @param _currentAllowancePart The current allowance part
     * @param _allowancePart The new allowance part
     */
    event ConfidentialApproval(
        address indexed _owner,
        address indexed _spender,
        bytes _currentAllowancePart,
        bytes _allowancePart
    );
}
