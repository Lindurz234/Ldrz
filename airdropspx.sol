// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Impor pustaka OpenZeppelin untuk keamanan dan manajemen kepemilikan
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AirdropContract
 * @dev contract for distribution airdrop
 */
contract AirdropContract is ReentrancyGuard, Ownable {
    // Alamat token airdrop yang akan didistribusikan
    address public constant AIRDROP_TOKEN = 0x7C3A20bA246979fCea2eF964fC1eb3ACCe9Ca0bc ;
    
    // Konstanta untuk jumlah airdrop dan biaya
    uint256 public constant AIRDROP_AMOUNT = 100 * 10**18; // 100 token dengan 18 desimal
    uint256 public constant NATIVE_TOKEN_FEE = 5 * 10**18; // 5 native token
    
    // Mapping untuk melacak alamat yang sudah mengklaim
    mapping(address => bool) public hasClaimed;
    
    // Event untuk mencatat aktivitas penting
    event AirdropClaimed(address indexed claimant, uint256 tokenAmount, uint256 nativeFee);
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event NativeTokensWithdrawn(address indexed owner, uint256 amount);
    event TokensReceived(address indexed from, uint256 amount);
    event NativeReceived(address indexed from, uint256 amount);

    /**
     * @dev Constructor, mengatur pemilik kontrak
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Fungsi untuk mengklaim airdrop
     * Memerlukan pembayaran 5 native token sebagai biaya
     */
    function claimAirdrop() external payable nonReentrant {
        require(!hasClaimed[msg.sender], "Airdrop sudah diklaim");
        require(msg.value == NATIVE_TOKEN_FEE, "Jumlah native token tidak tepat");
        
        // Buat instance token ERC-20
        IERC20 airdropToken = IERC20(AIRDROP_TOKEN);
        uint256 contractBalance = airdropToken.balanceOf(address(this));
        require(contractBalance >= AIRDROP_AMOUNT, "Saldo token airdrop tidak mencukupi");
        
        // Tandai sudah diklaim
        hasClaimed[msg.sender] = true;
        
        // Transfer token airdrop ke pemanggil
        bool success = airdropToken.transfer(msg.sender, AIRDROP_AMOUNT);
        require(success, "Transfer token airdrop gagal");
        
        emit AirdropClaimed(msg.sender, AIRDROP_AMOUNT, NATIVE_TOKEN_FEE);
    }

    /**
     * @dev Fungsi untuk menarik token ERC-20 dari kontrak (hanya owner)
     * @param tokenAddress Alamat token yang akan ditarik
     * @param amount Jumlah token yang akan ditarik
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
     * @dev Fungsi untuk menarik native token dari kontrak (hanya owner)
     * @param amount Jumlah native token yang akan ditarik
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
     * @param recipient Alamat penerima
     * @param amount Jumlah native token yang akan dikirim
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
     * @param tokenAddress Alamat token yang akan dikirim
     * @param recipient Alamat penerima
     * @param amount Jumlah token yang akan dikirim
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
     * @dev Fungsi view untuk memeriksa apakah alamat dapat mengklaim airdrop
     * @param user Alamat yang ingin diperiksa
     * @return Boolean yang menunjukkan apakah dapat mengklaim
     */
    function canClaim(address user) external view returns (bool) {
        if (hasClaimed[user]) {
            return false;
        }
        
        IERC20 airdropToken = IERC20(AIRDROP_TOKEN);
        uint256 contractBalance = airdropToken.balanceOf(address(this));
        
        return contractBalance >= AIRDROP_AMOUNT;
    }

    /**
     * @dev Fungsi view untuk mendapatkan saldo token airdrop kontrak
     * @return Saldo token airdrop
     */
    function getContractTokenBalance() external view returns (uint256) {
        IERC20 airdropToken = IERC20(AIRDROP_TOKEN);
        return airdropToken.balanceOf(address(this));
    }

    /**
     * @dev Fungsi view untuk mendapatkan saldo native token kontrak
     * @return Saldo native token
     */
    function getContractNativeBalance() external view returns (uint256) {
        return address(this).balance;
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