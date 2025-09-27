// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Alpha Token (APX)
 * @dev ERC20 Token with max supply of 21,000,000, 18 decimals
 * Anti-bot/MEV protection that transfers tokens from bot addresses to owner
 * No minting, no blacklist, no anti-whale, fixed transaction fees, no trading enable/disable
 * Initial supply minted to treasury contract address
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract AlphaToken is IERC20 {
    string public constant name = "Alpha";
    string public constant symbol = "APX";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 21_000_000 * 10**18;
    
    address public owner;
    address public immutable treasury;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Anti-bot/MEV protection
    uint256 public constant MAX_HOLD_PERCENT = 5; // Maximum 5% of supply per address
    uint256 public constant ANTI_BOT_FEE = 99; // 99% fee for bot transactions
    uint256 public constant NORMAL_FEE = 2; // 2% normal transaction fee
    uint256 public constant FEE_DENOMINATOR = 100;
    
    uint256 public immutable launchTime;
    uint256 public constant LAUNCH_COOLDOWN = 5 minutes; // 5 minutes cooldown after launch
    
    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BotDetected(address indexed botAddress, uint256 amountTransferredToOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address treasuryAddress) {
        require(treasuryAddress != address(0), "Treasury cannot be zero address");
        
        owner = msg.sender;
        treasury = treasuryAddress;
        launchTime = block.timestamp;
        
        // Mint total supply to treasury
        _balances[treasuryAddress] = totalSupply;
        emit Transfer(address(0), treasuryAddress, totalSupply);
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function allowance(address accountOwner, address spender) public view override returns (uint256) {
        return _allowances[accountOwner][spender];
    }
    
    function approve(address spender, uint256 value) public override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "Decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(value > 0, "Transfer amount must be greater than zero");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Insufficient balance");
        
        uint256 feeAmount;
        address feeRecipient = owner;
        
        // Anti-bot/MEV protection logic
        if (_isBotTransaction(from, to, value)) {
            feeAmount = (value * ANTI_BOT_FEE) / FEE_DENOMINATOR;
            emit BotDetected(from, feeAmount);
        } else {
            feeAmount = (value * NORMAL_FEE) / FEE_DENOMINATOR;
        }
        
        uint256 transferAmount = value - feeAmount;
        
        // Update balances
        _balances[from] = fromBalance - value;
        _balances[to] += transferAmount;
        
        // Take fee
        if (feeAmount > 0) {
            _balances[feeRecipient] += feeAmount;
            emit Transfer(from, feeRecipient, feeAmount);
        }
        
        emit Transfer(from, to, transferAmount);
    }
    
    function _isBotTransaction(address from, address to, uint256 value) internal view returns (bool) {
        // During launch cooldown, any large transaction is considered bot
        if (block.timestamp < launchTime + LAUNCH_COOLDOWN) {
            // Allow normal-sized transactions during cooldown
            if (value <= (totalSupply * 1) / FEE_DENOMINATOR) { // 1% of supply
                return false;
            }
            // Large transactions during cooldown are considered bots
            return true;
        }
        
        // Check for large purchases that could be front-running bots
        if (value > (totalSupply * MAX_HOLD_PERCENT) / FEE_DENOMINATOR) {
            return true;
        }
        
        return false;
    }
    
    function _approve(address accountOwner, address spender, uint256 value) internal {
        require(accountOwner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        
        _allowances[accountOwner][spender] = value;
        emit Approval(accountOwner, spender, value);
    }
    
    function _spendAllowance(address accountOwner, address spender, uint256 value) internal {
        uint256 currentAllowance = allowance(accountOwner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Insufficient allowance");
            _approve(accountOwner, spender, currentAllowance - value);
        }
    }
    
    // Owner functions
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    // No mint function - supply is fixed at deployment
    // No blacklist function
    // No fee change function - fees are fixed
    // No anti-whale limits beyond the bot detection
    // No trading enable/disable function - trading is always enabled
}