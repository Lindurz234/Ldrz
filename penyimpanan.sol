// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title Treasury - simple token/ETH vault for holding and sending ERC20 tokens (and ETH)
/// @notice Owner/Operators can move tokens out, approve spenders (e.g. DEX router), and perform batch transfers.
/// @dev Includes a small SafeERC20 helper to handle tokens that don't return boolean.
contract Treasury {
    // --- Events ---
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event OperatorAdded(address indexed operator);
    event OperatorRemoved(address indexed operator);
    event TokenWithdrawn(address indexed token, address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed to, uint256 amount);
    event TokenApproved(address indexed token, address indexed spender, uint256 amount);
    event BatchTransfer(address indexed token, uint256 totalRecipients);
    event ExecutedCall(address indexed target, uint256 value, bytes data, bytes result);
    event ReceivedETH(address indexed sender, uint256 amount);

    // --- State ---
    address public owner;
    mapping(address => bool) public operators;

    // --- Modifiers ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Treasury: caller is not owner");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || operators[msg.sender], "Treasury: not authorized");
        _;
    }

    constructor(address[] memory _operators) {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
        // set initial operators (optional)
        for (uint256 i = 0; i < _operators.length; i++) {
            if (_operators[i] != address(0)) {
                operators[_operators[i]] = true;
                emit OperatorAdded(_operators[i]);
            }
        }
    }

    // --- Ownership / operator management ---
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Treasury: new owner zero");
        address prev = owner;
        owner = newOwner;
        emit OwnershipTransferred(prev, newOwner);
    }

    function addOperator(address op) external onlyOwner {
        require(op != address(0), "Treasury: op zero");
        operators[op] = true;
        emit OperatorAdded(op);
    }

    function removeOperator(address op) external onlyOwner {
        require(operators[op], "Treasury: not operator");
        operators[op] = false;
        emit OperatorRemoved(op);
    }

    // --- Receive ETH ---
    receive() external payable {
        emit ReceivedETH(msg.sender, msg.value);
    }

    // --- ERC20 interface minimal ---
    interface IERC20 {
        function totalSupply() external view returns (uint256);
        function balanceOf(address account) external view returns (uint256);
        function transfer(address to, uint256 amount) external returns (bool);
        function allowance(address owner, address spender) external view returns (uint256);
        function approve(address spender, uint256 amount) external returns (bool);
        function transferFrom(address from, address to, uint256 amount) external returns (bool);
    }

    // --- SafeERC20 helpers (internal) ---
    function _safeApprove(address token, address spender, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(IERC20.approve.selector, spender, amount);
        (bool ok, bytes memory ret) = token.call(data);
        require(ok && _checkReturnBool(ret), "Treasury: approve failed");
    }

    function _safeTransfer(address token, address to, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(IERC20.transfer.selector, to, amount);
        (bool ok, bytes memory ret) = token.call(data);
        require(ok && _checkReturnBool(ret), "Treasury: transfer failed");
    }

    function _safeTransferFrom(address token, address from, address to, uint256 amount) internal {
        bytes memory data = abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount);
        (bool ok, bytes memory ret) = token.call(data);
        require(ok && _checkReturnBool(ret), "Treasury: transferFrom failed");
    }

    // Return data may be empty (non-standard tokens) or boolean true. Accept both.
    function _checkReturnBool(bytes memory ret) private pure returns (bool) {
        if (ret.length == 0) {
            return true;
        }
        if (ret.length == 32) {
            uint256 v = abi.decode(ret, (uint256));
            return v != 0;
        }
        if (ret.length == 1) {
            uint8 v = abi.decode(ret, (uint8));
            return v != 0;
        }
        return false;
    }

    // --- Core functionality ---

    /// @notice Withdraw an ERC20 token from treasury to a recipient
    /// @param token address of ERC20 token contract
    /// @param to recipient
    /// @param amount amount (in token decimals)
    function withdrawToken(address token, address to, uint256 amount) external onlyAuthorized {
        require(to != address(0), "Treasury: to zero");
        require(amount > 0, "Treasury: zero amount");
        _safeTransfer(token, to, amount);
        emit TokenWithdrawn(token, to, amount);
    }

    /// @notice Approve a spender to spend tokens from this treasury (useful for DEX router approvals)
    /// @param token token address
    /// @param spender spender address (e.g., router)
    /// @param amount amount to approve
    function approveToken(address token, address spender, uint256 amount) external onlyAuthorized {
        require(spender != address(0), "Treasury: spender zero");
        _safeApprove(token, spender, amount);
        emit TokenApproved(token, spender, amount);
    }

    /// @notice Batch transfer tokens to multiple recipients
    /// @param token token address
    /// @param recipients array of recipient addresses
    /// @param amounts array of amounts corresponding to recipients
    function batchTransfer(address token, address[] calldata recipients, uint256[] calldata amounts) external onlyAuthorized {
        require(recipients.length == amounts.length, "Treasury: length mismatch");
        uint256 len = recipients.length;
        require(len > 0, "Treasury: empty");
        for (uint256 i = 0; i < len; i++) {
            address to = recipients[i];
            uint256 amt = amounts[i];
            require(to != address(0), "Treasury: to zero in batch");
            require(amt > 0, "Treasury: zero amount in batch");
            _safeTransfer(token, to, amt);
        }
        emit BatchTransfer(token, len);
    }

    /// @notice Withdraw ETH from contract
    /// @param to recipient
    /// @param amount in wei
    function withdrawETH(address payable to, uint256 amount) external onlyAuthorized {
        require(to != address(0), "Treasury: to zero");
        require(amount > 0, "Treasury: zero amount");
        require(address(this).balance >= amount, "Treasury: insufficient ETH");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Treasury: ETH transfer failed");
        emit ETHWithdrawn(to, amount);
    }

    /// @notice Rescue arbitrary ERC20 tokens accidentally sent to this contract (alias to withdrawToken for owner/operator)
    /// @param token token address
    /// @param to recipient
    /// @param amount amount
    function rescueERC20(address token, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "Treasury: to zero");
        require(amount > 0, "Treasury: zero amount");
        _safeTransfer(token, to, amount);
        emit TokenWithdrawn(token, to, amount);
    }

    /// @notice Execute an arbitrary call to a target contract (owner only). Useful to interact with DEX router: addLiquidity, swapExactTokensForTokens, etc.
    /// @dev Very powerful: target call uses provided ETH value and data. Caller must ensure it's safe. Recommend multisig/time-lock for production.
    /// @param target address to call
    /// @param value ETH value in wei to send with call
    /// @param data calldata payload
    function executeCall(address target, uint256 value, bytes calldata data) external onlyOwner returns (bytes memory) {
        require(target != address(0), "Treasury: target zero");
        (bool ok, bytes memory res) = target.call{value: value}(data);
        require(ok, "Treasury: call failed");
        emit ExecutedCall(target, value, data, res);
        return res;
    }

    // --- View helpers ---
    function tokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }
}
