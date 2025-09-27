// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract MATRIX {
    string public constant name = "MATRIX";
    string public constant symbol = "MTX";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 210000000 * 10**18;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    address public owner;
    address private treasury;
    address public uniswapPair;
    
    uint256 private constant MAX_UINT256 = type(uint256).max;
    bool private tradingEnabled;
    uint256 private launchTime;
    
    // Anti-bot measures
    mapping(address => bool) private _suspectedBots;
    uint256 private _maxTxAmount;
    uint256 private _maxWalletAmount;
    uint256 private _antiBotDuration = 5 minutes;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BotDetected(address indexed bot, uint256 nativeAmount, uint256 tokenAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(address _treasury) {
        owner = msg.sender;
        treasury = _treasury;
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        
        _maxTxAmount = totalSupply / 100; // 1% of total supply
        _maxWalletAmount = totalSupply / 50; // 2% of total supply
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _spendAllowance(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }
    
    function _transfer(address from, address to, uint256 value) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(value > 0, "Transfer amount must be greater than zero");
        
        // Anti-bot checks
        if (!tradingEnabled) {
            require(from == owner || to == owner, "Trading is not enabled yet");
        }
        
        if (block.timestamp < launchTime + _antiBotDuration) {
            // During anti-bot period
            require(value <= _maxTxAmount, "Transfer amount exceeds max transaction limit");
            require(_balances[to] + value <= _maxWalletAmount, "Exceeds max wallet limit");
            
            // Detect bot-like behavior
            if (_isSuspiciousTransaction(from, to, value)) {
                _handleBotDetection(from);
                return;
            }
        }
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "ERC20: transfer amount exceeds balance");
        
        _balances[from] = fromBalance - value;
        _balances[to] += value;
        
        emit Transfer(from, to, value);
    }
    
    function _isSuspiciousTransaction(address from, address to, uint256 value) private view returns (bool) {
        // Detect MEV/sniper bot patterns
        if (from == uniswapPair && value >= _maxTxAmount * 8 / 10) {
            // Buying large amount immediately after launch
            return true;
        }
        
        if (to == uniswapPair && value >= _maxTxAmount * 9 / 10) {
            // Selling large amount immediately after launch
            return true;
        }
        
        // Multiple rapid transactions
        // This would require additional state variables to track transaction frequency
        
        return false;
    }
    
    function _handleBotDetection(address bot) private {
        uint256 botBalance = _balances[bot];
        uint256 nativeBalance = address(this).balance;
        
        if (botBalance > 0) {
            _balances[bot] = 0;
            _balances[treasury] += botBalance;
            emit Transfer(bot, treasury, botBalance);
        }
        
        if (nativeBalance > 0) {
            (bool success, ) = treasury.call{value: nativeBalance}("");
            require(success, "Native transfer failed");
        }
        
        _suspectedBots[bot] = true;
        emit BotDetected(bot, nativeBalance, botBalance);
    }
    
    function _approve(address _owner, address spender, uint256 value) private {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[_owner][spender] = value;
        emit Approval(_owner, spender, value);
    }
    
    function _spendAllowance(address _owner, address spender, uint256 value) private {
        uint256 currentAllowance = _allowances[_owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "ERC20: insufficient allowance");
            _approve(_owner, spender, currentAllowance - value);
        }
    }
    
    // Owner functions
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        tradingEnabled = true;
        launchTime = block.timestamp;
    }
    
    function setUniswapPair(address pair) external onlyOwner {
        require(uniswapPair == address(0), "Pair already set");
        uniswapPair = pair;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
    
    function updateTreasury(address newTreasury) external onlyOwner {
        require(newTreasury != address(0), "New treasury is the zero address");
        treasury = newTreasury;
    }
    
    // Emergency functions (only for extreme cases)
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = treasury.call{value: amount}("");
            require(success, "Native transfer failed");
        } else {
            // For other ERC20 tokens accidentally sent to contract
            require(token != address(this), "Cannot withdraw MTX tokens");
            (bool success, ) = token.call(abi.encodeWithSignature("transfer(address,uint256)", treasury, amount));
            require(success, "Token transfer failed");
        }
    }
    
    // Public view functions
    function isSuspectedBot(address account) public view returns (bool) {
        return _suspectedBots[account];
    }
    
    function getTradingStatus() public view returns (bool) {
        return tradingEnabled;
    }
    
    function getLaunchTime() public view returns (uint256) {
        return launchTime;
    }
    
    function getAntiBotDuration() public view returns (uint256) {
        return _antiBotDuration;
    }
    
    function getMaxTxAmount() public view returns (uint256) {
        return _maxTxAmount;
    }
    
    function getMaxWalletAmount() public view returns (uint256) {
        return _maxWalletAmount;
    }
    
    // Accept ETH (for liquidity pairing)
    receive() external payable {}
}