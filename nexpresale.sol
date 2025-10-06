// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract NEXBitPresalePremium {
    address public owner;
    IERC20 public nexToken;
    
    // Presale Basic Parameters
    uint256 public constant TOTAL_SUPPLY = 27000000 * 10**18;
    uint256 public constant PRESALE_SUPPLY = 5400000 * 10**18;
    uint256 public constant TOKEN_PRICE_USDT = 0.1 * 10**18;
    uint256 public constant TOKEN_PRICE_NATIVE = 0.25 * 10**18;
    
    // Purchase Limits
    uint256 public constant MIN_BUY_USDT = 10 * 10**18;
    uint256 public constant MAX_BUY_USDT = 1000 * 10**18;
    uint256 public constant MIN_BUY_NATIVE = 25 * 10**18;
    uint256 public constant MAX_BUY_NATIVE = 2500 * 10**18;
    
    // Vesting Parameters
    uint256 public constant VESTING_DURATION = 24 * 30 days;
    uint256 public constant VESTING_START_DELAY = 7 days;
    
    // ========== STAKING LIMITS ========== //
    uint256 public constant MIN_STAKING_AMOUNT = 1 * 10**18;
    uint256 public constant MAX_STAKING_AMOUNT = 100000 * 10**18;
    
    // ========== TIER SYSTEM ========== //
    enum Tier { BRONZE, SILVER, GOLD, PLATINUM, DIAMOND }
    
    struct TierInfo {
        uint256 minAllocationUSDT;
        uint256 maxAllocationUSDT;
        uint256 requiredPoints;
        uint256 extraAllocation;
    }
    
    mapping(Tier => TierInfo) public tiers;
    mapping(address => Tier) public userTier;
    mapping(address => uint256) public whitelistPoints;
    
    // ========== REFERRAL SYSTEM ========== //
    struct ReferralInfo {
        address referrer;
        uint256 totalReferred;
        uint256 totalReferralVolume;
        uint256 referralRewards;
    }
    
    mapping(address => ReferralInfo) public referrals;
    mapping(address => address) public userReferrer;
    uint256 public constant REFERRAL_BONUS_PERCENT = 5;
    uint256 public constant REFERRAL_BONUS_BUYER = 3;
    
    // ========== EARLY BIRD BONUS ========== //
    struct EarlyBirdBonus {
        uint256 timeLimit;
        uint256 bonusPercent;
    }
    
    EarlyBirdBonus[] public earlyBirdBonuses;
    
    // ========== APY STAKING SYSTEM ========== //
    enum StakingPeriod { 
        ONE_MONTH,      // 100% APY
        TWO_MONTHS,     // 150% APY  
        THREE_MONTHS,   // 200% APY
        SIX_MONTHS,     // 300% APY
        TWELVE_MONTHS   // 600% APY
    }
    
    struct StakingPlan {
        uint256 duration;
        uint256 apy;
        bool active;
    }
    
    struct UserStake {
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
        StakingPeriod period;
        uint256 rewardsClaimed;
        bool active;
    }
    
    mapping(StakingPeriod => StakingPlan) public stakingPlans;
    mapping(address => UserStake[]) public userStakes;
    uint256 public totalStaked;
    uint256 public totalStakingRewards;
    
    // State Variables
    uint256 public totalRaisedUSDT;
    uint256 public totalRaisedNative;
    uint256 public totalSold;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public vestingStartTime;
    bool public presaleActive;
    bool public vestingStarted;
    
    // User tracking
    struct UserInfo {
        uint256 totalContributionUSDT;
        uint256 totalContributionNative;
        uint256 totalAllocation;
        uint256 totalClaimed;
        uint256 lastClaimTime;
        uint256 bonusAllocation;
        uint256 referralBonus;
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // Accepted stablecoins
    address public constant USDT = 0x900101d06A7426441Ae63e9AB3B9b0F63Be145F1;
    address public constant USDC = 0xa4151B2B3e269645181dCcF2D426cE75fcbDeca9;
    
    // Events
    event TokensPurchased(
        address indexed buyer, 
        uint256 tokenAmount, 
        uint256 paymentAmount, 
        bool isNative, 
        uint256 earlyBirdBonus,
        uint256 referralBonus,
        uint256 tierBonus
    );
    event TokensClaimed(address indexed user, uint256 amount);
    event ReferralReward(address indexed referrer, address indexed referee, uint256 reward);
    event Staked(address indexed user, uint256 amount, StakingPeriod period);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event EmergencyUnstaked(address indexed user, uint256 amount, uint256 penalty);
    event TierUpdated(address indexed user, Tier newTier);
    event EarlyBirdBonusApplied(address indexed user, uint256 bonusPercent);
    event WhitelistPointsAdded(address[] users, uint256[] points);
    event PresaleStarted(uint256 startTime, uint256 endTime);
    event PresaleEnded(uint256 endTime, uint256 totalRaised);
    event VestingStarted(uint256 startTime);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier whenPresaleActive() {
        require(presaleActive, "Presale is not active");
        require(block.timestamp >= startTime && block.timestamp <= endTime, "Presale not in progress");
        _;
    }
    
    modifier whenVestingStarted() {
        require(vestingStarted, "Vesting has not started yet");
        _;
    }

    // ========== CONSTRUCTOR & INITIALIZATION ========== //
    
    constructor(address _nexToken) {
        owner = msg.sender;
        nexToken = IERC20(_nexToken);
        
        _initializeTiers();
        _initializeEarlyBirdBonuses();
        _initializeStakingPlans();
    }
    
    function _initializeTiers() internal {
        tiers[Tier.BRONZE] = TierInfo(10 * 10**18, 100 * 10**18, 10, 5);
        tiers[Tier.SILVER] = TierInfo(100 * 10**18, 500 * 10**18, 50, 10);
        tiers[Tier.GOLD] = TierInfo(500 * 10**18, 1000 * 10**18, 100, 15);
        tiers[Tier.PLATINUM] = TierInfo(1000 * 10**18, 2000 * 10**18, 200, 20);
        tiers[Tier.DIAMOND] = TierInfo(2000 * 10**18, 5000 * 10**18, 500, 25);
    }
    
    function _initializeEarlyBirdBonuses() internal {
        earlyBirdBonuses.push(EarlyBirdBonus(24 hours, 25));
        earlyBirdBonuses.push(EarlyBirdBonus(72 hours, 15));
        earlyBirdBonuses.push(EarlyBirdBonus(168 hours, 10));
        earlyBirdBonuses.push(EarlyBirdBonus(336 hours, 5));
    }
    
    function _initializeStakingPlans() internal {
        stakingPlans[StakingPeriod.ONE_MONTH] = StakingPlan(30 days, 10000, true);
        stakingPlans[StakingPeriod.TWO_MONTHS] = StakingPlan(60 days, 15000, true);
        stakingPlans[StakingPeriod.THREE_MONTHS] = StakingPlan(90 days, 20000, true);
        stakingPlans[StakingPeriod.SIX_MONTHS] = StakingPlan(180 days, 30000, true);
        stakingPlans[StakingPeriod.TWELVE_MONTHS] = StakingPlan(360 days, 60000, true);
    }

    // ========== MAIN PRESALE FUNCTIONS ========== //

    function buyWithNative(address referrer) external payable whenPresaleActive {
        if (referrer != address(0) && userReferrer[msg.sender] == address(0)) {
            userReferrer[msg.sender] = referrer;
            referrals[referrer].totalReferred++;
        }
        _processPurchase(msg.sender, msg.value, true);
    }
    
    function buyWithUSDT(uint256 usdtAmount, address referrer) external whenPresaleActive {
        if (referrer != address(0) && userReferrer[msg.sender] == address(0)) {
            userReferrer[msg.sender] = referrer;
            referrals[referrer].totalReferred++;
        }
        
        require(IERC20(USDT).transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");
        _processPurchase(msg.sender, usdtAmount, false);
    }
    
    function _processPurchase(address buyer, uint256 paymentAmount, bool isNative) internal {
        require(paymentAmount >= (isNative ? MIN_BUY_NATIVE : MIN_BUY_USDT), "Below minimum purchase");
        require(paymentAmount <= (isNative ? MAX_BUY_NATIVE : MAX_BUY_USDT), "Exceeds maximum purchase");
        
        UserInfo storage user = userInfo[buyer];
        Tier userTierLevel = userTier[buyer];
        TierInfo memory tier = tiers[userTierLevel];
        
        // Check tier limits
        uint256 currentContribution = isNative ? user.totalContributionNative : user.totalContributionUSDT;
        require(currentContribution + paymentAmount >= tier.minAllocationUSDT, "Below tier minimum");
        require(currentContribution + paymentAmount <= tier.maxAllocationUSDT, "Exceeds tier allocation");
        
        // Calculate base token amount
        uint256 baseTokenAmount = isNative ? 
            (paymentAmount * 10**18) / TOKEN_PRICE_NATIVE :
            (paymentAmount * 10**18) / TOKEN_PRICE_USDT;
        
        // Apply early bird bonus
        (uint256 earlyBirdBonus, uint256 bonusPercent) = _getEarlyBirdBonus(baseTokenAmount);
        
        // Apply tier bonus
        uint256 tierBonus = (baseTokenAmount * tier.extraAllocation) / 100;
        
        // Total token amount
        uint256 totalTokenAmount = baseTokenAmount + earlyBirdBonus + tierBonus;
        
        require(totalSold + totalTokenAmount <= PRESALE_SUPPLY, "Exceeds presale supply");
        
        // Update user info
        if (isNative) {
            user.totalContributionNative += paymentAmount;
            totalRaisedNative += paymentAmount;
        } else {
            user.totalContributionUSDT += paymentAmount;
            totalRaisedUSDT += paymentAmount;
        }
        
        user.totalAllocation += totalTokenAmount;
        user.bonusAllocation += (earlyBirdBonus + tierBonus);
        totalSold += totalTokenAmount;
        
        // Process referral rewards
        _processReferralReward(buyer, baseTokenAmount, paymentAmount);
        
        if (bonusPercent > 0) {
            emit EarlyBirdBonusApplied(buyer, bonusPercent);
        }
        
        emit TokensPurchased(
            buyer, 
            totalTokenAmount, 
            paymentAmount, 
            isNative, 
            earlyBirdBonus,
            user.referralBonus,
            tierBonus
        );
    }

    // ========== REFERRAL SYSTEM FUNCTIONS ========== //
    
    function _processReferralReward(address buyer, uint256 tokenAmount, uint256 paymentAmount) internal {
        address referrer = userReferrer[buyer];
        if (referrer != address(0) && referrer != buyer) {
            uint256 referrerBonus = (tokenAmount * REFERRAL_BONUS_PERCENT) / 100;
            referrals[referrer].referralRewards += referrerBonus;
            referrals[referrer].totalReferralVolume += paymentAmount;
            
            uint256 buyerBonus = (tokenAmount * REFERRAL_BONUS_BUYER) / 100;
            userInfo[buyer].referralBonus += buyerBonus;
            
            emit ReferralReward(referrer, buyer, referrerBonus + buyerBonus);
        }
    }
    
    function setReferrer(address referrer) external {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(referrer != address(0), "Invalid referrer");
        require(userReferrer[msg.sender] == address(0), "Referrer already set");
        
        userReferrer[msg.sender] = referrer;
        referrals[referrer].totalReferred++;
    }

    // ========== EARLY BIRD BONUS FUNCTIONS ========== //
    
    function _getEarlyBirdBonus(uint256 tokenAmount) internal view returns (uint256 bonusAmount, uint256 bonusPercent) {
        if (!presaleActive) return (0, 0);
        
        uint256 timePassed = block.timestamp - startTime;
        bonusPercent = 0;
        
        for (uint256 i = 0; i < earlyBirdBonuses.length; i++) {
            if (timePassed <= earlyBirdBonuses[i].timeLimit) {
                bonusPercent = earlyBirdBonuses[i].bonusPercent;
                break;
            }
        }
        
        bonusAmount = (tokenAmount * bonusPercent) / 100;
        return (bonusAmount, bonusPercent);
    }
    
    function getCurrentEarlyBirdBonus() public view returns (uint256 bonusPercent, uint256 timeRemaining) {
        if (!presaleActive) return (0, 0);
        
        uint256 timePassed = block.timestamp - startTime;
        
        for (uint256 i = 0; i < earlyBirdBonuses.length; i++) {
            if (timePassed <= earlyBirdBonuses[i].timeLimit) {
                bonusPercent = earlyBirdBonuses[i].bonusPercent;
                timeRemaining = earlyBirdBonuses[i].timeLimit - timePassed;
                return (bonusPercent, timeRemaining);
            }
        }
        
        return (0, 0);
    }

    // ========== TIER SYSTEM FUNCTIONS ========== //
    
    function addWhitelistPoints(address[] memory users, uint256[] memory points) external onlyOwner {
        require(users.length == points.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            whitelistPoints[users[i]] += points[i];
            _updateUserTier(users[i]);
        }
        emit WhitelistPointsAdded(users, points);
    }
    
    function _updateUserTier(address user) internal {
        uint256 points = whitelistPoints[user];
        Tier newTier;
        
        if (points >= tiers[Tier.DIAMOND].requiredPoints) {
            newTier = Tier.DIAMOND;
        } else if (points >= tiers[Tier.PLATINUM].requiredPoints) {
            newTier = Tier.PLATINUM;
        } else if (points >= tiers[Tier.GOLD].requiredPoints) {
            newTier = Tier.GOLD;
        } else if (points >= tiers[Tier.SILVER].requiredPoints) {
            newTier = Tier.SILVER;
        } else {
            newTier = Tier.BRONZE;
        }
        
        if (userTier[user] != newTier) {
            userTier[user] = newTier;
            emit TierUpdated(user, newTier);
        }
    }

    // ========== VESTING & CLAIM FUNCTIONS ========== //
    
    function claimTokens() external whenVestingStarted {
        _claimTokens(msg.sender);
    }
    
    function _claimTokens(address user) internal {
        UserInfo storage userData = userInfo[user];
        uint256 claimable = getClaimableTokens(user);
        require(claimable > 0, "No tokens available to claim");
        require(nexToken.balanceOf(address(this)) >= claimable, "Insufficient token balance");
        
        userData.totalClaimed += claimable;
        userData.lastClaimTime = block.timestamp;
        
        require(nexToken.transfer(user, claimable), "Token transfer failed");
        emit TokensClaimed(user, claimable);
    }
    
    function getClaimableTokens(address userAddress) public view returns (uint256) {
        UserInfo memory user = userInfo[userAddress];
        
        if (!vestingStarted || user.totalAllocation == 0) {
            return 0;
        }
        
        if (block.timestamp < vestingStartTime) {
            return 0;
        }
        
        uint256 totalTimePassed = block.timestamp - vestingStartTime;
        uint256 totalAllocationWithBonus = user.totalAllocation + user.referralBonus;
        
        if (totalTimePassed >= VESTING_DURATION) {
            return totalAllocationWithBonus - user.totalClaimed;
        } else {
            uint256 totalVested = (totalAllocationWithBonus * totalTimePassed) / VESTING_DURATION;
            return totalVested > user.totalClaimed ? totalVested - user.totalClaimed : 0;
        }
    }

    // ========== STAKING FUNCTIONS ========== //
    
    function stakeTokens(uint256 amount, StakingPeriod period) external whenVestingStarted {
        require(amount >= MIN_STAKING_AMOUNT, "Below minimum staking amount");
        require(amount <= MAX_STAKING_AMOUNT, "Exceeds maximum staking amount per stake");
        require(stakingPlans[period].active, "Staking plan not active");
        
        uint256 claimable = getClaimableTokens(msg.sender);
        require(claimable >= amount, "Insufficient claimable tokens");
        
        if (claimable > 0) {
            _claimTokens(msg.sender);
        }
        
        require(nexToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        StakingPlan memory plan = stakingPlans[period];
        UserStake memory newStake = UserStake({
            amount: amount,
            startTime: block.timestamp,
            endTime: block.timestamp + plan.duration,
            period: period,
            rewardsClaimed: 0,
            active: true
        });
        
        userStakes[msg.sender].push(newStake);
        totalStaked += amount;
        
        emit Staked(msg.sender, amount, period);
    }
    
    function unstakeTokens(uint256 stakeIndex) external {
        require(stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        UserStake storage stake = userStakes[msg.sender][stakeIndex];
        require(stake.active, "Stake not active");
        require(block.timestamp >= stake.endTime, "Staking period not ended");
        
        uint256 reward = calculateStakingReward(msg.sender, stakeIndex);
        uint256 totalAmount = stake.amount + reward;
        
        stake.active = false;
        totalStaked -= stake.amount;
        totalStakingRewards += reward;
        
        require(nexToken.transfer(msg.sender, totalAmount), "Transfer failed");
        
        emit Unstaked(msg.sender, totalAmount, reward);
    }
    
    function emergencyUnstake(uint256 stakeIndex) external {
        require(stakeIndex < userStakes[msg.sender].length, "Invalid stake index");
        
        UserStake storage stake = userStakes[msg.sender][stakeIndex];
        require(stake.active, "Stake not active");
        
        uint256 penalty = stake.amount / 2;
        uint256 returnAmount = stake.amount - penalty;
        
        stake.active = false;
        totalStaked -= stake.amount;
        
        require(nexToken.transfer(msg.sender, returnAmount), "Transfer failed");
        
        emit EmergencyUnstaked(msg.sender, returnAmount, penalty);
    }
    
    function calculateStakingReward(address user, uint256 stakeIndex) public view returns (uint256) {
        require(stakeIndex < userStakes[user].length, "Invalid stake index");
        
        UserStake memory stake = userStakes[user][stakeIndex];
        if (!stake.active) return 0;
        
        StakingPlan memory plan = stakingPlans[stake.period];
        
        uint256 calculationTime = block.timestamp > stake.endTime ? stake.endTime : block.timestamp;
        uint256 stakingDuration = calculationTime - stake.startTime;
        
        uint256 annualReward = (stake.amount * plan.apy) / 10000;
        uint256 reward = (annualReward * stakingDuration) / 365 days;
        
        return reward - stake.rewardsClaimed;
    }

    // ========== ADMIN FUNCTIONS ========== //
    
    function startPresale(uint256 durationInDays) external onlyOwner {
        require(!presaleActive, "Presale already active");
        require(nexToken.balanceOf(address(this)) >= PRESALE_SUPPLY, "Insufficient token balance");
        
        startTime = block.timestamp;
        endTime = block.timestamp + (durationInDays * 1 days);
        presaleActive = true;
        
        emit PresaleStarted(startTime, endTime);
    }
    
    function endPresaleAndStartVesting() external onlyOwner {
        require(presaleActive, "Presale not active");
        
        presaleActive = false;
        endTime = block.timestamp;
        vestingStartTime = block.timestamp + VESTING_START_DELAY;
        vestingStarted = true;
        
        uint256 totalRaisedUSDTValue = totalRaisedUSDT + (totalRaisedNative * TOKEN_PRICE_NATIVE / 10**18);
        
        emit PresaleEnded(endTime, totalRaisedUSDTValue);
        emit VestingStarted(vestingStartTime);
    }
    
    function withdrawFunds(address tokenAddress, uint256 amount) external onlyOwner {
        require(!presaleActive, "Presale still active");
        
        if (tokenAddress == address(0)) {
            uint256 balance = address(this).balance;
            require(amount <= balance, "Insufficient balance");
            (bool success, ) = payable(owner).call{value: amount}("");
            require(success, "Transfer failed");
        } else {
            require(IERC20(tokenAddress).transfer(owner, amount), "Token transfer failed");
        }
        
        emit FundsWithdrawn(owner, amount);
    }
    
    function updateStakingPlan(StakingPeriod period, uint256 apy, bool active) external onlyOwner {
        stakingPlans[period].apy = apy;
        stakingPlans[period].active = active;
    }

    // ========== VIEW FUNCTIONS YANG DIOPTIMALKAN ========== //
    
    // Fungsi getUserInfo yang dipecah menjadi beberapa fungsi kecil
    function getUserBasicInfo(address user) public view returns (
        uint256 totalAllocation,
        uint256 totalClaimed,
        uint256 claimableNow
    ) {
        UserInfo memory userData = userInfo[user];
        totalAllocation = userData.totalAllocation + userData.referralBonus;
        totalClaimed = userData.totalClaimed;
        claimableNow = getClaimableTokens(user);
    }
    
    function getUserBonusInfo(address user) public view returns (
        uint256 bonusAllocation,
        uint256 referralBonus,
        Tier tier
    ) {
        UserInfo memory userData = userInfo[user];
        bonusAllocation = userData.bonusAllocation;
        referralBonus = userData.referralBonus;
        tier = userTier[user];
    }
    
    function getUserContributionInfo(address user) public view returns (
        uint256 totalContributionUSDT,
        uint256 totalContributionNative
    ) {
        UserInfo memory userData = userInfo[user];
        totalContributionUSDT = userData.totalContributionUSDT;
        totalContributionNative = userData.totalContributionNative;
    }
    
    function getPresaleProgress() public view returns (uint256 soldPercent, uint256 raisedUSDT) {
        if (PRESALE_SUPPLY == 0) return (0, 0);
        soldPercent = (totalSold * 100) / PRESALE_SUPPLY;
        raisedUSDT = totalRaisedUSDT + (totalRaisedNative * TOKEN_PRICE_NATIVE / 10**18);
    }
    
    function getTimeRemaining() public view returns (uint256 daysLeft, uint256 hoursLeft) {
        if (block.timestamp >= endTime) return (0, 0);
        uint256 timeLeft = endTime - block.timestamp;
        daysLeft = timeLeft / 1 days;
        hoursLeft = (timeLeft % 1 days) / 1 hours;
    }
    
    function getTokenAmount(uint256 paymentAmount, bool isNative) public pure returns (uint256) {
        if (isNative) {
            require(paymentAmount >= MIN_BUY_NATIVE && paymentAmount <= MAX_BUY_NATIVE, "Invalid native amount");
            return (paymentAmount * 10**18) / TOKEN_PRICE_NATIVE;
        } else {
            require(paymentAmount >= MIN_BUY_USDT && paymentAmount <= MAX_BUY_USDT, "Invalid USDT amount");
            return (paymentAmount * 10**18) / TOKEN_PRICE_USDT;
        }
    }
    
    function getStakingAPY(StakingPeriod period) public view returns (uint256) {
        return stakingPlans[period].apy / 100;
    }
    
    function getTotalUserStaked(address user) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < userStakes[user].length; i++) {
            if (userStakes[user][i].active) {
                total += userStakes[user][i].amount;
            }
        }
        return total;
    }

    // ========== FALLBACK & RECOVERY ========== //
    
    receive() external payable {
        if (presaleActive) {
            this.buyWithNative{value: msg.value}(address(0));
        }
    }
    
    function recoverERC20(address tokenAddress, uint256 amount) external onlyOwner {
        require(tokenAddress != address(nexToken), "Cannot recover NEX token");
        require(IERC20(tokenAddress).transfer(owner, amount), "Transfer failed");
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        owner = newOwner;
    }
}