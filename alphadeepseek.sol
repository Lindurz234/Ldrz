// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title Alpha Token (APX)
 * @dev ERC20 Token with fixed supply 21,000,000, anti-bot protection, and minting to treasury
 * no anti-whale, no fee modifer
 */

contract Alpha {
    string public constant name = "Alpha";
    string public constant symbol = "APX";
    uint8 public constant decimals = 18;
    uint256 public constant MAX_SUPPLY = 21000000 * 10**18;
    
    address public immutable treasury;
    address public immutable owner;
    
    uint256 public totalSupply;
    bool public tradingEnabled;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    // Anti-bot protection
    mapping(address => bool) public blacklisted;
    uint256 public launchTime;
    bool public launched;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event TradingEnabled();
    event BlacklistUpdated(address indexed account, bool isBlacklisted);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier tradingCheck(address from, address to) {
        require(tradingEnabled || from == treasury || from == owner, "Trading disabled");
        require(!blacklisted[from] && !blacklisted[to], "Blacklisted");
        _;
    }
    
    /**
     * @dev Constructor - mints total supply ke treasury address
     * @param _treasury Alamat treasury yang akan menerima total supply
     */
    constructor(address _treasury) {
        require(_treasury != address(0), "Treasury zero address");
        
        owner = msg.sender;
        treasury = _treasury;
        
        // Mint total supply to treasury
        _mint(_treasury, MAX_SUPPLY);
    }
    
    /**
     * @dev Mengaktifkan trading dan anti-bot protection
     */
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading already enabled");
        require(!launched, "Already launched");
        
        tradingEnabled = true;
        launched = true;
        launchTime = block.timestamp;
        
        emit TradingEnabled();
    }
    
    /**
     * @dev Menambahkan/menghapus address dari blacklist (hanya owner)
     * @param account Alamat yang akan di-blacklist/unblacklist
     * @param isBlacklisted Status blacklist
     */
    function setBlacklist(address account, bool isBlacklisted) external onlyOwner {
        require(account != address(0), "Zero address");
        require(blacklisted[account] != isBlacklisted, "Status unchanged");
        
        blacklisted[account] = isBlacklisted;
        emit BlacklistUpdated(account, isBlacklisted);
    }
    
    /**
     * @dev Melihat balance dari address tertentu
     * @param account Alamat pemilik token
     */
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
    
    /**
     * @dev Transfer token ke address lain
     * @param to Alamat penerima
     * @param value Jumlah token yang ditransfer
     */
    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }
    
    /**
     * @dev Transfer token dari alamat lain (dengan allowance)
     * @param from Alamat pengirim
     * @param to Alamat penerima
     * @param value Jumlah token yang ditransfer
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        address spender = msg.sender;
        uint256 currentAllowance = _allowances[from][spender];
        
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= value, "Insufficient allowance");
            unchecked {
                _approve(from, spender, currentAllowance - value);
            }
        }
        
        _transfer(from, to, value);
        return true;
    }
    
    /**
     * @dev Set allowance untuk spender
     * @param spender Alamat yang diizinkan menghabiskan token
     * @param value Jumlah allowance
     */
    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }
    
    /**
     * @dev Melihat allowance yang diberikan owner ke spender
     * @param owner Alamat pemilik token
     * @param spender Alamat yang diizinkan menghabiskan token
     */
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    /**
     * @dev Internal function untuk transfer
     */
    function _transfer(address from, address to, uint256 value) internal tradingCheck(from, to) {
        require(from != address(0), "Transfer from zero address");
        require(to != address(0), "Transfer to zero address");
        require(value > 0, "Transfer amount zero");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= value, "Insufficient balance");
        
        unchecked {
            _balances[from] = fromBalance - value;
            _balances[to] += value;
        }
        
        emit Transfer(from, to, value);
    }
    
    /**
     * @dev Internal function untuk mint token
     */
    function _mint(address account, uint256 value) internal {
        require(account != address(0), "Mint to zero address");
        
        totalSupply += value;
        unchecked {
            _balances[account] += value;
        }
        emit Transfer(address(0), account, value);
    }
    
    /**
     * @dev Internal function untuk set allowance
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        
        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }
    
    /**
     * @dev Tidak ada fungsi untuk mengubah fee transfer (sesuai requirement)
     * @dev Tidak ada fungsi mint tambahan (fixed supply)
     * @dev Tidak ada anti-whale limits (sesuai requirement)
     * @dev Tidak ada fungsi untuk mematikan transaksi (sesuai requirement)
     */
}