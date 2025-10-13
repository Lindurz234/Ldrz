// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title CozySwap Treasury
/// @notice Treasury receive eth erc20
contract CozySwapTreasury {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event EtherReceived(address indexed from, uint256 amount);
    event EtherSent(address indexed to, uint256 amount);
    event TokenSent(address indexed token, address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "SimpleTreasury: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    /// @notice Terima ETH langsung ke kontrak
    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }

    /// @notice Fallback payable (jika panggilan tidak cocok)
    fallback() external payable {
        if (msg.value > 0) {
            emit EtherReceived(msg.sender, msg.value);
        }
    }

    /// @notice Transfer ETH dari kontrak ke alamat tujuan
    /// @param to alamat penerima
    /// @param amount jumlah wei yang dikirim
    function sendEther(address payable to, uint256 amount) external onlyOwner {
        // lakukan call untuk transfer ETH; cek keberhasilan
        (bool success, ) = to.call{value: amount}("");
        require(success, "SimpleTreasury: ETH transfer failed");
        emit EtherSent(to, amount);
    }

    /// @notice Kirim token ERC20 dari kontrak ke alamat tujuan (tanpa interface)
    /// @dev Memanggil fungsi `transfer(address,uint256)` pada kontrak token via low-level call.
    /// @param token alamat kontrak token ERC20
    /// @param to alamat penerima token
    /// @param amount jumlah token (sesuai decimals token)
    function sendToken(address token, address to, uint256 amount) external onlyOwner {
        // ABI-encode signature "transfer(address,uint256)"
        bytes memory payload = abi.encodeWithSignature("transfer(address,uint256)", to, amount);

        (bool success, bytes memory ret) = token.call(payload);

        // Beberapa token mengembalikan boolean, beberapa tidak mengembalikan apa-apa.
        // Anggap sukses hanya jika call berhasil dan (tidak ada return data OR return data adalah true)
        if (!success) {
            revert("SimpleTreasury: token transfer call failed");
        }
        if (ret.length > 0) {
            // jika ada return data, decode sebagai bool dan pastikan true
            require(abi.decode(ret, (bool)), "SimpleTreasury: token transfer returned false");
        }

        emit TokenSent(token, to, amount);
    }

    /// @notice Transfer kepemilikan kontrak ke alamat lain
    /// @param newOwner alamat pemilik baru
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "SimpleTreasury: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}