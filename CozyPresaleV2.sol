// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract CozyTokenPresale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    // COZY Token Information
    IERC20 public cozyToken;
    address public constant COZY_ADDRESS = 0x06E2Ef46662834F4E42dBf9fF9222B077C57dF5C;

    // Tokenomics
    uint256 public constant MAX_SUPPLY = 120_000_000 * 10**18;
    uint256 public constant PRESALE_TOKENS = 25_000_000 * 10**18; // 25M COZY for presale
    uint256 public constant TOKENS_PER_XPL = 1000 * 10**18;       // 1 XPL = 1000 COZY

    // presale time (3 month)
    uint256 public startTime;
    uint256 public endTime;
    uint256 public constant PRESALE_DURATION = 90 days;

    // Target
    uint256 public constant SOFT_CAP = 25_000 * 10**18; // 25.000 XPL
    uint256 public constant HARD_CAP = 50_000 * 10**18; // 50.000 XPL

    // Vesting
    uint256 public constant CLIFF_DURATION = 30 days; 
    uint256 public constant VESTING_DURATION = 330 days; 

    // Status
    uint256 public totalRaised;
    uint256 public totalTokensSold;
    bool public presaleActive;
    bool public presaleFinalized;
    bool public refundEnabled;

    struct Investor {
        uint256 investedAmount;
        uint256 tokenAmount;
        uint256 claimedAmount;
        uint256 lastClaimTime;
        bool refunded;
    }

    mapping(address => Investor) public investors;
    address[] public investorAddresses;

    // Events
    event PresaleActivated(uint256 startTime, uint256 endTime);
    event TokensPurchased(address indexed investor, uint256 xplAmount, uint256 cozyTokens);
    event TokensClaimed(address indexed investor, uint256 amount);
    event RefundClaimed(address indexed investor, uint256 amount);
    event PresaleFinalized(bool success, uint256 totalRaised);
    event FundsWithdrawn(address indexed owner, uint256 amount);
    event Received(address indexed sender, uint256 amount);
    event ERC20Recovered(address token, uint256 amount);

    constructor() Ownable(msg.sender) {
        cozyToken = IERC20(COZY_ADDRESS);
    }

    // Aktifkan presale otomatis 3 bulan
    function activatePresale() external onlyOwner {
        require(!presaleActive, "Presale already active");
        startTime = block.timestamp;
        endTime = startTime + PRESALE_DURATION;
        presaleActive = true;
        emit PresaleActivated(startTime, endTime);
    }

    // Terima native XPL langsung
    receive() external payable nonReentrant {
        require(presaleActive, "Presale not active");
        _processPurchase(msg.sender, msg.value);
        emit Received(msg.sender, msg.value);
    }

    function buyTokens() external payable nonReentrant {
        require(presaleActive, "Presale not active");
        require(msg.value > 0, "Invalid amount");
        _processPurchase(msg.sender, msg.value);
    }

    function _processPurchase(address investor, uint256 xplAmount) internal {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not running");
        require(xplAmount >= 1 ether && xplAmount <= 1000 ether, "Buy limit 1-1000 XPL");
        require(totalRaised + xplAmount <= HARD_CAP, "Hard cap reached");

        uint256 tokensToReceive = xplAmount.mul(TOKENS_PER_XPL).div(1 ether);
        require(totalTokensSold + tokensToReceive <= PRESALE_TOKENS, "Not enough tokens");
        require(cozyToken.balanceOf(address(this)) >= tokensToReceive, "Insufficient COZY in contract");

        if (investors[investor].investedAmount == 0) {
            investorAddresses.push(investor);
        }

        investors[investor].investedAmount += xplAmount;
        investors[investor].tokenAmount += tokensToReceive;

        totalRaised += xplAmount;
        totalTokensSold += tokensToReceive;

        emit TokensPurchased(investor, xplAmount, tokensToReceive);
    }

    // Klaim token setelah vesting
    function claimTokens() external nonReentrant {
        require(presaleFinalized && !refundEnabled, "Claim not available");
        Investor storage inv = investors[msg.sender];
        require(inv.tokenAmount > 0 && !inv.refunded, "No tokens to claim");

        uint256 claimable = getClaimableTokens(msg.sender);
        require(claimable > 0, "No claimable tokens");

        inv.claimedAmount += claimable;
        inv.lastClaimTime = block.timestamp;
        require(cozyToken.transfer(msg.sender, claimable), "Transfer failed");
        emit TokensClaimed(msg.sender, claimable);
    }

    // Refund
    function claimRefund() external nonReentrant {
        require(refundEnabled, "Refund disabled");
        Investor storage inv = investors[msg.sender];
        require(inv.investedAmount > 0 && !inv.refunded, "Not eligible");

        uint256 refundAmount = inv.investedAmount;
        inv.refunded = true;
        inv.tokenAmount = 0;
        inv.investedAmount = 0;
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Refund failed");
        emit RefundClaimed(msg.sender, refundAmount);
    }

    // Finalisasi
    function finalizePresale() external onlyOwner {
        require(presaleActive && !presaleFinalized, "Already finalized");
        require(block.timestamp > endTime, "Presale not ended");
        presaleFinalized = true;

        if (totalRaised >= SOFT_CAP) refundEnabled = false;
        else refundEnabled = true;

        emit PresaleFinalized(totalRaised >= SOFT_CAP, totalRaised);
    }

    // Owner menarik dana XPL
    function withdrawXPL() external onlyOwner {
        require(presaleFinalized && !refundEnabled, "Cannot withdraw");
        uint256 bal = address(this).balance;
        require(bal > 0, "No XPL to withdraw");
        (bool success, ) = owner().call{value: bal}("");
        require(success, "Withdraw failed");
        emit FundsWithdrawn(owner(), bal);
    }

    // Tarik token COZY tersisa
    function withdrawUnsoldTokens() external onlyOwner {
        require(presaleFinalized, "Presale not finalized");
        uint256 unsold = cozyToken.balanceOf(address(this)) - totalTokensSold;
        require(unsold > 0, "No unsold tokens");
        cozyToken.transfer(owner(), unsold);
    }

    // Fungsi bantuan
    function getClaimableTokens(address user) public view returns (uint256) {
        Investor memory inv = investors[user];
        if (!presaleFinalized || refundEnabled || inv.refunded) return 0;
        uint256 vestingStart = endTime + CLIFF_DURATION;
        if (block.timestamp < vestingStart) return 0;
        if (block.timestamp >= vestingStart + VESTING_DURATION)
            return inv.tokenAmount - inv.claimedAmount;
        uint256 timePassed = block.timestamp - vestingStart;
        uint256 totalVested = inv.tokenAmount * timePassed / VESTING_DURATION;
        return totalVested - inv.claimedAmount;
    }

    // Emergency recovery token lain
    function recoverERC20(address tokenAddr) external onlyOwner {
        require(tokenAddr != address(cozyToken), "Cannot recover COZY");
        IERC20 t = IERC20(tokenAddr);
        uint256 bal = t.balanceOf(address(this));
        t.transfer(owner(), bal);
        emit ERC20Recovered(tokenAddr, bal);
    }
}
