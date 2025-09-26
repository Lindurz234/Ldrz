// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title TokenVault - penyimpanan aman untuk ERC20 token & ETH
/// @author ChatGPT
/// @notice Vault sederhana: terima token/ETH, dan owner dapat mengirim kembali.
/// @dev Tidak ada mekanisme mint/burn; tidak ada blacklist, fee, atau modifikasi fee.
contract TokenVault {
    // ---------- Interfaces & helpers ----------
    /// @dev Minimal ERC20 interface
    interface IERC20 {
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
        function allowance(address owner, address spender) external view returns (uint256);
    }

    /// @dev SafeERC20-like helpers (minimal, in-contract) — ensures calls succeeded even if token doesn't return bool
    function _safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TokenVault: transfer failed");
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
            address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), "TokenVault: transferFrom failed");
    }

    // ---------- State ----------
    address public owner;

    // Reentrancy guard
    uint256 private _status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // Events
    event DepositedERC20(address indexed token, address indexed from, uint256 amount);
    event WithdrawnERC20(address indexed token, address indexed to, uint256 amount);
    event DepositedETH(address indexed from, uint256 amount);
    event WithdrawnETH(address indexed to, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ---------- Modifiers ----------
    modifier onlyOwner() {
        require(msg.sender == owner, "TokenVault: caller is not owner");
        _;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "TokenVault: reentrant");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    // ---------- Constructor ----------
    constructor(address initialOwner) {
        require(initialOwner != address(0), "TokenVault: zero owner");
        owner = initialOwner;
        _status = _NOT_ENTERED;
        emit OwnershipTransferred(address(0), initialOwner);
    }

    // ---------- Ownership management ----------
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "TokenVault: new owner is zero");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function renounceOwnership() external onlyOwner {
        address prev = owner;
        owner = address(0);
        emit OwnershipTransferred(prev, address(0));
    }

    // ---------- Deposit functions ----------
    /// @notice Deposit ERC20 token into the vault. Caller must `approve` this contract beforehand.
    /// @param tokenAddress address of ERC20 token
    /// @param amount amount to deposit
    function depositERC20(address tokenAddress, uint256 amount) external nonReentrant {
        require(tokenAddress != address(0), "TokenVault: token zero");
        require(amount > 0, "TokenVault: amount zero");

        IERC20 token = IERC20(tokenAddress);
        // transferFrom caller -> this
        _safeTransferFrom(token, msg.sender, address(this), amount);

        emit DepositedERC20(tokenAddress, msg.sender, amount);
    }

    /// @notice Fallback to accept ETH deposits. Emits event.
    receive() external payable {
        require(msg.value > 0, "TokenVault: zero eth");
        emit DepositedETH(msg.sender, msg.value);
    }

    // ---------- Withdraw functions (owner only) ----------
    /// @notice Withdraw ERC20 tokens from the vault to a target address. Only owner.
    /// @param tokenAddress address of ERC20 token
    /// @param to recipient address
    /// @param amount amount to send
    function withdrawERC20(address tokenAddress, address to, uint256 amount) external onlyOwner nonReentrant {
        require(tokenAddress != address(0), "TokenVault: token zero");
        require(to != address(0), "TokenVault: to zero");
        require(amount > 0, "TokenVault: amount zero");

        IERC20 token = IERC20(tokenAddress);
        uint256 bal = token.balanceOf(address(this));
        require(bal >= amount, "TokenVault: insufficient token balance");

        _safeTransfer(token, to, amount);

        emit WithdrawnERC20(tokenAddress, to, amount);
    }

    /// @notice Withdraw ETH from the vault to a target address. Only owner.
    /// @param to recipient
    /// @param amount wei amount
    function withdrawETH(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(to != address(0), "TokenVault: to zero");
        require(amount > 0, "TokenVault: amount zero");
        require(address(this).balance >= amount, "TokenVault: insufficient eth balance");

        // Use call for sending ETH and check success
        (bool success, ) = to.call{value: amount}("");
        require(success, "TokenVault: ETH transfer failed");

        emit WithdrawnETH(to, amount);
    }

    // ---------- View helpers ----------
    /// @notice Returns ERC20 balance of this vault for given token.
    function balanceOfERC20(address tokenAddress) external view returns (uint256) {
        if (tokenAddress == address(0)) return 0;
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    /// @notice Returns ETH balance of this vault.
    function balanceOfETH() external view returns (uint256) {
        return address(this).balance;
    }

    // ---------- Rescue / emergency helpers ----------
    /// @notice Rescue ERC20 tokens accidentally sent to this contract (alias to withdrawERC20). Only owner.
    function rescueERC20(address tokenAddress, address to, uint256 amount) external onlyOwner {
        withdrawERC20(tokenAddress, to, amount);
    }

    /// @notice Emergency withdraw all ETH to owner (onlyOwner)
    function emergencyWithdrawAllETH() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        require(bal > 0, "TokenVault: no eth");
        (bool success, ) = payable(owner).call{value: bal}("");
        require(success, "TokenVault: emergency eth transfer failed");
        emit WithdrawnETH(owner, bal);
    }
}
