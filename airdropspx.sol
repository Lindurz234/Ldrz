// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AirdropContract is ReentrancyGuard, Ownable {
    IERC20 public airdropToken;
    uint256 public constant TOKENS_PER_CLAIM = 100 * 10**18; // 100 token dengan 18 desimal
    uint256 public constant NATIVE_TOKEN_FEE = 5 * 10**18; // 5 native token
    
    // Event untuk mencatat aktivitas
    event AirdropClaimed(address indexed claimant, uint256 tokenAmount, uint256 nativeFee, uint256 timestamp);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event NativeTokensWithdrawn(address indexed owner, uint256 amount);
    event TokensReceived(address indexed from, uint256 amount);
    event NativeReceived(address indexed from, uint256 amount);

    // Constructor untuk mengatur token airdrop
    constructor(address _airdropToken) Ownable(msg.sender) {
        require(_airdropToken != address(0), "Alamat token tidak valid");
        airdropToken = IERC20(_airdropToken);
    }
    
    /**
     * @dev Fungsi utama untuk claim airdrop
     * User bisa claim berulang kali asal membayar fee 5 native token
     */
    function claimAirdrop() external payable nonReentrant {
        require(msg.value == NATIVE_TOKEN_FEE, "Jumlah native token tidak tepat");
        require(airdropToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM, "Saldo token airdrop tidak mencukupi");
        
        // Transfer token airdrop ke pemanggil
        bool success = airdropToken.transfer(msg.sender, TOKENS_PER_CLAIM);
        require(success, "Transfer token airdrop gagal");
        
        emit AirdropClaimed(msg.sender, TOKENS_PER_CLAIM, NATIVE_TOKEN_FEE, block.timestamp);
    }
    
    /**
     * @dev Fungsi untuk withdraw token ERC-20 dari kontrak (hanya owner)
     */
    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        require(amount > 0, "Jumlah penarikan harus lebih dari 0");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= amount, "Saldo token tidak mencukupi");
        
        bool success = token.transfer(owner(), amount);
        require(success, "Penarikan token gagal");
        
        emit TokensWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Fungsi untuk withdraw native token dari kontrak (hanya owner)
     */
    function withdrawNativeTokens(uint256 amount) external onlyOwner {
        require(amount > 0, "Jumlah penarikan harus lebih dari 0");
        require(address(this).balance >= amount, "Saldo native token tidak mencukupi");
        
        (bool sent, ) = owner().call{value: amount}("");
        require(sent, "Penarikan native token gagal");
        
        emit NativeTokensWithdrawn(owner(), amount);
    }
    
    /**
     * @dev Fungsi untuk mengirim native token ke alamat lain (hanya owner)
     */
    function sendNativeToken(address payable recipient, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Jumlah pengiriman harus lebih dari 0");
        require(address(this).balance >= amount, "Saldo native token tidak mencukupi");
        require(recipient != address(0), "Alamat penerima tidak valid");
        
        (bool sent, ) = recipient.call{value: amount}("");
        require(sent, "Pengiriman native token gagal");
    }
    
    /**
     * @dev Fungsi untuk mengirim token ERC-20 ke alamat lain (hanya owner)
     */
    function sendERC20Token(address tokenAddress, address recipient, uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Jumlah pengiriman harus lebih dari 0");
        require(tokenAddress != address(0), "Alamat token tidak valid");
        require(recipient != address(0), "Alamat penerima tidak valid");
        
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(recipient, amount);
        require(success, "Pengiriman token ERC-20 gagal");
    }
    
    /**
     * @dev Fungsi view untuk memeriksa saldo token airdrop kontrak
     */
    function getContractTokenBalance() external view returns (uint256) {
        return airdropToken.balanceOf(address(this));
    }
    
    /**
     * @dev Fungsi view untuk memeriksa saldo native token kontrak
     */
    function getContractNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Fungsi view untuk memeriksa apakah kontrak memiliki cukup token untuk claim
     */
    function canClaim() external view returns (bool) {
        return airdropToken.balanceOf(address(this)) >= TOKENS_PER_CLAIM;
    }
    
    /**
     * @dev Fungsi untuk menerima native token
     */
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
    
    /**
     * @dev Fallback function untuk menerima native token
     */
    fallback() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
}