// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title CHAOS Token - CHO
 * @dev Token ERC-20 yang canggih dengan fitur multi-chain, burn mechanism, dan security features
 * Total Supply: 12,000,000 CHO
 * Decimals: 18
 * Versi: Solidity 0.8.30
 */
contract ChaosToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;
    
    // Roles
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    
    // Token Configuration
    uint256 public constant MAX_SUPPLY = 12_000_000 * 10**18; // 12 juta dengan 18 desimal
    string public logoURL;
    
    // Tax and Fee Mechanism (Opsional - bisa diaktifkan)
    uint256 public burnFeePercentage = 1; // 1% default burn fee
    uint256 public liquidityFeePercentage = 1; // 1% default liquidity fee
    bool public feesEnabled = false;
    
    // Multi-chain support mappings
    mapping(string => uint256) public chainSupplies; // Track supply per chain
    mapping(address => bool) public isBridge;
    
    // Events
    event FeesUpdated(uint256 burnFee, uint256 liquidityFee, bool enabled);
    event TokensBridged(address indexed from, string toChain, uint256 amount);
    event LogoURLUpdated(string newLogoURL);
    event CrossChainTransfer(address indexed from, address indexed to, uint256 amount, string chain);

    /**
     * @dev Constructor untuk deploy token CHAOS
     * @param _logoURL URL untuk logo token
     * @param adminAddress Alamat admin yang akan mendapatkan semua role
     * @param initialHolder Alamat yang akan menerima supply awal
     */
    constructor(
        string memory _logoURL,
        address adminAddress,
        address initialHolder
    ) ERC20("CHAOS", "CHO") {
        require(adminAddress != address(0), "Admin address cannot be zero");
        require(initialHolder != address(0), "Initial holder cannot be zero");
        
        logoURL = _logoURL;
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _grantRole(PAUSER_ROLE, adminAddress);
        _grantRole(MINTER_ROLE, adminAddress);
        _grantRole(BRIDGE_ROLE, adminAddress);
        
        // Mint total supply ke initial holder
        _mint(initialHolder, MAX_SUPPLY);
        chainSupplies["main"] = MAX_SUPPLY; // Track supply di chain utama
    }

    /**
     * @dev Override decimals function
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @dev Update logo URL (hanya admin)
     */
    function updateLogoURL(string memory _newLogoURL) external onlyRole(DEFAULT_ADMIN_ROLE) {
        logoURL = _newLogoURL;
        emit LogoURLUpdated(_newLogoURL);
    }

    /**
     * @dev Pause semua transfers (untuk emergency)
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause transfers
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Configure fee mechanism (hanya admin)
     */
    function configureFees(
        uint256 _burnFee, 
        uint256 _liquidityFee, 
        bool _enabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_burnFee.add(_liquidityFee) <= 10, "Total fees cannot exceed 10%");
        
        burnFeePercentage = _burnFee;
        liquidityFeePercentage = _liquidityFee;
        feesEnabled = _enabled;
        
        emit FeesUpdated(_burnFee, _liquidityFee, _enabled);
    }

    /**
     * @dev Internal function untuk handle fees saat transfer
     */
    function _calculateFees(uint256 amount) internal view returns (
        uint256 transferAmount, 
        uint256 burnAmount, 
        uint256 liquidityAmount
    ) {
        if (!feesEnabled) {
            return (amount, 0, 0);
        }
        
        burnAmount = amount.mul(burnFeePercentage).div(100);
        liquidityAmount = amount.mul(liquidityFeePercentage).div(100);
        transferAmount = amount.sub(burnAmount).sub(liquidityAmount);
        
        return (transferAmount, burnAmount, liquidityAmount);
    }

    /**
     * @dev Override transfer function dengan fee mechanism
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        if (from == address(0) || feesEnabled == false) {
            // Minting atau fees disabled, transfer normal
            super._update(from, to, amount);
            return;
        }

        (uint256 transferAmount, uint256 burnAmount, uint256 liquidityAmount) = _calculateFees(amount);
        
        // Burn tokens
        if (burnAmount > 0) {
            super._update(from, address(0), burnAmount); // Burn ke address(0)
        }
        
        // Transfer ke liquidity pool (atau fee collector)
        if (liquidityAmount > 0) {
            address liquidityPool = 0x000000000000000000000000000000000000dEaD; // Ganti dengan LP address
            super._update(from, liquidityPool, liquidityAmount);
        }
        
        // Transfer amount utama
        super._update(from, to, transferAmount);
    }

    /**
     * @dev Function untuk bridge ke chain lain (hanya bridge contract)
     */
    function bridgeToChain(
        address from, 
        uint256 amount, 
        string memory targetChain
    ) external onlyRole(BRIDGE_ROLE) nonReentrant returns (bool) {
        require(bytes(targetChain).length > 0, "Target chain cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(from) >= amount, "Insufficient balance");
        
        // Burn tokens dari chain asal
        _burn(from, amount);
        chainSupplies[targetChain] = chainSupplies[targetChain].add(amount);
        
        emit TokensBridged(from, targetChain, amount);
        return true;
    }

    /**
     * @dev Function untuk mint tokens dari bridge (hanya bridge contract)
     */
    function mintFromBridge(
        address to, 
        uint256 amount, 
        string memory sourceChain
    ) external onlyRole(BRIDGE_ROLE) nonReentrant returns (bool) {
        require(bytes(sourceChain).length > 0, "Source chain cannot be empty");
        require(amount > 0, "Amount must be greater than 0");
        require(chainSupplies[sourceChain] >= amount, "Insufficient supply on source chain");
        
        chainSupplies[sourceChain] = chainSupplies[sourceChain].sub(amount);
        _mint(to, amount);
        
        emit CrossChainTransfer(address(0), to, amount, sourceChain);
        return true;
    }

    /**
     * @dev Add bridge contract address (hanya admin)
     */
    function addBridge(address bridgeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bridgeAddress != address(0), "Bridge address cannot be zero");
        isBridge[bridgeAddress] = true;
        _grantRole(BRIDGE_ROLE, bridgeAddress);
    }

    /**
     * @dev Remove bridge contract address (hanya admin)
     */
    function removeBridge(address bridgeAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isBridge[bridgeAddress] = false;
        _revokeRole(BRIDGE_ROLE, bridgeAddress);
    }

    /**
     * @dev Emergency withdraw tokens yang stuck (hanya admin)
     */
    function emergencyWithdraw(
        address tokenAddress, 
        address to, 
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        require(to != address(0), "Cannot withdraw to zero address");
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(to, amount), "Transfer failed");
    }

    /**
     * @dev Get total burned tokens
     */
    function totalBurned() public view returns (uint256) {
        return balanceOf(address(0));
    }

    /**
     * @dev Get current circulating supply
     */
    function circulatingSupply() public view returns (uint256) {
        return totalSupply().sub(balanceOf(address(0)));
    }

    // Override required oleh compiler
    function _beforeTokenTransfer(
        address from, 
        address to, 
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}