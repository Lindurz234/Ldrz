// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Simple Treasury with Batch Transfer
/// @notice Minimal treasury contract to receive ETH and send ETH/ERC20 tokens (single & batch).
/// @dev Does not use IERC20 interface and does not provide balance check functions.
contract SimpleTreasury {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EtherReceived(address indexed from, uint256 amount);
    event EtherSent(address indexed to, uint256 amount);
    event TokenSent(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "SimpleTreasury: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Accept ETH sent directly to the contract
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice Fallback payable (in case no function matches)
    fallback() external payable {
        if (msg.value > 0) {
            emit EtherReceived(msg.sender, msg.value);
        }
    }

    /// @notice Transfer ETH from this contract to a recipient
    function sendEther(address payable to, uint256 amount) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        require(success, "SimpleTreasury: ETH transfer failed");
        emit EtherSent(to, amount);
    }

    /// @notice Transfer ERC20 tokens from this contract to a recipient (no interface used)
    function sendToken(address token, address to, uint256 amount) external onlyOwner {
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
        (bool success, bytes memory ret) = token.call(payload);

        if (!success) revert("SimpleTreasury: token transfer call failed");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "SimpleTreasury: token transfer returned false");

        emit TokenSent(token, to, amount);
    }

    /// @notice Batch transfer ETH to multiple recipients
    function batchSendEther(address payable[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "SimpleTreasury: length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            require(success, "SimpleTreasury: ETH transfer failed");
            emit EtherSent(recipients[i], amounts[i]);
        }
    }

    /// @notice Batch transfer ERC20 tokens to multiple recipients
    function batchSendToken(address token, address[] calldata recipients, uint256[] calldata amounts) external onlyOwner {
        require(recipients.length == amounts.length, "SimpleTreasury: length mismatch");

        for (uint256 i = 0; i < recipients.length; i++) {
            bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", recipients[i], amounts[i]);
            (bool success, bytes memory ret) = token.call(payload);

            if (!success) revert("SimpleTreasury: token transfer call failed");
            if (ret.length > 0) require(abi.decode(ret, (bool)), "SimpleTreasury: token transfer returned false");

            emit TokenSent(token, recipients[i], amounts[i]);
        }
    }

    /// @notice Transfer contract ownership to another address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SimpleTreasury: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}
