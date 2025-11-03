// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SimpleTokenv2 - Full Ownership Support
 * @dev Token ERC20 dengan fungsi ownership lengkap
 */
contract SimpleTokenv2 is ERC20, Ownable {
    uint8 private _decimals;
    
    event TokenDeployed(
        address indexed owner,
        string name,
        string symbol, 
        uint8 decimals,
        uint256 initialSupply
    );

    /**
     * @dev Constructor langsung set owner ke user
     */
    constructor(
        address owner_,
        string memory name_,
        string memory symbol_, 
        uint8 decimals_,
        uint256 initialSupply_
    ) ERC20(name_, symbol_) Ownable(owner_) {
        require(owner_ != address(0), "Owner cannot be zero address");
        require(bytes(name_).length > 0, "Name cannot be empty");
        require(bytes(symbol_).length > 0, "Symbol cannot be empty");
        require(initialSupply_ > 0, "Initial supply must be greater than 0");
        require(decimals_ <= 18, "Decimals cannot exceed 18");
        
        _decimals = decimals_;
        
        // Mint initial supply ke owner (user)
        _mint(owner_, initialSupply_);

        emit TokenDeployed(owner_, name_, symbol_, decimals_, initialSupply_);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Mint additional tokens (hanya owner)
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Burn tokens
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
    
    /**
     * @dev Transfer ownership - INHERITED dari Ownable
     * function transferOwnership(address newOwner) external onlyOwner
     */
    
    /**
     * @dev Renounce ownership - INHERITED dari Ownable  
     * function renounceOwnership() external onlyOwner
     */
}