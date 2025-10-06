// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NexBitStaking is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    
    // Constants
    uint256 public constant MIN_STAKE = 1 * 10**18; // 1 NEX (asumsi 18 decimals)
    uint256 public constant MAX_STAKE = 100000 * 10**18; // 100,000 NEX
    uint256 public constant DAY = 24 hours;
    
    // APY Configuration (dalam basis points, 10000 = 100%)
    struct Plan {
        uint256 duration; // dalam days
        uint256 apy; // dalam basis points (100% = 10000)
    }
    
    Plan[] public plans;
    
    // Staking structure
    struct Stake {
        uint256 amount;
        uint256 planIndex;
        uint256 startTime;
        uint256 endTime;
        uint256 lastClaimTime;
        uint256 totalRewards;
        bool active;
    }
    
    // User stakes mapping
    mapping(address => Stake[]) public userStakes;
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 planIndex, uint256 endTime);
    event Claimed(address indexed user, uint256 reward, uint256 stakeIndex);
    event Unstaked(address indexed user, uint256 amount, uint256 stakeIndex);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NativeReceived(address from, uint256 amount);
    
    constructor(address _stakingToken) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid token address");
        stakingToken = IERC20(_stakingToken);
        
        // Initialize staking plans
        plans.push(Plan(30 days, 10000));   // 1 bulan 100%
        plans.push(Plan(60 days, 15000));   // 2 bulan 150%
        plans.push(Plan(90 days, 20000));   // 3 bulan 200%
        plans.push(Plan(180 days, 30000));  // 6 bulan 300%
        plans.push(Plan(365 days, 60000));  // 12 bulan 600%
    }
    
    // Receive native token
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }
    
    /**
     * @dev Stake tokens dengan plan tertentu
     */
    function stake(uint256 _amount, uint256 _planIndex) external nonReentrant {
        require(_amount >= MIN_STAKE, "Amount below minimum stake");
        require(_amount <= MAX_STAKE, "Amount exceeds maximum stake");
        require(_planIndex < plans.length, "Invalid plan index");
        
        Plan memory plan = plans[_planIndex];
        uint256 endTime = block.timestamp + plan.duration;
        
        // Transfer tokens dari user ke contract
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // Create new stake
        userStakes[msg.sender].push(Stake({
            amount: _amount,
            planIndex: _planIndex,
            startTime: block.timestamp,
            endTime: endTime,
            lastClaimTime: block.timestamp,
            totalRewards: 0,
            active: true
        }));
        
        emit Staked(msg.sender, _amount, _planIndex, endTime);
    }
    
    /**
     * @dev Claim rewards untuk stake tertentu
     */
    function claimRewards(uint256 _stakeIndex) external nonReentrant {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        Stake storage userStake = userStakes[msg.sender][_stakeIndex];
        require(userStake.active, "Stake not active");
        
        uint256 pendingRewards = calculatePendingRewards(msg.sender, _stakeIndex);
        require(pendingRewards > 0, "No rewards to claim");
        
        // Update stake data
        userStake.lastClaimTime = block.timestamp;
        userStake.totalRewards += pendingRewards;
        
        // Transfer rewards
        require(stakingToken.transfer(msg.sender, pendingRewards), "Reward transfer failed");
        
        emit Claimed(msg.sender, pendingRewards, _stakeIndex);
    }
    
    /**
     * @dev Claim semua rewards dari semua active stakes
     */
    function claimAllRewards() external nonReentrant {
        uint256 totalRewards;
        
        for (uint256 i = 0; i < userStakes[msg.sender].length; i++) {
            if (userStakes[msg.sender][i].active) {
                uint256 pending = calculatePendingRewards(msg.sender, i);
                if (pending > 0) {
                    totalRewards += pending;
                    userStakes[msg.sender][i].lastClaimTime = block.timestamp;
                    userStakes[msg.sender][i].totalRewards += pending;
                }
            }
        }
        
        require(totalRewards > 0, "No rewards to claim");
        require(stakingToken.transfer(msg.sender, totalRewards), "Reward transfer failed");
        
        emit Claimed(msg.sender, totalRewards, type(uint256).max); // max value untuk indicate all
    }
    
    /**
     * @dev Unstake tokens setelah periode selesai
     */
    function unstake(uint256 _stakeIndex) external nonReentrant {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        Stake storage userStake = userStakes[msg.sender][_stakeIndex];
        require(userStake.active, "Stake not active");
        require(block.timestamp >= userStake.endTime, "Staking period not ended");
        
        // Claim sisa rewards terakhir
        uint256 pendingRewards = calculatePendingRewards(msg.sender, _stakeIndex);
        uint256 totalAmount = userStake.amount;
        
        if (pendingRewards > 0) {
            userStake.totalRewards += pendingRewards;
            totalAmount += pendingRewards;
        }
        
        // Mark stake sebagai tidak active
        userStake.active = false;
        
        // Transfer kembali staked amount + rewards
        require(stakingToken.transfer(msg.sender, totalAmount), "Unstake transfer failed");
        
        emit Unstaked(msg.sender, totalAmount, _stakeIndex);
    }
    
    /**
     * @dev Emergency withdraw (dengan penalty - hanya untuk owner)
     */
    function emergencyWithdraw(uint256 _stakeIndex) external nonReentrant {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        Stake storage userStake = userStakes[msg.sender][_stakeIndex];
        require(userStake.active, "Stake not active");
        
        // Hanya bisa withdraw 50% sebagai penalty
        uint256 penaltyAmount = userStake.amount / 2;
        userStake.active = false;
        
        require(stakingToken.transfer(msg.sender, penaltyAmount), "Emergency withdraw failed");
        
        emit EmergencyWithdraw(msg.sender, penaltyAmount);
    }
    
    /**
     * @dev Calculate pending rewards untuk stake tertentu
     */
    function calculatePendingRewards(address _user, uint256 _stakeIndex) public view returns (uint256) {
        if (_stakeIndex >= userStakes[_user].length) return 0;
        
        Stake memory userStake = userStakes[_user][_stakeIndex];
        if (!userStake.active) return 0;
        
        Plan memory plan = plans[userStake.planIndex];
        
        // Hitung waktu yang sudah berlalu sejak last claim
        uint256 timeElapsed;
        if (block.timestamp > userStake.endTime) {
            timeElapsed = userStake.endTime - userStake.lastClaimTime;
        } else {
            timeElapsed = block.timestamp - userStake.lastClaimTime;
        }
        
        if (timeElapsed == 0) return 0;
        
        // Calculate rewards: (amount * apy * timeElapsed) / (365 days * 10000)
        uint256 rewards = (userStake.amount * plan.apy * timeElapsed) / (365 days * 10000);
        
        return rewards;
    }
    
    /**
     * @dev Get total pending rewards untuk user
     */
    function getTotalPendingRewards(address _user) external view returns (uint256) {
        uint256 totalPending;
        
        for (uint256 i = 0; i < userStakes[_user].length; i++) {
            if (userStakes[_user][i].active) {
                totalPending += calculatePendingRewards(_user, i);
            }
        }
        
        return totalPending;
    }
    
    /**
     * @dev Get user's active stakes count
     */
    function getUserActiveStakesCount(address _user) external view returns (uint256) {
        uint256 count;
        for (uint256 i = 0; i < userStakes[_user].length; i++) {
            if (userStakes[_user][i].active) {
                count++;
            }
        }
        return count;
    }
    
    /**
     * @dev Get user stake details
     */
    function getUserStakes(address _user) external view returns (Stake[] memory) {
        return userStakes[_user];
    }
    
    /**
     * @dev Get contract staking token balance
     */
    function getStakingTokenBalance() external view returns (uint256) {
        return stakingToken.balanceOf(address(this));
    }
    
    /**
     * @dev Get native token balance
     */
    function getNativeBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Withdraw native tokens (hanya owner)
     */
    function withdrawNative(uint256 _amount) external onlyOwner {
        require(address(this).balance >= _amount, "Insufficient balance");
        payable(owner()).transfer(_amount);
    }
    
    /**
     * @dev Withdraw ERC20 tokens (hanya owner)
     */
    function withdrawERC20(address _token, uint256 _amount) external onlyOwner {
        require(_token != address(stakingToken), "Cannot withdraw staking token");
        IERC20(_token).transfer(owner(), _amount);
    }
    
    /**
     * @dev Add new staking plan (hanya owner)
     */
    function addStakingPlan(uint256 _duration, uint256 _apy) external onlyOwner {
        plans.push(Plan(_duration, _apy));
    }
    
    /**
     * @dev Update existing staking plan (hanya owner)
     */
    function updateStakingPlan(uint256 _planIndex, uint256 _duration, uint256 _apy) external onlyOwner {
        require(_planIndex < plans.length, "Invalid plan index");
        plans[_planIndex] = Plan(_duration, _apy);
    }
    
    /**
     * @dev Get total plans count
     */
    function getPlansCount() external view returns (uint256) {
        return plans.length;
    }
}