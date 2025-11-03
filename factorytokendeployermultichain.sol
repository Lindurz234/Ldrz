// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./SimpleTokenv2.sol";

/**
 * @title UniversalTokenFactory
 * @dev Factory untuk membuat token ERC20 dengan fee flexible.
 * Tanpa constructor parameters - fee default 0 dan disabled.
 */
contract UniversalTokenFactory is Ownable, ReentrancyGuard {
    uint256 public createFee;
    bool public isFeeEnabled;
    
    address[] public allTokens;
    mapping(address => address[]) public userTokens;

    event TokenCreated(
        address indexed user,
        address tokenAddress,
        string name,
        string symbol,
        uint8 decimals,
        uint256 initialSupply
    );

    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeToggled(bool enabled);
    event FeesWithdrawn(address indexed owner, uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    /**
     * @dev Constructor sederhana - set msg.sender sebagai owner
     */
    constructor() Ownable(msg.sender) {
        // Fee default 0 dan disabled
        createFee = 0;
        isFeeEnabled = false;
    }

    /**
     * @dev Membuat token baru dengan fee flexible
     */
    function createToken(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 initialSupply
    ) external payable nonReentrant returns (address) {
        // Check fee jika enabled
        if (isFeeEnabled) {
            require(msg.value == createFee, "Incorrect fee amount");
        } else {
            // Jika fee disabled, refund any ETH sent
            if (msg.value > 0) {
                payable(msg.sender).transfer(msg.value);
            }
        }
        
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(initialSupply > 0, "Initial supply must be greater than 0");
        require(decimals <= 18, "Decimals cannot exceed 18");

        // Deploy kontrak token - langsung set user sebagai owner
        SimpleTokenv2 newToken = new SimpleTokenv2(
            msg.sender,  // USER jadi owner
            name,
            symbol, 
            decimals,
            initialSupply
        );

        address tokenAddress = address(newToken);
        allTokens.push(tokenAddress);
        userTokens[msg.sender].push(tokenAddress);

        emit TokenCreated(
            msg.sender,
            tokenAddress,
            name,
            symbol,
            decimals,
            initialSupply
        );

        return tokenAddress;
    }

    // ==== Management Functions ====

    function updateFee(uint256 newFee) external onlyOwner {
        uint256 oldFee = createFee;
        createFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function toggleFee(bool enable) external onlyOwner {
        isFeeEnabled = enable;
        emit FeeToggled(enable);
    }

    function withdrawFees() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        payable(owner()).transfer(balance);
        emit FeesWithdrawn(owner(), balance);
    }

    function withdrawERC20(address tokenAddress) external onlyOwner nonReentrant {
        require(tokenAddress != address(0), "Invalid token address");
        uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        IERC20(tokenAddress).transfer(owner(), balance);
        emit EmergencyWithdraw(tokenAddress, balance);
    }

    function getFeeInfo() external view returns (uint256 fee, bool enabled) {
        return (createFee, isFeeEnabled);
    }

    function getTotalTokens() external view returns (uint256) {
        return allTokens.length;
    }

    function getUserTokens(address user) external view returns (address[] memory) {
        return userTokens[user];
    }

    receive() external payable {}
}