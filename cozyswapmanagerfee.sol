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
        
        .input-group input, .input-group textarea {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e1e5e9;
            border-radius: 10px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        
        .input-group input:focus, .input-group textarea:focus {
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
        
        .loading {
            background: #fff3cd;
            color: #856404;
            border: 1px solid #ffeaa7;
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
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏦 CozySwap Manager</h1>
            <p>Kelola Treasury, Burn LP, dan Ubah feeTo</p>
        </div>

        <!-- Wallet Connection -->
        <div class="section">
            <h2>🔗 Connect Wallet</h2>
            <button class="connect-btn" onclick="connectWallet()" id="connectBtn">Connect MetaMask</button>
            <div class="wallet-info" id="walletInfo">
                <p><strong>Connected:</strong> <span id="walletAddress"></span></p>
                <p><strong>Network:</strong> <span id="networkInfo"></span></p>
            </div>
        </div>

        <!-- Treasury Management -->
        <div class="section">
            <h2>🏦 Treasury Management</h2>
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
            </div>
        </div>

        <!-- LP Token Burning -->
        <div class="section">
            <h2>🔥 Burn LP Tokens</h2>
            <div class="input-group">
                <label for="pairAddressBurn">Pair Contract Address:</label>
                <input type="text" id="pairAddressBurn" placeholder="0x...">
            </div>
            
            <div class="button-group">
                <button class="burn-btn" onclick="checkLPBalance()" id="checkBalanceBtn" disabled>Check LP Balance</button>
                <button class="burn-btn" onclick="burnLPTokens()" id="burnBtn" disabled>Burn LP Tokens</button>
            </div>
            
            <div id="lpBalanceInfo" style="display:none; margin-top:15px; padding:15px; background:#f8f9fa; border-radius:10px;">
                <p><strong>Your LP Balance:</strong> <span id="lpBalance">0</span></p>
            </div>
        </div>

        <!-- Factory Management -->
        <div class="section">
            <h2>🏭 Factory Management</h2>
            <div class="input-group">
                <label for="factoryAddress">Factory Contract Address:</label>
                <input type="text" id="factoryAddress" placeholder="0x...">
            </div>
            
            <div class="input-group">
                <label for="newFeeTo">New feeTo Address:</label>
                <input type="text" id="newFeeTo" placeholder="0x...">
            </div>

            <div class="button-group">
                <button class="factory-btn" onclick="setFeeTo()" id="setFeeToBtn" disabled>Set feeTo</button>
                <button class="factory-btn" onclick="getFeeTo()" id="getFeeToBtn" disabled>Get Current feeTo</button>
            </div>
            
            <div id="feeToInfo" style="display:none; margin-top:15px; padding:15px; background:#f8f9fa; border-radius:10px;">
                <p><strong>Current feeTo:</strong> <span id="currentFeeTo"></span></p>
            </div>
        </div>

        <!-- Status Messages -->
        <div class="status" id="statusMessage"></div>
    </div>

    <script>
        let provider, signer, userAddress;
        
        // Treasury Contract ABI
        const TREASURY_ABI = [
            "function sendToken(address token, address to, uint256 amount) external",
            "function sendEther(address payable to, uint256 amount) external",
            "function owner() external view returns (address)"
        ];
        
        // Pair Contract ABI
        const PAIR_ABI = [
            "function burn(address to) external returns (uint amount0, uint amount1)",
            "function balanceOf(address owner) external view returns (uint)"
        ];
        
        // Factory Contract ABI
        const FACTORY_ABI = [
            "function setFeeTo(address _feeTo) external",
            "function feeTo() external view returns (address)",
            "function feeToSetter() external view returns (address)"
        ];

        // Default addresses
        const TREASURY_ADDRESS = "0x1B4f447cFBAE0fdA4d6a1eAAc2bE1e6a008082Cf";

        function showStatus(message, type = 'info') {
            const statusElement = document.getElementById('statusMessage');
            statusElement.textContent = message;
            statusElement.className = 'status ' + type;
            statusElement.style.display = 'block';
            
            // Auto hide success messages after 10 seconds
            if (type === 'success') {
                setTimeout(() => {
                    statusElement.style.display = 'none';
                }, 10000);
            }
        }

        async function connectWallet() {
            try {
                if (!window.ethereum) {
                    showStatus('Please install MetaMask!', 'error');
                    return;
                }

                showStatus('Connecting to wallet...', 'loading');
                
                provider = new ethers.providers.Web3Provider(window.ethereum);
                await provider.send("eth_requestAccounts", []);
                signer = provider.getSigner();
                userAddress = await signer.getAddress();
                
                // Update UI
                document.getElementById('walletAddress').textContent = 
                    userAddress.substring(0, 6) + '...' + userAddress.substring(38);
                
                // Get network info
                const network = await provider.getNetwork();
                document.getElementById('networkInfo').textContent = 
                    network.name + ' (Chain ID: ' + network.chainId + ')';
                
                document.getElementById('walletInfo').style.display = 'block';
                document.getElementById('connectBtn').textContent = 'Connected';
                document.getElementById('connectBtn').disabled = true;
                
                // Enable all buttons
                document.getElementById('sendTokenBtn').disabled = false;
                document.getElementById('sendEtherBtn').disabled = false;
                document.getElementById('checkBalanceBtn').disabled = false;
                document.getElementById('setFeeToBtn').disabled = false;
                document.getElementById('getFeeToBtn').disabled = false;
                
                showStatus('Wallet connected successfully!', 'success');
                
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

                if (!ethers.utils.isAddress(tokenAddress) || !ethers.utils.isAddress(recipient)) {
                    showStatus('Invalid address format', 'error');
                    return;
                }

                showStatus('Sending token...', 'loading');

                const treasury = new ethers.Contract(TREASURY_ADDRESS, TREASURY_ABI, signer);
                
                // Convert amount to wei (assuming 18 decimals)
                const amountWei = ethers.utils.parseUnits(amount, 18);
                
                const tx = await treasury.sendToken(tokenAddress, recipient, amountWei);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('Token sent successfully!', 'success');

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

                showStatus('Sending ETH...', 'loading');

                const treasury = new ethers.Contract(TREASURY_ADDRESS, TREASURY_ABI, signer);
                const amountWei = ethers.utils.parseEther(amount);
                
                const tx = await treasury.sendEther(recipient, amountWei);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('ETH sent successfully!', 'success');

            } catch (error) {
                showStatus('Error sending ETH: ' + error.message, 'error');
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

                showStatus('Checking LP balance...', 'loading');

                const pairContract = new ethers.Contract(pairAddress, PAIR_ABI, provider);
                const balance = await pairContract.balanceOf(userAddress);
                const balanceFormatted = ethers.utils.formatUnits(balance, 18);

                document.getElementById('lpBalance').textContent = balanceFormatted;
                document.getElementById('lpBalanceInfo').style.display = 'block';

                if (balance.gt(0)) {
                    document.getElementById('burnBtn').disabled = false;
                    showStatus(`LP Balance: ${balanceFormatted}`, 'success');
                } else {
                    document.getElementById('burnBtn').disabled = true;
                    showStatus('No LP tokens found', 'info');
                }

            } catch (error) {
                showStatus('Error checking balance: ' + error.message, 'error');
            }
        }

        async function burnLPTokens() {
            try {
                const pairAddress = document.getElementById('pairAddressBurn').value.trim();

                showStatus('Burning LP tokens...', 'loading');

                const pairContract = new ethers.Contract(pairAddress, PAIR_ABI, signer);
                const tx = await pairContract.burn(userAddress);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('LP tokens burned successfully!', 'success');
                
                // Update balance
                checkLPBalance();

            } catch (error) {
                showStatus('Error burning LP: ' + error.message, 'error');
            }
        }

        // Factory Functions
        async function setFeeTo() {
            try {
                const factoryAddress = document.getElementById('factoryAddress').value.trim();
                const newFeeTo = document.getElementById('newFeeTo').value.trim();

                if (!factoryAddress || !newFeeTo) {
                    showStatus('Please fill all fields', 'error');
                    return;
                }

                if (!ethers.utils.isAddress(newFeeTo)) {
                    showStatus('Invalid feeTo address', 'error');
                    return;
                }

                showStatus('Setting new feeTo...', 'loading');

                const factory = new ethers.Contract(factoryAddress, FACTORY_ABI, signer);
                const tx = await factory.setFeeTo(newFeeTo);
                showStatus(`Transaction submitted: ${tx.hash}`, 'info');
                
                await tx.wait();
                showStatus('feeTo updated successfully!', 'success');

            } catch (error) {
                showStatus('Error setting feeTo: ' + error.message, 'error');
            }
        }

        async function getFeeTo() {
            try {
                const factoryAddress = document.getElementById('factoryAddress').value.trim();

                if (!factoryAddress) {
                    showStatus('Please enter Factory Address', 'error');
                    return;
                }

                showStatus('Getting current feeTo...', 'loading');

                const factory = new ethers.Contract(factoryAddress, FACTORY_ABI, provider);
                const currentFeeTo = await factory.feeTo();

                document.getElementById('currentFeeTo').textContent = currentFeeTo;
                document.getElementById('feeToInfo').style.display = 'block';
                
                showStatus('Current feeTo retrieved', 'success');

            } catch (error) {
                showStatus('Error getting feeTo: ' + error.message, 'error');
            }
        }

        // Auto-connect on load
        window.addEventListener('load', function() {
            if (window.ethereum) {
                connectWallet();
            }
        });

        showStatus('Connect your wallet to start', 'info');
    </script>
</body>
</html>