// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract TTAFaucet {
    IERC20 public constant TTA_TOKEN = IERC20(0x742641b0C71E855A86eADC4978699c9d215DED5a);
    
    uint256 public constant CLAIM_AMOUNT = 1000 * 10**18; // 1000 TTA
    uint256 public constant COOLDOWN_PERIOD = 24 hours;
    
    mapping(address => uint256) public lastClaimTime;
    
    event TokensClaimed(address indexed user, uint256 amount, uint256 timestamp);
    
    function claimTokens() external {
        require(block.timestamp >= lastClaimTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown active");
        require(TTA_TOKEN.balanceOf(address(this)) >= CLAIM_AMOUNT, "Faucet empty");
        
        lastClaimTime[msg.sender] = block.timestamp;
        
        bool success = TTA_TOKEN.transfer(msg.sender, CLAIM_AMOUNT);
        require(success, "Transfer failed");
        
        emit TokensClaimed(msg.sender, CLAIM_AMOUNT, block.timestamp);
    }
    
    function getFaucetBalance() external view returns (uint256) {
        return TTA_TOKEN.balanceOf(address(this));
    }
    
    function canUserClaim(address user) external view returns (bool) {
        return block.timestamp >= lastClaimTime[user] + COOLDOWN_PERIOD;
    }
    
    function getNextClaimTime(address user) external view returns (uint256) {
        return lastClaimTime[user] + COOLDOWN_PERIOD;
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}