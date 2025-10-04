// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ServiceRewards is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Main reward token
    IERC20 public rewardToken;
    address public rewardTokenAddress;
    
    // Supported tokens for contributions
    struct TokenInfo {
        bool isSupported;
        uint256 conversionRate; // tokens per 1 MATIC
        uint256 minContribution;
        uint256 maxContribution;
    }
    
    mapping(address => TokenInfo) public supportedTokens;
    address[] public supportedTokenList;
    
    uint256 private constant TOKEN_DECIMALS = 18;
    uint256 private constant MIN_CONTRIBUTION = 1 ether;
    uint256 private constant MAX_CONTRIBUTION = 1000 ether;
    
    // Reward tiers - hidden from public view
    mapping(uint256 => uint256) private contributionRewards;
    
    mapping(address => uint256) public userContributions;
    mapping(address => uint256) public userTokenContributions;
    mapping(address => uint256) public totalRewardsReceived;
    
    bool public rewardsActive = true;
    uint256 public totalContributions;
    uint256 public totalTokenContributions;
    uint256 public totalRewardsDistributed;
    
    event ContributionReceived(address indexed user, uint256 amount, uint256 reward, address token);
    event RewardsClaimed(address indexed user, uint256 amount);
    event EmergencyWithdraw(address token, uint256 amount);
    event TokenSupported(address token, uint256 conversionRate);
    event TokenRemoved(address token);
    
    constructor(address _rewardToken) Ownable(msg.sender) {
        require(_rewardToken != address(0), "Invalid token address");
        rewardToken = IERC20(_rewardToken);
        rewardTokenAddress = _rewardToken;
        _initializeRewards();
    }
    
    function _initializeRewards() private {
        contributionRewards[1 ether] = 10 * 10**TOKEN_DECIMALS;
        contributionRewards[5 ether] = 60 * 10**TOKEN_DECIMALS;
        contributionRewards[10 ether] = 120 * 10**TOKEN_DECIMALS;
        contributionRewards[20 ether] = 230 * 10**TOKEN_DECIMALS;
        contributionRewards[50 ether] = 550 * 10**TOKEN_DECIMALS;
        contributionRewards[100 ether] = 1600 * 10**TOKEN_DECIMALS;
        contributionRewards[1000 ether] = 11000 * 10**TOKEN_DECIMALS;
    }
    
    receive() external payable {
        participateWithMatic();
    }
    
    // MATIC contributions
    function participateWithMatic() public payable nonReentrant {
        require(rewardsActive, "Rewards program inactive");
        require(msg.value >= MIN_CONTRIBUTION, "Below minimum");
        require(msg.value <= MAX_CONTRIBUTION, "Exceeds maximum");
        
        uint256 rewardAmount = calculateServiceReward(msg.value);
        require(rewardAmount > 0, "No rewards for this amount");
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Insufficient reward tokens");
        
        userContributions[msg.sender] += msg.value;
        totalContributions += msg.value;
        
        // Immediate reward distribution
        rewardToken.safeTransfer(msg.sender, rewardAmount);
        
        totalRewardsDistributed += rewardAmount;
        totalRewardsReceived[msg.sender] += rewardAmount;
        
        emit ContributionReceived(msg.sender, msg.value, rewardAmount, address(0));
    }
    
    // Token contributions
    function participateWithToken(address token, uint256 amount) external nonReentrant {
        require(rewardsActive, "Rewards program inactive");
        require(token != address(0), "Invalid token");
        require(supportedTokens[token].isSupported, "Token not supported");
        require(amount >= supportedTokens[token].minContribution, "Below minimum");
        require(amount <= supportedTokens[token].maxContribution, "Exceeds maximum");
        
        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate MATIC equivalent
        uint256 maticEquivalent = (amount * 1 ether) / supportedTokens[token].conversionRate;
        uint256 rewardAmount = calculateServiceReward(maticEquivalent);
        
        require(rewardAmount > 0, "No rewards for this amount");
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Insufficient reward tokens");
        
        userTokenContributions[msg.sender] += amount;
        totalTokenContributions += amount;
        
        // Distribute rewards
        rewardToken.safeTransfer(msg.sender, rewardAmount);
        
        totalRewardsDistributed += rewardAmount;
        totalRewardsReceived[msg.sender] += rewardAmount;
        
        emit ContributionReceived(msg.sender, amount, rewardAmount, token);
    }
    
    function calculateServiceReward(uint256 contribution) public view returns (uint256) {
        if (contribution >= 1000 ether) return 11000 * 10**TOKEN_DECIMALS;
        if (contribution >= 100 ether) return 1600 * 10**TOKEN_DECIMALS;
        if (contribution >= 50 ether) return 550 * 10**TOKEN_DECIMALS;
        if (contribution >= 20 ether) return 230 * 10**TOKEN_DECIMALS;
        if (contribution >= 10 ether) return 120 * 10**TOKEN_DECIMALS;
        if (contribution >= 5 ether) return 60 * 10**TOKEN_DECIMALS;
        if (contribution >= 1 ether) return 10 * 10**TOKEN_DECIMALS;
        return 0;
    }
    
    // Token Management Functions
    function addSupportedToken(
        address token,
        uint256 conversionRate,
        uint256 minContribution,
        uint256 maxContribution
    ) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(token != rewardTokenAddress, "Cannot add reward token");
        require(conversionRate > 0, "Invalid conversion rate");
        
        if (!supportedTokens[token].isSupported) {
            supportedTokenList.push(token);
        }
        
        supportedTokens[token] = TokenInfo({
            isSupported: true,
            conversionRate: conversionRate,
            minContribution: minContribution,
            maxContribution: maxContribution
        });
        
        emit TokenSupported(token, conversionRate);
    }
    
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token].isSupported, "Token not supported");
        
        supportedTokens[token].isSupported = false;
        
        // Remove from list
        for (uint256 i = 0; i < supportedTokenList.length; i++) {
            if (supportedTokenList[i] == token) {
                supportedTokenList[i] = supportedTokenList[supportedTokenList.length - 1];
                supportedTokenList.pop();
                break;
            }
        }
        
        emit TokenRemoved(token);
    }
    
    function updateTokenConversionRate(address token, uint256 newRate) external onlyOwner {
        require(supportedTokens[token].isSupported, "Token not supported");
        require(newRate > 0, "Invalid conversion rate");
        supportedTokens[token].conversionRate = newRate;
    }
    
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokenList;
    }
    
    function getTokenInfo(address token) external view returns (TokenInfo memory) {
        return supportedTokens[token];
    }
    
    // Administrative functions
    function updateRewardsStatus(bool _active) external onlyOwner {
        rewardsActive = _active;
    }
    
    function adjustRewardTiers(
        uint256[] memory amounts,
        uint256[] memory rewards
    ) external onlyOwner {
        require(amounts.length == rewards.length, "Array length mismatch");
        
        for (uint256 i = 0; i < amounts.length; i++) {
            contributionRewards[amounts[i]] = rewards[i] * 10**TOKEN_DECIMALS;
        }
    }
    
    function withdrawMatic(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner()).transfer(amount);
    }
    
    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(token, amount);
    }
    
    // Contract information functions
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    function getRewardTokenBalance() external view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
    
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
    
    function getUserStats(address user) external view returns (
        uint256 maticContributions,
        uint256 tokenContributions,
        uint256 totalRewards
    ) {
        return (
            userContributions[user],
            userTokenContributions[user],
            totalRewardsReceived[user]
        );
    }
    
    // Emergency functions
    function emergencyPause() external onlyOwner {
        rewardsActive = false;
    }
    
    function recoverFunds() external onlyOwner {
        // Withdraw MATIC
        uint256 maticBalance = address(this).balance;
        if (maticBalance > 0) {
            payable(owner()).transfer(maticBalance);
        }
        
        // Withdraw all supported tokens
        for (uint256 i = 0; i < supportedTokenList.length; i++) {
            address token = supportedTokenList[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(owner(), balance);
            }
        }
        
        // Withdraw reward tokens (if any left)
        uint256 rewardBalance = rewardToken.balanceOf(address(this));
        if (rewardBalance > 0) {
            rewardToken.safeTransfer(owner(), rewardBalance);
        }
    }
    
    // Fund the contract with reward tokens
    function fundRewardTokens(uint256 amount) external {
        rewardToken.safeTransferFrom(msg.sender, address(this), amount);
    }
}