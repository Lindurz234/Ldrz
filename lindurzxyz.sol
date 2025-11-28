// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract LindurzXYZ is ReentrancyGuard {
    string public constant name = "lindurz";
    string public constant symbol = "xyz";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 234000 * 10**18;
    string public logoURI = "lindurzxyz.png";
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event NativeReceived(address indexed from, uint256 amount);
    event ERC20Received(address indexed from, address indexed token, uint256 amount);
    
    constructor() {
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    // ✅ FUNCTION ERC20
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }
    
    function transfer(address to, uint256 amount) public nonReentrant returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public nonReentrant returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    // ✅ RECEIVE NATIVE ETH
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
    
    fallback() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
    
    // ✅ SEND NATIVE ETH FROM CONTRACT
    function sendNative(address payable to, uint256 amount) public nonReentrant returns (bool) {
        require(address(this).balance >= amount, "Insufficient native balance");
        (bool success, ) = to.call{value: amount}("");
        require(success, "Native transfer failed");
        return true;
    }
        
        IERC20(token).transferFrom(address(this), to, amount);
        return true;
    }
    
    
    function getNativeBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    function getERC20Balance(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    // ✅ INTERNAL FUNCTIONS
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from zero address");
        require(to != address(0), "ERC20: transfer to zero address");
        require(_balances[from] >= amount, "ERC20: insufficient balance");
        
        unchecked {
            _balances[from] -= amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
    
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from zero address");
        require(spender != address(0), "ERC20: approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    
    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}