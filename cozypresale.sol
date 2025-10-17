// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CozyTokenPresale is Ownable, ReentrancyGuard {
    IERC20 public cozyToken;

    uint256 public constant MAX_SUPPLY = 120_000_000 * 1e18;
    uint256 public constant PRESALE_PERCENTAGE = 20;
    uint256 public constant PRESALE_TOKENS = (MAX_SUPPLY * PRESALE_PERCENTAGE) / 100;

    uint256 public constant TOKENS_PER_XPL = 1000 * 1e18;
    uint256 public constant MIN_BUY = 1 ether;        // 1 XPL
    uint256 public constant MAX_BUY = 1000 ether;     // 1000 XPL per wallet
    uint256 public constant PRESALE_DURATION = 90 days;
    uint256 public constant SOFT_CAP = 25_000 ether;
    uint256 public constant HARD_CAP = 50_000 ether;
    uint256 public constant CLIFF_DURATION = 30 days;
    uint256 public constant VESTING_DURATION = 330 days;

    uint256 public startTime;
    uint256 public endTime;

    uint256 public totalRaised;
    uint256 public totalTokensSold;
    bool public presaleFinalized;
    bool public refundEnabled;
    bool public presaleActive;

    struct Investor {
        uint256 investedAmount;
        uint256 tokenAmount;
        uint256 claimedAmount;
        uint256 lastClaimTime;
        bool refunded;
    }

    mapping(address => Investor) public investors;
    address[] public investorAddresses;

    event TokensPurchased(address indexed investor, uint256 xplAmount, uint256 cozyTokens);
    event TokensClaimed(address indexed investor, uint256 amount);
    event RefundClaimed(address indexed investor, uint256 amount);
    event PresaleFinalized(bool success, uint256 totalRaised);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event TokenRecovered(address indexed token, uint256 amount);
    event NativeReceived(address indexed from, uint256 amount);
    event PresaleActivated(uint256 startTime, uint256 endTime);

    // ====== SETUP ======

    function setCozyToken(address _token) external onlyOwner {
        require(address(cozyToken) == address(0), "Already set");
        require(_token != address(0), "Invalid token");
        cozyToken = IERC20(_token);
    }

    // ====== ACTIVATE PRESALE (auto 3 months) ======

    function activatePresale() external onlyOwner {
        require(!presaleActive, "Presale already active");
        require(address(cozyToken) != address(0), "Token not set");

        startTime = block.timestamp;
        endTime = block.timestamp + PRESALE_DURATION;
        presaleActive = true;

        emit PresaleActivated(startTime, endTime);
    }

    // ====== BUY TOKEN ======

    receive() external payable nonReentrant {
        _buyTokens(msg.sender, msg.value);
        emit NativeReceived(msg.sender, msg.value);
    }

    function _buyTokens(address buyer, uint256 xplAmount) internal {
        require(presaleActive, "Presale not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Out of presale time");
        require(xplAmount >= MIN_BUY && xplAmount <= MAX_BUY, "Buy outside limits");
        require(totalRaised + xplAmount <= HARD_CAP, "Hard cap reached");

        Investor storage inv = investors[buyer];
        require(inv.investedAmount + xplAmount <= MAX_BUY, "Exceeds wallet limit");

        uint256 tokensToReceive = (xplAmount * TOKENS_PER_XPL) / 1e18;
        require(totalTokensSold + tokensToReceive <= PRESALE_TOKENS, "Not enough tokens");
        require(cozyToken.balanceOf(address(this)) >= tokensToReceive, "Insufficient COZY tokens");

        if (inv.investedAmount == 0) investorAddresses.push(buyer);

        inv.investedAmount += xplAmount;
        inv.tokenAmount += tokensToReceive;
        totalRaised += xplAmount;
        totalTokensSold += tokensToReceive;

        emit TokensPurchased(buyer, xplAmount, tokensToReceive);
    }

    // ====== CLAIM ======

    function claimTokens() external nonReentrant {
        require(presaleFinalized && !refundEnabled, "Presale not ready");
        Investor storage inv = investors[msg.sender];
        require(inv.tokenAmount > 0 && !inv.refunded, "No tokens or refunded");

        uint256 claimable = getClaimableTokens(msg.sender);
        require(claimable > 0, "Nothing to claim");

        inv.claimedAmount += claimable;
        inv.lastClaimTime = block.timestamp;
        require(cozyToken.transfer(msg.sender, claimable), "Transfer failed");

        emit TokensClaimed(msg.sender, claimable);
    }

    // ====== REFUND ======

    function claimRefund() external nonReentrant {
        require(refundEnabled, "Refund not enabled");
        Investor storage inv = investors[msg.sender];
        require(inv.investedAmount > 0 && !inv.refunded, "No funds or already refunded");

        uint256 refundAmount = inv.investedAmount;
        inv.refunded = true;
        inv.tokenAmount = 0;
        inv.investedAmount = 0;

        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund failed");

        emit RefundClaimed(msg.sender, refundAmount);
    }

    // ====== FINALIZE ======

    function finalizePresale() external onlyOwner {
        require(presaleActive, "Presale not active");
        require(!presaleFinalized, "Already finalized");
        require(block.timestamp > endTime, "Presale not ended");

        presaleFinalized = true;
        refundEnabled = totalRaised < SOFT_CAP;

        emit PresaleFinalized(!refundEnabled, totalRaised);
    }

    // ====== WITHDRAW ======

    function withdrawXPL() external onlyOwner {
        require(presaleFinalized && !refundEnabled, "Presale failed");
        require(totalRaised >= SOFT_CAP, "Soft cap not met");

        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdraw failed");

        emit FundsWithdrawn(owner(), balance);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        require(presaleFinalized && !refundEnabled, "Not finalized or failed");

        uint256 unsold = cozyToken.balanceOf(address(this)) - totalTokensSold;
        require(unsold > 0, "No unsold tokens");
        require(cozyToken.transfer(owner(), unsold), "Token transfer failed");
    }

    // ====== VIEW ======

    function getClaimableTokens(address user) public view returns (uint256) {
        Investor memory inv = investors[user];
        if (!presaleFinalized || refundEnabled || inv.refunded || inv.claimedAmount >= inv.tokenAmount) {
            return 0;
        }

        uint256 vestingStart = endTime + CLIFF_DURATION;
        if (block.timestamp < vestingStart) return 0;
        if (block.timestamp >= vestingStart + VESTING_DURATION) {
            return inv.tokenAmount - inv.claimedAmount;
        }

        uint256 timePassed = block.timestamp - vestingStart;
        uint256 totalVested = (inv.tokenAmount * timePassed) / VESTING_DURATION;
        return totalVested - inv.claimedAmount;
    }

    function getPresaleStatus() public view returns (string memory) {
        if (!presaleActive) return "Inactive";
        if (!presaleFinalized) {
            if (block.timestamp < startTime) return "Not Started";
            if (block.timestamp <= endTime) return "Active";
            return "Ended - Pending Finalization";
        }
        if (refundEnabled) return "Failed - Refunds Active";
        return "Success - Claim Ongoing";
    }

    function getInvestorCount() external view returns (uint256) {
        return investorAddresses.length;
    }

    // ====== EMERGENCY RECOVERY ======

    function recoverToken(address tokenAddress) external onlyOwner {
        require(tokenAddress != address(cozyToken), "Can't recover presale token");
        IERC20 token = IERC20(tokenAddress);
        uint256 bal = token.balanceOf(address(this));
        require(bal > 0, "No balance");
        token.transfer(owner(), bal);
        emit TokenRecovered(tokenAddress, bal);
    }

    function emergencyWithdrawNative() external onlyOwner {
        uint256 bal = address(this).balance;
        require(bal > 0, "No balance");
        (bool success, ) = owner().call{value: bal}("");
        require(success, "Withdraw failed");
        emit FundsWithdrawn(owner(), bal);
    }
}
