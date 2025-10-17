// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CozyTokenPresale
 * @notice Presale COZY Token on Plasma chain 9745.
 */
contract CozyTokenPresale is Ownable, ReentrancyGuard {
    IERC20 public immutable cozyToken = IERC20(0x06E2Ef46662834F4E42dBf9fF9222B077C57dF5C);

    uint256 public constant MAX_SUPPLY = 120_000_000 * 10**18;
    uint256 public constant PRESALE_PERCENTAGE = 20;
    uint256 public constant PRESALE_TOKENS = (MAX_SUPPLY * PRESALE_PERCENTAGE) / 100;

    uint256 public constant TOKENS_PER_XPL = 1000 * 10**18; // 1 XPL = 1000 COZY
    uint256 public constant MIN_BUY = 1 ether; // Min 1 XPL
    uint256 public constant MAX_BUY = 1000 ether; // Max 1000 XPL
    uint256 public constant PRESALE_DURATION = 90 days;

    uint256 public startTime;
    uint256 public endTime;
    bool public presaleActive;
    bool public presaleFinalized;
    bool public refundEnabled;

    uint256 public totalRaised;
    uint256 public totalSold;

    struct Investor {
        uint256 invested;
        uint256 tokens;
        bool refunded;
    }

    mapping(address => Investor) public investors;
    address[] public investorList;

    // Events
    event PresaleActivated(uint256 start, uint256 end);
    event TokensPurchased(address indexed buyer, uint256 xplAmount, uint256 tokenAmount);
    event RefundClaimed(address indexed buyer, uint256 amount);
    event FundsWithdrawn(uint256 amount);
    event NativeReceived(address indexed sender, uint256 amount);

    constructor() Ownable(msg.sender) {}

    // ========= PRESALE CONTROL =========

    function activatePresale() external onlyOwner {
        require(!presaleActive, "Presale already active");
        startTime = block.timestamp;
        endTime = block.timestamp + PRESALE_DURATION;
        presaleActive = true;
        emit PresaleActivated(startTime, endTime);
    }

    receive() external payable nonReentrant {
        emit NativeReceived(msg.sender, msg.value);
        if (presaleActive && block.timestamp <= endTime) {
            _buy(msg.sender, msg.value);
        }
    }

    function buy() external payable nonReentrant {
        require(presaleActive, "Presale not active");
        require(block.timestamp <= endTime, "Presale ended");
        _buy(msg.sender, msg.value);
    }

    function _buy(address buyer, uint256 amount) internal {
        require(amount >= MIN_BUY && amount <= MAX_BUY, "Invalid amount");
        require(totalRaised + amount <= 50_000 ether, "Hard cap reached");

        uint256 tokenAmount = (amount * TOKENS_PER_XPL) / 1 ether;
        require(totalSold + tokenAmount <= PRESALE_TOKENS, "Not enough tokens");

        if (investors[buyer].invested == 0) investorList.push(buyer);

        investors[buyer].invested += amount;
        investors[buyer].tokens += tokenAmount;
        totalRaised += amount;
        totalSold += tokenAmount;

        emit TokensPurchased(buyer, amount, tokenAmount);
    }

    // ========= OWNER FUNCTIONS =========

    function finalizePresale() external onlyOwner {
        require(presaleActive, "Not active");
        require(block.timestamp > endTime, "Presale not ended");
        presaleActive = false;
        presaleFinalized = true;
        refundEnabled = totalRaised < 25_000 ether; // Soft cap
    }

    function withdrawXPL() external onlyOwner nonReentrant {
        require(presaleFinalized && !refundEnabled, "Cannot withdraw");
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
        emit FundsWithdrawn(balance);
    }

    function emergencyWithdrawNative() external onlyOwner nonReentrant {
        uint256 bal = address(this).balance;
        (bool ok, ) = payable(owner()).call{value: bal}("");
        require(ok, "Native withdraw failed");
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(presaleFinalized && !refundEnabled, "Presale not successful");
        uint256 unsold = cozyToken.balanceOf(address(this)) - totalSold;
        if (unsold > 0) {
            cozyToken.transfer(owner(), unsold);
        }
    }

    // ========= REFUND =========

    function claimRefund() external nonReentrant {
        require(refundEnabled, "Refund not available");
        Investor storage inv = investors[msg.sender];
        require(inv.invested > 0 && !inv.refunded, "No refund");
        uint256 amount = inv.invested;
        inv.refunded = true;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Refund failed");
        emit RefundClaimed(msg.sender, amount);
    }

    // ========= SAFETY =========

    function emergencyWithdrawToken(address tokenAddr) external onlyOwner {
        require(tokenAddr != address(cozyToken), "Cannot withdraw presale token");
        IERC20 token = IERC20(tokenAddr);
        uint256 bal = token.balanceOf(address(this));
        if (bal > 0) token.transfer(owner(), bal);
    }

    // ========= VIEWS =========

    function getPresaleStatus() public view returns (string memory) {
        if (!presaleActive && !presaleFinalized) return "Not Started";
        if (presaleActive && block.timestamp <= endTime) return "Active";
        if (presaleFinalized && refundEnabled) return "Failed - Refund";
        if (presaleFinalized && !refundEnabled) return "Success";
        return "Ended";
    }

    function getInvestorCount() external view returns (uint256) {
        return investorList.length;
    }
}
