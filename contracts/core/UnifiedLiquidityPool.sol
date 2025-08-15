// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IUnifiedLiquidityPool.sol";
import "../interfaces/IRiskEngine.sol";
import "../libraries/Math.sol";

/**
 * @title UnifiedLiquidityPool
 * @dev Central liquidity pool that serves all protocol functions
 */
contract UnifiedLiquidityPool is IUnifiedLiquidityPool, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_ASSETS = 50;
    uint256 public constant MIN_HEALTH_FACTOR = 1.1e18; // 110%

    // State variables
    mapping(address => AssetInfo) public assets;
    mapping(address => LiquidityAllocation) public liquidityAllocations;
    mapping(address => mapping(address => uint256)) public userDeposits; // user => token => amount
    mapping(address => mapping(address => uint256)) public userBorrows; // user => token => amount
    mapping(address => mapping(address => uint256)) public userShares; // user => token => shares
    mapping(address => uint256) public totalShares; // token => total shares
    
    address[] public supportedAssets;
    IRiskEngine public riskEngine;
    
    // Interest rate model parameters
    mapping(address => uint256) public baseRate;
    mapping(address => uint256) public multiplier;
    mapping(address => uint256) public jumpMultiplier;
    mapping(address => uint256) public kink;
    
    // Protocol fees
    uint256 public protocolFeeRate = 0.1e18; // 10%
    mapping(address => uint256) public protocolFees;
    
    // Modifiers
    modifier onlyValidAsset(address token) {
        require(assets[token].isActive, "Asset not supported");
        _;
    }
    
    modifier onlyHealthyPosition(address user) {
        require(getUserHealthFactor(user) >= MIN_HEALTH_FACTOR, "Position unhealthy");
        _;
    }

    constructor(address _riskEngine) Ownable(msg.sender) {
        riskEngine = IRiskEngine(_riskEngine);
    }

    /**
     * @dev Deposit tokens into the unified pool
     */
    function deposit(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyValidAsset(token) 
        returns (uint256 shares) 
    {
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        
        // Calculate shares to mint
        uint256 totalSupply = totalShares[token];
        uint256 totalAssets = getTotalLiquidity(token);
        
        if (totalSupply == 0) {
            shares = amount;
        } else {
            shares = amount.mulDiv(totalSupply, totalAssets - amount);
        }
        
        // Update state
        userShares[msg.sender][token] += shares;
        totalShares[token] += shares;
        assets[token].totalDeposits += amount;
        
        emit LiquidityDeposited(msg.sender, token, amount);
        
        // Trigger rebalancing if needed
        _checkRebalance(token);
        
        return shares;
    }

    /**
     * @dev Withdraw tokens from the unified pool
     */
    function withdraw(address token, uint256 shares) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyValidAsset(token) 
        returns (uint256 amount) 
    {
        require(shares > 0, "Shares must be greater than 0");
        require(userShares[msg.sender][token] >= shares, "Insufficient shares");
        
        // Calculate amount to withdraw
        uint256 totalSupply = totalShares[token];
        uint256 totalAssets = getTotalLiquidity(token);
        amount = shares.mulDiv(totalAssets, totalSupply);
        
        require(getAvailableLiquidity(token) >= amount, "Insufficient liquidity");
        
        // Update state
        userShares[msg.sender][token] -= shares;
        totalShares[token] -= shares;
        assets[token].totalDeposits -= amount;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        emit LiquidityWithdrawn(msg.sender, token, amount);
        
        return amount;
    }

    /**
     * @dev Borrow tokens against collateral
     */
    function borrow(address token, uint256 amount, address collateralToken) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyValidAsset(token) 
        onlyValidAsset(collateralToken) 
    {
        require(amount > 0, "Amount must be greater than 0");
        require(assets[token].canBorrow, "Asset cannot be borrowed");
        require(assets[collateralToken].canCollateralize, "Asset cannot be used as collateral");
        require(getAvailableLiquidity(token) >= amount, "Insufficient liquidity");
        
        // Check if user has sufficient collateral
        uint256 maxBorrow = riskEngine.getMaxBorrowAmount(msg.sender, token);
        require(amount <= maxBorrow, "Insufficient collateral");
        
        // Update state
        userBorrows[msg.sender][token] += amount;
        assets[token].totalBorrows += amount;
        
        IERC20(token).safeTransfer(msg.sender, amount);
        
        // Ensure position remains healthy
        require(getUserHealthFactor(msg.sender) >= MIN_HEALTH_FACTOR, "Position would be unhealthy");
    }

    /**
     * @dev Repay borrowed tokens
     */
    function repay(address token, uint256 amount) 
        external 
        nonReentrant 
        whenNotPaused 
        onlyValidAsset(token) 
    {
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 userDebt = userBorrows[msg.sender][token];
        require(userDebt > 0, "No debt to repay");
        
        uint256 repayAmount = amount > userDebt ? userDebt : amount;
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), repayAmount);
        
        // Update state
        userBorrows[msg.sender][token] -= repayAmount;
        assets[token].totalBorrows -= repayAmount;
    }

    /**
     * @dev Allocate liquidity across different components
     */
    function allocateLiquidity(address token, LiquidityAllocation calldata allocation) 
        external 
        onlyOwner 
        onlyValidAsset(token) 
    {
        uint256 totalAllocation = allocation.lendingPool + allocation.dexPool + 
                                 allocation.vaultStrategies + allocation.liquidStaking + allocation.reserves;
        
        require(totalAllocation <= PRECISION, "Total allocation exceeds 100%");
        
        liquidityAllocations[token] = allocation;
        
        emit LiquidityAllocated(token, allocation);
        
        _executeRebalance(token);
    }

    /**
     * @dev Rebalance liquidity for optimal capital efficiency
     */
    function rebalanceLiquidity(address token) external onlyValidAsset(token) {
        _executeRebalance(token);
    }

    /**
     * @dev Add a new supported asset
     */
    function addAsset(address token, AssetInfo calldata assetInfo) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(!assets[token].isActive, "Asset already exists");
        require(supportedAssets.length < MAX_ASSETS, "Too many assets");
        
        assets[token] = assetInfo;
        supportedAssets.push(token);
        
        emit AssetAdded(token, assetInfo);
    }

    /**
     * @dev Update asset parameters
     */
    function updateAsset(address token, AssetInfo calldata assetInfo) external onlyOwner onlyValidAsset(token) {
        assets[token] = assetInfo;
        emit AssetUpdated(token, assetInfo);
    }

    /**
     * @dev Liquidate an unhealthy position
     */
    function liquidate(address user, address collateralToken, address debtToken, uint256 debtAmount) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        require(riskEngine.isUserLiquidatable(user), "Position is healthy");
        require(riskEngine.canLiquidate(user, msg.sender), "Cannot liquidate");
        
        uint256 liquidationAmount = riskEngine.calculateLiquidationAmount(user, collateralToken, debtToken);
        require(debtAmount <= liquidationAmount, "Liquidation amount too high");
        
        // Calculate collateral to seize
        uint256 collateralPrice = riskEngine.getAssetPrice(collateralToken);
        uint256 debtPrice = riskEngine.getAssetPrice(debtToken);
        uint256 liquidationBonus = riskEngine.getLiquidationBonus(collateralToken);
        
        uint256 collateralToSeize = debtAmount.mulDiv(debtPrice, collateralPrice).mulDiv(PRECISION + liquidationBonus, PRECISION);
        
        // Update user positions
        userBorrows[user][debtToken] -= debtAmount;
        userDeposits[user][collateralToken] -= collateralToSeize;
        
        // Update global state
        assets[debtToken].totalBorrows -= debtAmount;
        assets[collateralToken].totalDeposits -= collateralToSeize;
        
        // Transfer tokens
        IERC20(debtToken).safeTransferFrom(msg.sender, address(this), debtAmount);
        IERC20(collateralToken).safeTransfer(msg.sender, collateralToSeize);
    }

    // View functions
    function getAvailableLiquidity(address token) public view returns (uint256) {
        return IERC20(token).balanceOf(address(this)) - protocolFees[token];
    }

    function getTotalLiquidity(address token) public view returns (uint256) {
        return assets[token].totalDeposits;
    }

    function getUtilizationRate(address token) public view returns (uint256) {
        uint256 totalDeposits = assets[token].totalDeposits;
        if (totalDeposits == 0) return 0;
        return assets[token].totalBorrows.mulDiv(PRECISION, totalDeposits);
    }

    function getSupplyRate(address token) public view returns (uint256) {
        uint256 utilizationRate = getUtilizationRate(token);
        uint256 borrowRate = getBorrowRate(token);
        return borrowRate.mulDiv(utilizationRate, PRECISION).mulDiv(PRECISION - protocolFeeRate, PRECISION);
    }

    function getBorrowRate(address token) public view returns (uint256) {
        uint256 utilizationRate = getUtilizationRate(token);
        
        if (utilizationRate <= kink[token]) {
            return baseRate[token] + utilizationRate.mulDiv(multiplier[token], PRECISION);
        } else {
            uint256 normalRate = baseRate[token] + kink[token].mulDiv(multiplier[token], PRECISION);
            uint256 excessUtilization = utilizationRate - kink[token];
            return normalRate + excessUtilization.mulDiv(jumpMultiplier[token], PRECISION);
        }
    }

    function getUserDeposits(address user, address token) external view returns (uint256) {
        if (totalShares[token] == 0) return 0;
        return userShares[user][token].mulDiv(getTotalLiquidity(token), totalShares[token]);
    }

    function getUserBorrows(address user, address token) external view returns (uint256) {
        return userBorrows[user][token];
    }

    function getUserHealthFactor(address user) public view returns (uint256) {
        return riskEngine.calculateHealthFactor(user);
    }

    function getAssetInfo(address token) external view returns (AssetInfo memory) {
        return assets[token];
    }

    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }

    function isLiquidatable(address user) external view returns (bool) {
        return riskEngine.isUserLiquidatable(user);
    }

    // Internal functions
    function _checkRebalance(address token) internal {
        // Implement rebalancing logic based on utilization and allocation targets
        uint256 utilizationRate = getUtilizationRate(token);
        
        // Trigger rebalance if utilization deviates significantly from target
        if (utilizationRate > 0.9e18 || utilizationRate < 0.1e18) {
            _executeRebalance(token);
        }
    }

    function _executeRebalance(address token) internal {
        // Implement actual rebalancing logic
        // This would involve moving liquidity between lending, DEX, vaults, etc.
        emit RebalanceExecuted(token, block.timestamp);
    }

    // Admin functions
    function setRiskEngine(address _riskEngine) external onlyOwner {
        riskEngine = IRiskEngine(_riskEngine);
    }

    function setInterestRateModel(address token, uint256 _baseRate, uint256 _multiplier, uint256 _jumpMultiplier, uint256 _kink) external onlyOwner {
        baseRate[token] = _baseRate;
        multiplier[token] = _multiplier;
        jumpMultiplier[token] = _jumpMultiplier;
        kink[token] = _kink;
    }

    function setProtocolFeeRate(uint256 _protocolFeeRate) external onlyOwner {
        require(_protocolFeeRate <= 0.3e18, "Fee rate too high"); // Max 30%
        protocolFeeRate = _protocolFeeRate;
    }

    function collectProtocolFees(address token) external onlyOwner {
        uint256 fees = protocolFees[token];
        protocolFees[token] = 0;
        IERC20(token).safeTransfer(msg.sender, fees);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}