// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title SimpleTreasury - treasury minimal untuk menyimpan & mengirim ERC-20
/// @author -
contract SimpleTreasury {
    // ----- Events -----
    event DepositedERC20(address indexed token, address indexed from, uint256 amount);
    event WithdrawnERC20(address indexed token, address indexed to, uint256 amount);
    event DepositedETH(address indexed from, uint256 amount);
    event WithdrawnETH(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ----- Owner -----
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    /// @notice pindah kepemilikan
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // ----- Minimal ERC20 interface -----
    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function allowance(address owner_, address spender) external view returns (uint256);
        function approve(address spender, uint256 amount) external returns (bool);
        function transfer(address to, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }

    // ----- Safe wrappers for tokens (handles non-standard ERC20 that don't return bool) -----
    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        // try standard call first
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transferFrom failed");
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "transfer failed");
    }

    // ----- Deposit ERC20 -----
    /// @notice deposit token ke treasury (caller harus approve kontrak sebelumnya)
    /// @param token alamat token ERC20
    /// @param amount jumlah yang ingin dipindahkan
    function depositERC20(address token, uint256 amount) external {
        require(amount > 0, "amount=0");
        _safeTransferFrom(token, msg.sender, address(this), amount);
        emit DepositedERC20(token, msg.sender, amount);
    }

    /// @notice cek saldo token pada treasury
    function tokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    // ----- Withdraw ERC20 (owner only) -----
    /// @notice tarikan token dari treasury ke alamat tujuan (hanya owner)
    /// @param token alamat token ERC20
    /// @param to alamat penerima
    /// @param amount jumlah token
    function withdrawERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero address");
        require(amount > 0, "amount=0");
        _safeTransfer(token, to, amount);
        emit WithdrawnERC20(token, to, amount);
    }

    // ----- ETH handling (opsional) -----
    receive() external payable {
        if (msg.value > 0) {
            emit DepositedETH(msg.sender, msg.value);
        }
    }

    /// @notice tarik ETH (hanya owner)
    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero address");
        require(amount <= address(this).balance, "insufficient ETH");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit WithdrawnETH(to, amount);
    }

    /// @notice lihat saldo ETH kontrak
    function ethBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ----- Emergency: allow owner to call arbitrary low-level (use carefully) -----
    /// @notice Eksekusi panggilan arbitrary dari owner. Berguna untuk interoperabilitas DEX / contract lain.
    /// Hati-hati: memberi fleksibilitas tetapi berisiko bila owner diretas.
    function ownerCall(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        require(target != address(0), "zero address");
        (bool ok, bytes memory ret) = target.call{value: value}(data);
        require(ok, "call failed");
        return ret;
    }
}
