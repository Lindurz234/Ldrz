<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CozySwap Manager</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/5.7.1/ethers.umd.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Arial', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 15px 35px rgba(0,0,0,0.1);
        }
        
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        
        .header h1 {
            color: #333;
            font-size: 32px;
            margin-bottom: 10px;
        }
        
        .section {
            background: #f8f9fa;
            border-radius: 15px;
            padding: 25px;
            margin-bottom: 25px;
            border-left: 5px solid #667eea;
        }
        
        .section h2 {
            color: #333;
            margin-bottom: 20px;
            font-size: 22px;
        }
        
        .input-group {
            margin-bottom: 15px;
        }
        
        .input-group label {
            display: block;
            margin-bottom: 8px;
            font-weight: bold;
            color: #333;
        }
        
        .input-group input {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e5e9;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        .input-group input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        button {
            padding: 15px 25px;
            border: none;
            border-radius: 10px;
            font-size: 16px;
            font-weight: bold;
            cursor: pointer;
            transition: all 0.3s;
            margin: 5px;
        }
        
        .connect-btn {
            background: #28a745;
            color: white;
            width: 100%;
        }
        
        .transfer-btn {
            background: #17a2b8;
            color: white;
        }
        
        .burn-btn {
            background: #dc3545;
            color: white;
        }
        
        .factory-btn {
            background: #6f42c1;
            color: white;
        }
        
        button:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.2);
        }
        
        button:disabled {
            background: #6c757d;
            cursor: not-allowed;
            transform: none;
            box-shadow: none;
        }
        
        .status {
            margin-top: 15px;
            padding: 15px;
            border-radius: 10px;
            text-align: center;
            font-weight: bold;
            display: none;
        }
        
        .success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        
        .error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        
        .info {
            background: #cce7ff;
            color: #004085;
            border: 1px solid #b3d7ff;
        }
        
        .wallet-info {
            background: #e7f3ff;
            border-radius: 10px;
            padding: 15px;
            margin-bottom: 20px;
            display: none;
        }
        
        .info-box {
            background: #fff3cd;
            border-radius: 10px;
            padding: 15px;
            margin: 10px 0;
            border-left: 4px solid #ffc107;
        }
        
        .button-group {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 15px;
        }
        
        .balance-info {
            background: #e7f3ff;
            border-radius: 10px;
            padding: 15px;
            margin: 10px 0;
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏦 CozySwap Manager</h1>
            <p>Transfer dari Treasury • Burn LP • Set feeTo</p>
        </div>

        <!-- Wallet Connection -->
        <div class="section">
            <h2>🔗 Connect Wallet (Plasma Chain 9745)</h2>
            <button class="connect-btn" onclick="connectWallet()" id="connectBtn">Connect MetaMask</button>
            <div class="wallet-info" id="walletInfo">
                <p><strong>Connected:</strong> <span id="walletAddress"></span></p>
                <p><strong>Network:</strong> <span id="networkInfo"></span></p>
                <p><strong>Balance:</strong> <span id="walletBalance"></span> ETH</p>
            </div>
        </div>

        <!-- Treasury Transfer -->
        <div class="section">
            <h2>🏦 Treasury Transfer</h2>
            <div class="info-box">
                <strong>Treasury Address:</strong> 0x1B4f447cFBAE0fdA4d6a1eAAc2bE1e6a008082Cf
            </div>
            
            <div class="input-group">
                <label for="tokenAddress">Token Address (ERC20):</label>
                <input type="text" id="tokenAddress" placeholder="0x...">
            </div>
            
            <div class="input-group">
                <label for="recipientAddress">Recipient Wallet Address:</label>
                <input type="text" id="recipientAddress" placeholder="0x...">
            </div>
            
            <div class="input-group">
                <label for="tokenAmount">Amount to Send:</label>
                <input type="text" id="tokenAmount" placeholder="0.0">
            </div>

            <div class="button-group">
                <button class="transfer-btn" onclick="sendToken()" id="sendTokenBtn" disabled>Send Token</button>
                <button class="transfer-btn" onclick="sendEther()" id="sendEtherBtn" disabled>Send ETH</button>
                <button class="transfer-btn" onclick="checkTreasuryBalance()" id="checkTreasuryBtn" disabled>Check Treasury Balance</button>
            </div>

            <div class="balance-info" id="treasuryBalanceInfo">
                <h4>📊 Treasury Balances</h4>
                <p><strong>ETH Balance:</strong> <span id="treasuryETH">0</span></p>
                <p><strong>Token Balance:</strong> <span id="treasuryToken">0</span></p>
            </div>
        </div>

        <!-- LP Token Burning -->
        <div class="section">
            <h2>🔥 Burn LP Tokens via Router</h2>
            <div class="info-box">
                <strong>Router Address:</strong> 0x89E695B38610e78a77Fb310458Dfd855505AD239
            </div>
            
            <div class="input-group">
                <label for="pairAddressBurn">Pair Contract Address:</label>
                <input type="text" id="pairAddressBurn" placeholder="0x...">
            </div>
            
            <div class="button-group">
                <button class="burn-btn" onclick="checkLPBalance()" id="checkBalanceBtn" disabled>Check LP Balance</button>
                <button class="burn-btn" onclick="removeLiquidity()" id="removeLiqBtn" disabled>Remove Liquidity</button>
            </div>
            
            <div class="balance-info" id="lpBalanceInfo">
                <h4>📊 LP Token Info</h4>
                <p><strong>Your LP Balance:</strong> <span id="lpBalance">0</span></p>
                <p><strong>Token0:</strong> <span id="token0Address">-</span></p>
                <p><strong>Token1:</strong> <span id="token1Address">-</span></p>
            </div>
        </div>

        <!-- Factory Management -->
        <div class="section">
            <h2>🏭 Factory Management</h2>
            <div class="info-box">
                <strong>Factory Address:</strong> 0xa252e44D3478CeBb1a3D59C9146CD860cb09Ec93
            </div>
            
            <div class="input-group">
                <label for="newFeeTo">New feeTo Address:</label>
                <input type="text" id="newFeeTo" placeholder="0x...">
            </div>

            <div class="button-group">
                <button class="factory-btn" onclick="setFeeTo()" id="setFeeToBtn" disabled>Set feeTo</button>
                <button class="factory-btn" onclick="getFeeTo()" id="getFeeToBtn" disabled>Get Current feeTo</button>
            </div>
            
            <div class="balance-info" id="feeToInfo">
                <h4>🏭 Factory Info</h4>
                <p><strong>Current feeTo:</strong> <span id="currentFeeTo"></span></p>
                <p><strong>feeToSetter:</strong> <span id="feeToSetter"></span></p>
            </div>
        </div>

        <!-- Status Messages -->
        <div class="status" id="statusMessage"></div>
    </div>

    <script>
        let provider, signer, userAddress;
        
        // Contract Addresses
        const TREASURY_ADDRESS = "0x1B4f447cFBAE0fdA4d6a1eAAc2bE1e6a008082Cf";
        const FACTORY_ADDRESS = "0xa252e44D3478CeBb1a3D59C9146CD860cb09Ec93";
        const ROUTER_ADDRESS = "0x89E695B38610e78a77Fb310458Dfd855505AD239";
        const PLASMA_CHAIN_ID = "0x2611"; // 9745 in hex

        // Treasury Contract ABI
        const TREASURY_ABI = [
            "function sendToken(address token, address to, uint256 amount) external",
            "function sendEther(address payable to, uint256 amount) external",
            "function owner() external view returns (address)"
        ];
        
        // Router Contract ABI
        const ROUTER_ABI = [
            {
                "inputs": [
                    {"internalType": "address","name": "tokenA","type": "address"},
                    {"internalType": "address","name": "tokenB","type": "address"},
                    {"internalType": "uint256","name": "liquidity","type": "uint256"},
                    {"internalType": "uint256","name": "amountAMin","type": "uint256"},
                    {"internalType": "uint256","name": "amountBMin","type": "uint256"},
                    {"internalType": "address","name": "to","type": "address"},
                    {"internalType": "uint256","name": "deadline","type": "uint256"}
                ],
                "name": "removeLiquidity",
                "outputs": [
                    {"internalType": "uint256","name": "amountA","type": "uint256"},
                    {"internalType": "uint256","name": "amountB","type": "uint256"}
                ],
                "stateMutability": "nonpayable",
                "type": "function"
            }
        ];
        
        // Pair Contract ABI
        const PAIR_ABI = [
            "function balanceOf(address owner) external view returns (uint)",
            "function token0() external view returns (address)",
            "function token1() external view returns (address)",
            "function approve(address spender, uint amount) external returns (bool)"
        ];
        
        // Factory Contract ABI
        const FACTORY_ABI = [
            "function setFeeTo(address _feeTo) external",
            "function feeTo() external view returns (address)",
            "function feeToSetter() external view returns (address)"
        ];

        // ERC20 ABI
        const ERC20_ABI = [
            "function balanceOf(address account) external view returns (uint256)",
            "function decimals() external view returns (uint8)"
        ];

        async function switchToPlasmaNetwork() {
            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: PLASMA_CHAIN_ID }],
                });
                return true;
            } catch (switchError) {
                // Jika network belum ditambahkan
                if (switchError.code === 4902) {
                    try {
                        await window.ethereum.request({
                            method: 'wallet_addEthereumChain',
                            params: [{
                                chainId: PLASMA_CHAIN_ID,
                                chainName: 'Plasma Chain',
                                rpcUrls: ['https://rpc.plasma.dsolutions.mn/'],
                                nativeCurrency: {
                                    name: 'ETH',
                                    symbol: 'ETH',
                                    decimals: 18
                                },
                                blockExplorerUrls: ['https://scan.plasma.dsolutions.mn/']
                            }],
                        });
                        return true;
                    } catch (addError) {
                        console.error('Failed to add network:', addError);
                        return false;
                    }
                }
                return false;
            }
        }

        function showStatus(message, type = 'info') {
            const statusElement = document.getElementById('statusMessage');
            statusElement.textContent = message;
            statusElement.className = 'status ' + type;
            statusElement.style.display = 'block';
        }

        async function connectWallet() {
            try {
                if (!window.ethereum) {
                    showStatus('Please install MetaMask!', 'error');
                    return;
                }

                showStatus('Switching to Plasma Chain...', 'info');
                
                // Switch to Plasma network
                const switched = await switchToPlasmaNetwork();
                if (!switched) {
                    showStatus('Failed to switch to Plasma Chain', 'error');
                    return;
                }

                showStatus('Connecting to wallet...', 'info');
                
                provider = new ethers.providers.Web3Provider(window.ethereum);
                await provider.send("eth_requestAccounts", []);
                signer = provider.getSigner();
                userAddress = await signer.getAddress();
                
                // Get wallet balance
                const balance = await provider.getBalance(userAddress);
                const balanceFormatted = ethers.utils.formatEther(balance);
                
                // Update UI
                document.getElementById('walletAddress').textContent = userAddress;
                document.getElementById('networkInfo').textContent = 'Plasma Chain (9745)';
                document.getElementById('walletBalance').textContent = parseFloat(balanceFormatted).toFixed(4);
                document.getElementById('walletInfo').style.display = 'block';
                
                document.getElementById('connectBtn').disabled = true;
                document.getElementById('connectBtn').textContent = '✅ Connected to Plasma';
                
                // Enable all buttons
                document.getElementById('sendTokenBtn').disabled = false;
                document.getElementById('sendEtherBtn').disabled = false;
                document.getElementById('checkTreasuryBtn').disabled = false;
                document.getElementById('checkBalanceBtn').disabled = false;
                document.getElementById('removeLiqBtn').disabled = false;
                document.getElementById('setFeeToBtn').disabled = false;
                document.getElementById('getFeeToBtn').disabled = false;
                
                // Auto fill recipient with connected wallet
                document.getElementById('recipientAddress').value = userAddress;
                
                showStatus('✅ Wallet connected to Plasma Chain!', 'success');
                
            } catch (error) {
                showStatus('Error connecting wallet: ' + error.message, 'error');
            }
        }

        // Treasury Functions
        async function sendToken() {
            try {
                const tokenAddress = document.getElementById('tokenAddress').value.trim();
                const recipient = document.getElementById('recipientAddress').value.trim();
                const amount = document.getElementById('tokenAmount').value.trim();

                if (!tokenAddress || !recipient || !amount) {
                    showStatus('Please fill all fields', 'error');
                    return;
                }

                showStatus('Sending token from Treasury...', 'info');

                const treasury = new ethers.Contract(TREASURY_ADDRESS, TREASURY_ABI, signer);
                
                // Convert amount to wei (assuming 18 decimals)
                const amountWei = ethers.utils.parseUnits(amount, 18);
                
                const tx = await treasury.sendToken(tokenAddress, recipient, amountWei);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('✅ Token sent successfully from Treasury!', 'success');

            } catch (error) {
                showStatus('Error sending token: ' + error.message, 'error');
            }
        }

        async function sendEther() {
            try {
                const recipient = document.getElementById('recipientAddress').value.trim();
                const amount = document.getElementById('tokenAmount').value.trim();

                if (!recipient || !amount) {
                    showStatus('Please fill all fields', 'error');
                    return;
                }

                showStatus('Sending ETH from Treasury...', 'info');

                const treasury = new ethers.Contract(TREASURY_ADDRESS, TREASURY_ABI, signer);
                const amountWei = ethers.utils.parseEther(amount);
                
                const tx = await treasury.sendEther(recipient, amountWei);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('✅ ETH sent successfully from Treasury!', 'success');

            } catch (error) {
                showStatus('Error sending ETH: ' + error.message, 'error');
            }
        }

        async function checkTreasuryBalance() {
            try {
                showStatus('Checking Treasury balances...', 'info');

                // Check ETH balance
                const ethBalance = await provider.getBalance(TREASURY_ADDRESS);
                const ethFormatted = ethers.utils.formatEther(ethBalance);

                // Check token balance if address provided
                const tokenAddress = document.getElementById('tokenAddress').value.trim();
                let tokenBalance = '0';
                
                if (tokenAddress && ethers.utils.isAddress(tokenAddress)) {
                    const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
                    const balance = await tokenContract.balanceOf(TREASURY_ADDRESS);
                    const decimals = await tokenContract.decimals();
                    tokenBalance = ethers.utils.formatUnits(balance, decimals);
                }

                document.getElementById('treasuryETH').textContent = parseFloat(ethFormatted).toFixed(4) + ' ETH';
                document.getElementById('treasuryToken').textContent = tokenBalance;
                document.getElementById('treasuryBalanceInfo').style.display = 'block';

                showStatus('✅ Treasury balances retrieved!', 'success');

            } catch (error) {
                showStatus('Error checking Treasury balance: ' + error.message, 'error');
            }
        }

        // LP Burning Functions
        async function checkLPBalance() {
            try {
                const pairAddress = document.getElementById('pairAddressBurn').value.trim();

                if (!pairAddress) {
                    showStatus('Please enter Pair Address', 'error');
                    return;
                }

                showStatus('Checking LP balance...', 'info');

                const pairContract = new ethers.Contract(pairAddress, PAIR_ABI, provider);
                const [balance, token0, token1] = await Promise.all([
                    pairContract.balanceOf(userAddress),
                    pairContract.token0(),
                    pairContract.token1()
                ]);

                const balanceFormatted = ethers.utils.formatUnits(balance, 18);

                document.getElementById('lpBalance').textContent = balanceFormatted;
                document.getElementById('token0Address').textContent = token0.substring(0, 10) + '...';
                document.getElementById('token1Address').textContent = token1.substring(0, 10) + '...';
                document.getElementById('lpBalanceInfo').style.display = 'block';

                if (balance.gt(0)) {
                    showStatus(`✅ Found ${balanceFormatted} LP tokens!`, 'success');
                } else {
                    showStatus('No LP tokens found in your wallet', 'info');
                }

            } catch (error) {
                showStatus('Error checking LP balance: ' + error.message, 'error');
            }
        }

        async function removeLiquidity() {
            try {
                const pairAddress = document.getElementById('pairAddressBurn').value.trim();

                if (!pairAddress) {
                    showStatus('Please enter Pair Address', 'error');
                    return;
                }

                showStatus('Removing liquidity via Router...', 'info');

                const pairContract = new ethers.Contract(pairAddress, PAIR_ABI, provider);
                const routerContract = new ethers.Contract(ROUTER_ADDRESS, ROUTER_ABI, signer);

                // Get pair info
                const [balance, token0, token1] = await Promise.all([
                    pairContract.balanceOf(userAddress),
                    pairContract.token0(),
                    pairContract.token1()
                ]);

                if (balance.eq(0)) {
                    showStatus('No LP tokens to remove', 'error');
                    return;
                }

                // Approve LP tokens to router
                const approveTx = await pairContract.approve(ROUTER_ADDRESS, balance);
                await approveTx.wait();

                showStatus('Approval confirmed, removing liquidity...', 'info');

                // Remove liquidity
                const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes
                const tx = await routerContract.removeLiquidity(
                    token0,
                    token1,
                    balance,
                    0, // amountAMin
                    0, // amountBMin
                    userAddress,
                    deadline,
                    { gasLimit: 400000 }
                );

                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                const receipt = await tx.wait();
                showStatus('✅ Liquidity removed successfully!', 'success');

                // Update balance
                checkLPBalance();

            } catch (error) {
                showStatus('Error removing liquidity: ' + error.message, 'error');
            }
        }

        // Factory Functions
        async function setFeeTo() {
            try {
                const newFeeTo = document.getElementById('newFeeTo').value.trim();

                if (!newFeeTo) {
                    showStatus('Please enter feeTo address', 'error');
                    return;
                }

                if (!ethers.utils.isAddress(newFeeTo)) {
                    showStatus('Invalid feeTo address', 'error');
                    return;
                }

                showStatus('Setting new feeTo...', 'info');

                const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, signer);
                const tx = await factory.setFeeTo(newFeeTo);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('✅ feeTo updated successfully!', 'success');

            } catch (error) {
                showStatus('Error setting feeTo: ' + error.message, 'error');
            }
        }

        async function getFeeTo() {
            try {
                showStatus('Getting factory info...', 'info');

                const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, provider);
                const [currentFeeTo, feeToSetter] = await Promise.all([
                    factory.feeTo(),
                    factory.feeToSetter()
                ]);

                document.getElementById('currentFeeTo').textContent = currentFeeTo;
                document.getElementById('feeToSetter').textContent = feeToSetter;
                document.getElementById('feeToInfo').style.display = 'block';
                
                showStatus('✅ Factory info retrieved!', 'success');

            } catch (error) {
                showStatus('Error getting factory info: ' + error.message, 'error');
            }
        }

        // Auto connect
        window.addEventListener('load', function() {
            if (window.ethereum) {
                connectWallet();
            }
        });

        showStatus('Connect wallet to start managing CozySwap', 'info');
    </script>
</body>
</html>