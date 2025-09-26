// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Splash (SPX) - ERC20 fixed supply with non-blocking anti-bot monitoring
/// @notice Fixed supply ERC20 token. No mint after deployment. Anti-bot feature only emits events / keeps counters (does NOT block transactions).
contract SPLASH {
    // ERC20 metadata
    string public constant name = "Splash";
    string public constant symbol = "SPX";
    uint8 public constant decimals = 18;

    // Fixed total supply: 21,000,000 * 10^18
    uint256 public constant TOTAL_SUPPLY = 21_000_000 * (10 ** uint256(decimals));

    // Balances and allowances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Ownership (simple)
    address public owner;

    // Anti-bot (monitoring only) - owner may set window (in blocks) and start launch
    uint256 public antiSniperBlocks = 0; // number of blocks after launch considered "launch window"
    uint256 public launchBlock = 0;      // block number set by owner when starting launch; zero means not set

    // Counters to help monitoring (public read)
    // counts how many transfers an address received during the launch window (if launch started)
    mapping(address => uint256) public launchWindowReceivedCount;
    // counts how many transfers an address sent during the launch window
    mapping(address => uint256) public launchWindowSentCount;
    // Total transfers observed during launch window
    uint256 public launchWindowTotalTransfers;

    // ERC20 events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed ownerAddr, address indexed spender, uint256 value);

    // Ownership events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // Anti-bot monitoring event (does NOT block)
    event LaunchWindowTransferObserved(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 blockNumber
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "MUSE: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        _balances[msg.sender] = TOTAL_SUPPLY;
        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ===== ERC20 standard functions =====

    function totalSupply() external pure returns (uint256) {
        return TOTAL_SUPPLY;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address holder, address spender) external view returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        require(allowed >= amount, "MUSE: allowance exceeded");
        _allowances[from][msg.sender] = allowed - amount;
        _transfer(from, to, amount);
        return true;
    }

    // Internal transfer: contains only monitoring logic for anti-bot (no blocking)
    function _transfer(address from, address to, uint256 amount) internal {
        require(from != address(0), "MUSE: transfer from zero");
        require(to != address(0), "MUSE: transfer to zero");
        require(_balances[from] >= amount, "MUSE: balance too low");

        // Update balances
        _balances[from] -= amount;
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        // If launch is active and within antiSniperBlocks window, log / count but DO NOT block
        if (launchBlock != 0 && block.number <= launchBlock + antiSniperBlocks) {
            // increment monitoring counters
            launchWindowSentCount[from] += 1;
            launchWindowReceivedCount[to] += 1;
            launchWindowTotalTransfers += 1;

            // Emit monitoring event (for off-chain observers)
            emit LaunchWindowTransferObserved(from, to, amount, block.number);
        }
    }

    // ===== Owner controls (safe / minimal powers) =====

    /// @notice Owner can set how many blocks after launch count as the "launch window" for monitoring
    /// @param blocks Number of blocks for monitoring window. Can be changed by owner.
    function setAntiSniperBlocks(uint256 blocks) external onlyOwner {
        antiSniperBlocks = blocks;
    }

    /// @notice Owner starts the launch monitoring by setting launchBlock = current block. Can be called once or multiple times (resets window).
    function startLaunch() external onlyOwner {
        launchBlock = block.number;
    }

    /// @notice Transfer ownership to newOwner. newOwner cannot be zero address.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "MUSE: new owner zero");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    /// @notice Renounce ownership (make owner = zero). After this call, owner-only functions cannot be executed.
    function renounceOwnership() external onlyOwner {
        address prev = owner;
        owner = address(0);
        emit OwnershipTransferred(prev, address(0));
    }

    /// @notice Rescue ERC20 tokens accidentally sent to this contract (NOT MUSE itself).
    /// @param tokenAddress token contract to rescue
    /// @param to recipient
    /// @param amount amount to rescue
    function rescueERC20(address tokenAddress, address to, uint256 amount) external onlyOwner {
        require(tokenAddress != address(this), "MUSE: cannot rescue this token");
        require(to != address(0), "MUSE: rescue to zero");
        // low-level call to be generic; expect standard ERC20 return behavior
        (bool success, bytes memory data) = tokenAddress.call(
            abi.encodeWithSelector(bytes4(keccak256("transfer(address,uint256)")), to, amount)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))), "MUSE: rescue failed");
    }

    // ===== View helpers =====

    /// @notice Returns whether current block is in launch monitoring window.
    function isInLaunchWindow() external view returns (bool) {
        return (launchBlock != 0 && block.number <= launchBlock + antiSniperBlocks);
    }
}
