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

contract HybridDividendToken is IERC20 {
    string public constant name = "Hybrid Deviden Token";
    string public constant symbol = "HDX";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 10_000_000 * 10**decimals;
    
    // Dividen configuration
    uint256 public constant APY = 1200; // 12% dalam basis points
    uint256 public constant MIN_HOLD_DURATION = 30 days;
    uint256 public constant DIVIDEND_DAY = 1; // Tanggal 1 setiap bulan
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public lastHoldStart;
    mapping(address => bool) public hasEverHeld;
    
    address public owner;
    uint256 public lastDistributionDate;
    
    event DividendsDistributed(address indexed holder, uint256 amount);
    event NativeTokensReceived(address indexed from, uint256 amount);
    event TokensReceived(address indexed token, address indexed from, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        _balances[owner] = totalSupply;
        lastDistributionDate = _getNextDistributionDate(block.timestamp);
        emit Transfer(address(0), owner, totalSupply);
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }
    
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        // Update holding periods
        _updateHoldStatus(from);
        _updateHoldStatus(to);
        
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        // Set hold start time for new holders
        if (!hasEverHeld[to] && _balances[to] > 0) {
            lastHoldStart[to] = block.timestamp;
            hasEverHeld[to] = true;
        }
        
        emit Transfer(from, to, amount);
        
        // Check and execute dividend distribution if it's distribution day
        _checkAndDistributeDividends();
    }
    
    function _updateHoldStatus(address account) internal {
        if (_balances[account] == 0 && hasEverHeld[account]) {
            lastHoldStart[account] = 0;
        }
    }
    
    function _checkAndDistributeDividends() internal {
        if (block.timestamp >= lastDistributionDate) {
            _distributeDividends();
            lastDistributionDate = _getNextDistributionDate(lastDistributionDate);
        }
    }
    
    function _distributeDividends() internal {
        uint256 contractBalance = address(this).balance;
        if (contractBalance == 0) return;
        
        uint256 totalEligibleSupply = _calculateEligibleSupply();
        if (totalEligibleSupply == 0) return;
        
        for (uint256 i = 0; i < _getHolderCount(); i++) {
            address holder = _getHolder(i);
            if (_isEligibleForDividends(holder)) {
                uint256 holderBalance = _balances[holder];
                uint256 dividendShare = (holderBalance * contractBalance) / totalEligibleSupply;
                uint256 annualDividend = (holderBalance * APY) / 10000;
                uint256 monthlyDividend = annualDividend / 12;
                
                uint256 actualDividend = monthlyDividend < dividendShare ? monthlyDividend : dividendShare;
                
                if (actualDividend > 0 && address(this).balance >= actualDividend) {
                    payable(holder).transfer(actualDividend);
                    emit DividendsDistributed(holder, actualDividend);
                }
            }
        }
    }
    
    function _calculateEligibleSupply() internal view returns (uint256) {
        uint256 eligibleSupply = 0;
        for (uint256 i = 0; i < _getHolderCount(); i++) {
            address holder = _getHolder(i);
            if (_isEligibleForDividends(holder)) {
                eligibleSupply += _balances[holder];
            }
        }
        return eligibleSupply;
    }
    
    function _isEligibleForDividends(address holder) internal view returns (bool) {
        return hasEverHeld[holder] && 
               lastHoldStart[holder] > 0 && 
               block.timestamp >= lastHoldStart[holder] + MIN_HOLD_DURATION &&
               _balances[holder] > 0;
    }
    
    function _getNextDistributionDate(uint256 fromDate) internal pure returns (uint256) {
        (uint256 year, uint256 month, ) = _daysToDate(fromDate / 1 days);
        uint256 nextMonth = month + 1;
        uint256 nextYear = year;
        if (nextMonth > 12) {
            nextMonth = 1;
            nextYear += 1;
        }
        return _dateToDays(nextYear, nextMonth, DIVIDEND_DAY) * 1 days;
    }
    
    function _daysToDate(uint256 _days) internal pure returns (uint256 year, uint256 month, uint256 day) {
        int256 __days = int256(_days);
        int256 L = __days + 68569 + 2440588; // 2440588 is the Julian day number for 1970-01-01
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        int256 _day = L - (2447 * _month) / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;
        
        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
    }
    
    function _dateToDays(uint256 year, uint256 month, uint256 day) internal pure returns (uint256 _days) {
        int256 _year = int256(year);
        int256 _month = int256(month);
        int256 _day = int256(day);
        
        int256 __days = _day - 32075 + (1461 * (_year + 4800 + (_month - 14) / 12)) / 4
            + (367 * (_month - 2 - ((_month - 14) / 12) * 12)) / 12
            - (3 * ((_year + 4900 + (_month - 14) / 12) / 100)) / 4 - 2440588;
        
        _days = uint256(__days);
    }
    
    // Simplified holder management (in production, use more efficient data structures)
    address[] private holders;
    mapping(address => bool) private isHolder;
    
    function _getHolderCount() internal view returns (uint256) {
        return holders.length;
    }
    
    function _getHolder(uint256 index) internal view returns (address) {
        require(index < holders.length, "Index out of bounds");
        return holders[index];
    }
    
    function _addHolder(address holder) internal {
        if (!isHolder[holder] && _balances[holder] > 0) {
            holders.push(holder);
            isHolder[holder] = true;
        }
    }
    
    function _removeHolder(address holder) internal {
        if (isHolder[holder] && _balances[holder] == 0) {
            for (uint256 i = 0; i < holders.length; i++) {
                if (holders[i] == holder) {
                    holders[i] = holders[holders.length - 1];
                    holders.pop();
                    isHolder[holder] = false;
                    break;
                }
            }
        }
    }
    
    function _approve(address _owner, address spender, uint256 amount) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[_owner][spender] = amount;
        emit Approval(_owner, spender, amount);
    }
    
    function _spendAllowance(address _owner, address spender, uint256 amount) internal {
        uint256 currentAllowance = allowance(_owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(_owner, spender, currentAllowance - amount);
            }
        }
    }
    
    // Fungsi untuk menerima ETH (native tokens)
    receive() external payable {
        emit NativeTokensReceived(msg.sender, msg.value);
    }
    
    // Fungsi untuk menerima ERC20 tokens
    function receiveTokens(address tokenAddress, uint256 amount) external {
        IERC20 token = IERC20(tokenAddress);
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        emit TokensReceived(tokenAddress, msg.sender, amount);
    }
    
    // Owner functions untuk management
    function withdrawNativeTokens(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(owner).transfer(amount);
    }
    
    function withdrawERC20Tokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(owner, amount), "Token transfer failed");
    }
    
    function getHoldTime(address account) public view returns (uint256) {
        if (lastHoldStart[account] == 0) return 0;
        return block.timestamp - lastHoldStart[account];
    }
    
    function isEligibleForDividends(address account) public view returns (bool) {
        return _isEligibleForDividends(account);
    }
    
    function nextDistributionDate() public view returns (uint256) {
        return lastDistributionDate;
    }
}