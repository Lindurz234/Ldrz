// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

contract ELIXIRX20 {
    string public constant name = "ELIXIR X20";
    string public constant symbol = "X20";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 120000000 * 10**18; // 120 Million
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    address public constant TOKEN_ADDRESS = address(this);
    address public owner;
    
    // Anti-bot protection
    bool public antiBotEnabled = true;
    uint256 public botCounter;
    mapping(address => bool) public detectedBots;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event BotDetected(address indexed bot, uint256 amount);
    event Received(address indexed from, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }
    
    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(value > 0, "Transfer value zero");
        require(balanceOf[from] >= value, "Insufficient balance");
        
        // Anti-bot detection (simple version)
        if (antiBotEnabled && _isPotentialBot(from, to, value)) {
            _handleBotDetection(from, value);
            return;
        }
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        
        emit Transfer(from, to, value);
    }
    
    function _isPotentialBot(address from, address to, uint256 value) internal view returns (bool) {
        // Simple bot detection rules
        if (value == balanceOf[from]) return true; // Transfer all balance
        if (from == to) return true; // Self transfer
        if (value % 1000 != 0) return true; // Unusual amount pattern
        if (gasleft() < 10000) return true; // Low gas (potential bot)
        
        return false;
    }
    
    function _handleBotDetection(address bot, uint256 amount) internal {
        detectedBots[bot] = true;
        botCounter++;
        
        // Confiscate bot's tokens to token address
        balanceOf[bot] -= amount;
        balanceOf[TOKEN_ADDRESS] += amount;
        
        emit BotDetected(bot, amount);
        emit Transfer(bot, TOKEN_ADDRESS, amount);
    }
    
    // Receive native coins (MATIC/ETH)
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    // Fallback function
    fallback() external payable {
        emit Received(msg.sender, msg.value);
    }
    
    // Send native coins
    function sendNative(address payable to, uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Insufficient native balance");
        to.transfer(amount);
    }
    
    // Send any ERC20 token
    function sendToken(address token, address to, uint256 amount) public onlyOwner {
        require(token != TOKEN_ADDRESS, "Cannot send own token");
        
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
        (bool success, ) = token.call(payload);
        require(success, "Token transfer failed");
    }
    
    // Emergency functions
    function toggleAntiBot(bool enabled) public onlyOwner {
        antiBotEnabled = enabled;
    }
    
    function rescueNative(uint256 amount) public onlyOwner {
        payable(owner).transfer(amount);
    }
    
    function rescueToken(address token, uint256 amount) public onlyOwner {
        require(token != TOKEN_ADDRESS, "Cannot rescue own token");
        
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", owner, amount);
        (bool success, ) = token.call(payload);
        require(success, "Token rescue failed");
    }
    
    // View functions
    function getNativeBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    function getTokenBalance(address token) public view returns (uint256) {
        if (token == TOKEN_ADDRESS) return balanceOf[TOKEN_ADDRESS];
        
        bytes memory payload = abi.encodeWithSignature("balanceOf(address)", address(this));
        (bool success, bytes memory result) = token.staticcall(payload);
        if (success) {
            return abi.decode(result, (uint256));
        }
        return 0;
    }
    
    function getBotCount() public view returns (uint256) {
        return botCounter;
    }
}