// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "../interfaces/IRiskEngine.sol";
import "../interfaces/IUnifiedLiquidityPool.sol";
import "../libraries/Math.sol";

/**
 * @title RiskEngine
 * @dev Advanced risk management system for the Fluid Protocol
 */
contract RiskEngine is IRiskEngine, Ownable, ReentrancyGuard, Pausable {
    using Math for uint256;

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_HEALTH_FACTOR = 1.1e18; // 110%
    uint256 public constant MAX_LTV = 0.95e18; // 95%
    uint256 public constant LIQUIDATION_THRESHOLD = 1.05e18; // 105%

    // State variables
    mapping(address => RiskParameters) public riskParameters;
    mapping(address => mapping(address => uint256)) public correlationMatrix;
    mapping(address => uint256) public assetPrices;
    mapping(address => uint256) public priceConfidence;
    mapping(address => uint256) public lastPriceUpdate;
    
    IUnifiedLiquidityPool public liquidityPool;
    address public priceOracle;
    uint256 public globalRiskMultiplier = PRECISION;
    uint256 public maxPriceAge = 3600; // 1 hour
    
    // Risk monitoring
    mapping(address => uint256) public userRiskScores;
    address[] public highRiskUsers;
    mapping(address => bool) public isHighRisk;
    
    // Emergency controls
    mapping(address => bool) public assetPaused;
    bool public globalEmergencyPause;

    // Events
    event PriceUpdated(address indexed asset, uint256 price, uint256 confidence);
    event UserRiskUpdated(address indexed user, uint256 riskScore);
    event EmergencyAction(address indexed asset, string action);

    modifier onlyOracle() {
        require(msg.sender == priceOracle, "Only oracle can update prices");
        _;
    }

    modifier notPaused(address asset) {
        require(!assetPaused[asset] && !globalEmergencyPause, "Asset or system paused");
        _;
    }

    constructor(address _liquidityPool, address _priceOracle) Ownable(msg.sender) {
        liquidityPool = IUnifiedLiquidityPool(_liquidityPool);
        priceOracle = _priceOracle;
    }

    /**
     * @dev Set risk parameters for an asset
     */
    function setRiskParameters(address asset, RiskParameters calldata params) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(params.baseLTV <= MAX_LTV, "LTV too high");
        require(params.liquidationLTV <= params.baseLTV, "Invalid liquidation LTV");
        
        riskParameters[asset] = params;
        emit RiskParametersUpdated(asset, params);
    }

    function getRiskParameters(address asset) external view returns (RiskParameters memory) {
        return riskParameters[asset];
    }

    /**
     * @dev Update volatility factor for an asset
     */
    function updateVolatilityFactor(address asset, uint256 volatilityFactor) external onlyOwner {
        riskParameters[asset].volatilityFactor = volatilityFactor;
        emit RiskParametersUpdated(asset, riskParameters[asset]);
    }

    /**
     * @dev Update correlation matrix between assets
     */
    function updateCorrelationMatrix(address[] calldata assets, uint256[][] calldata correlations) external onlyOwner {
        require(assets.length == correlations.length, "Array length mismatch");
        
        for (uint256 i = 0; i < assets.length; i++) {
            require(correlations[i].length == assets.length, "Correlation matrix invalid");
            for (uint256 j = 0; j < assets.length; j++) {
                correlationMatrix[assets[i]][assets[j]] = correlations[i][j];
            }
        }
    }

    /**
     * @dev Calculate health factor for a user
     */
    function calculateHealthFactor(address user) public view returns (uint256) {
        (uint256 totalCollateralValue, uint256 totalDebtValue) = _getUserPortfolioValue(user);
        
        if (totalDebtValue == 0) {
            return type(uint256).max; // No debt = infinite health
        }
        
        if (totalCollateralValue == 0) {
            return 0; // No collateral = zero health
        }
        
        // Apply risk adjustments
        uint256 adjustedCollateralValue = _applyRiskAdjustments(user, totalCollateralValue);
        
        return adjustedCollateralValue.mulDiv(PRECISION, totalDebtValue);
    }

    /**
     * @dev Get comprehensive user risk profile
     */
    function getUserRiskProfile(address user) external view returns (UserRiskProfile memory) {
        (uint256 totalCollateralValue, uint256 totalDebtValue) = _getUserPortfolioValue(user);
        uint256 healthFactor = calculateHealthFactor(user);
        
        return UserRiskProfile({
            totalCollateralValue: totalCollateralValue,
            totalDebtValue: totalDebtValue,
            healthFactor: healthFactor,
            liquidationThreshold: LIQUIDATION_THRESHOLD,
            isLiquidatable: healthFactor < LIQUIDATION_THRESHOLD,
            collateralAssets: _getUserCollateralAssets(user),
            debtAssets: _getUserDebtAssets(user)
        });
    }

    /**
     * @dev Check if user position is liquidatable
     */
    function isUserLiquidatable(address user) public view returns (bool) {
        return calculateHealthFactor(user) < LIQUIDATION_THRESHOLD;
    }

    /**
     * @dev Get maximum borrow amount for a user
     */
    function getMaxBorrowAmount(address user, address asset) external view returns (uint256) {
        (uint256 totalCollateralValue,) = _getUserPortfolioValue(user);
        
        RiskParameters memory params = riskParameters[asset];
        uint256 assetPrice = getAssetPrice(asset);
        
        // Apply risk adjustments
        uint256 adjustedCollateralValue = _applyRiskAdjustments(user, totalCollateralValue);
        uint256 maxBorrowValue = adjustedCollateralValue.mulDiv(params.baseLTV, PRECISION);
        
        return maxBorrowValue.mulDiv(PRECISION, assetPrice);
    }

    /**
     * @dev Get maximum withdraw amount for a user
     */
    function getMaxWithdrawAmount(address user, address asset) external view returns (uint256) {
        uint256 userDeposits = liquidityPool.getUserDeposits(user, asset);
        uint256 userBorrows = liquidityPool.getUserBorrows(user, asset);
        
        if (userBorrows == 0) {
            return userDeposits; // No debt, can withdraw all
        }
        
        // Calculate minimum collateral needed
        uint256 assetPrice = getAssetPrice(asset);
        RiskParameters memory params = riskParameters[asset];
        
        uint256 minCollateralValue = userBorrows.mulDiv(assetPrice, params.baseLTV);
        uint256 minCollateralAmount = minCollateralValue.mulDiv(PRECISION, assetPrice);
        
        return userDeposits > minCollateralAmount ? userDeposits - minCollateralAmount : 0;
    }

    /**
     * @dev Get market risk assessment for an asset
     */
    function getMarketRisk(address asset) external view returns (MarketRisk memory) {
        uint256 utilizationRate = liquidityPool.getUtilizationRate(asset);
        uint256 volatilityIndex = riskParameters[asset].volatilityFactor;
        uint256 liquidityDepth = liquidityPool.getTotalLiquidity(asset);
        
        // Calculate concentration risk (simplified)
        uint256 concentrationRisk = utilizationRate > 0.8e18 ? 
            (utilizationRate - 0.8e18).mulDiv(5, PRECISION) : 0;
        
        // Calculate correlation risk (simplified)
        uint256 correlationRisk = _calculateCorrelationRisk(asset);
        
        return MarketRisk({
            utilizationRate: utilizationRate,
            volatilityIndex: volatilityIndex,
            liquidityDepth: liquidityDepth,
            concentrationRisk: concentrationRisk,
            correlationRisk: correlationRisk
        });
    }

    /**
     * @dev Get system-wide risk level
     */
    function getSystemRisk() external view returns (uint256) {
        address[] memory assets = liquidityPool.getSupportedAssets();
        uint256 totalRisk = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 assetLiquidity = liquidityPool.getTotalLiquidity(assets[i]);
            uint256 assetRisk = _calculateAssetRisk(assets[i]);
            
            totalRisk += assetRisk.mulDiv(assetLiquidity, PRECISION);
            totalWeight += assetLiquidity;
        }
        
        return totalWeight > 0 ? totalRisk.mulDiv(PRECISION, totalWeight) : 0;
    }

    /**
     * @dev Check if market is stressed
     */
    function isMarketStressed(address asset) external view returns (bool) {
        uint256 utilizationRate = liquidityPool.getUtilizationRate(asset);
        uint256 volatilityFactor = riskParameters[asset].volatilityFactor;
        
        return utilizationRate > 0.9e18 || volatilityFactor > 2e18;
    }

    /**
     * @dev Get recommended LTV based on current market conditions
     */
    function getRecommendedLTV(address asset) external view returns (uint256) {
        RiskParameters memory params = riskParameters[asset];
        uint256 marketStress = _calculateMarketStress(asset);
        
        // Reduce LTV during high stress
        uint256 stressAdjustment = marketStress.mulDiv(params.baseLTV, 4 * PRECISION); // Max 25% reduction
        
        return params.baseLTV > stressAdjustment ? params.baseLTV - stressAdjustment : params.baseLTV / 2;
    }

    /**
     * @dev Dynamically adjust risk parameters based on market conditions
     */
    function adjustRiskParameters(address asset) external {
        require(msg.sender == address(liquidityPool) || msg.sender == owner(), "Unauthorized");
        
        uint256 marketStress = _calculateMarketStress(asset);
        RiskParameters storage params = riskParameters[asset];
        
        // Adjust parameters based on stress level
        if (marketStress > 2e18) { // High stress
            params.baseLTV = params.baseLTV.mulDiv(8e17, PRECISION); // Reduce by 20%
            params.liquidationThreshold = params.liquidationThreshold.mulDiv(11e17, PRECISION); // Increase by 10%
        } else if (marketStress < 0.5e18) { // Low stress
            params.baseLTV = Math.min(params.baseLTV.mulDiv(105e16, PRECISION), MAX_LTV); // Increase by 5%
        }
        
        emit RiskParametersUpdated(asset, params);
    }

    /**
     * @dev Emergency pause for an asset
     */
    function emergencyPause(address asset) external onlyOwner {
        assetPaused[asset] = true;
        emit EmergencyAction(asset, "PAUSED");
    }

    /**
     * @dev Emergency unpause for an asset
     */
    function emergencyUnpause(address asset) external onlyOwner {
        assetPaused[asset] = false;
        emit EmergencyAction(asset, "UNPAUSED");
    }

    /**
     * @dev Set global risk multiplier
     */
    function setGlobalRiskMultiplier(uint256 multiplier) external onlyOwner {
        require(multiplier >= 0.5e18 && multiplier <= 2e18, "Invalid multiplier");
        globalRiskMultiplier = multiplier;
    }

    /**
     * @dev Calculate liquidation amount
     */
    function calculateLiquidationAmount(address user, address collateralAsset, address debtAsset) 
        external 
        view 
        returns (uint256) 
    {
        uint256 userDebt = liquidityPool.getUserBorrows(user, debtAsset);
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor >= LIQUIDATION_THRESHOLD) {
            return 0; // Position is healthy
        }
        
        // Calculate maximum liquidation amount (typically 50% of debt)
        return userDebt.mulDiv(5e17, PRECISION);
    }

    /**
     * @dev Get liquidation bonus for an asset
     */
    function getLiquidationBonus(address collateralAsset) external view returns (uint256) {
        return riskParameters[collateralAsset].liquidationBonus;
    }

    /**
     * @dev Check if liquidator can liquidate user
     */
    function canLiquidate(address user, address liquidator) external view returns (bool) {
        // Add any liquidator-specific checks here
        return isUserLiquidatable(user) && liquidator != user;
    }

    /**
     * @dev Update asset price from oracle
     */
    function updateAssetPrice(address asset, uint256 price) external onlyOracle {
        require(price > 0, "Invalid price");
        
        assetPrices[asset] = price;
        lastPriceUpdate[asset] = block.timestamp;
        priceConfidence[asset] = PRECISION; // Full confidence from oracle
        
        emit PriceUpdated(asset, price, PRECISION);
    }

    /**
     * @dev Get asset price
     */
    function getAssetPrice(address asset) public view returns (uint256) {
        require(assetPrices[asset] > 0, "Price not available");
        require(block.timestamp - lastPriceUpdate[asset] <= maxPriceAge, "Price too old");
        
        return assetPrices[asset];
    }

    /**
     * @dev Get price with confidence level
     */
    function getPriceWithConfidence(address asset) external view returns (uint256 price, uint256 confidence) {
        price = getAssetPrice(asset);
        confidence = priceConfidence[asset];
        
        // Reduce confidence based on price age
        uint256 age = block.timestamp - lastPriceUpdate[asset];
        if (age > maxPriceAge / 2) {
            confidence = confidence.mulDiv(maxPriceAge - age, maxPriceAge / 2);
        }
    }

    /**
     * @dev Monitor user positions for risk
     */
    function monitorUserPositions(address[] calldata users) external {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 riskScore = getRiskScore(users[i]);
            userRiskScores[users[i]] = riskScore;
            
            if (riskScore > 0.8e18 && !isHighRisk[users[i]]) {
                highRiskUsers.push(users[i]);
                isHighRisk[users[i]] = true;
            } else if (riskScore <= 0.6e18 && isHighRisk[users[i]]) {
                _removeFromHighRisk(users[i]);
            }
            
            emit UserRiskUpdated(users[i], riskScore);
        }
    }

    /**
     * @dev Get list of high-risk users
     */
    function getHighRiskUsers() external view returns (address[] memory) {
        return highRiskUsers;
    }

    /**
     * @dev Calculate risk score for a user
     */
    function getRiskScore(address user) public view returns (uint256) {
        uint256 healthFactor = calculateHealthFactor(user);
        
        if (healthFactor >= 2e18) return 0; // Very safe
        if (healthFactor >= 1.5e18) return 0.2e18; // Safe
        if (healthFactor >= 1.2e18) return 0.5e18; // Moderate risk
        if (healthFactor >= LIQUIDATION_THRESHOLD) return 0.8e18; // High risk
        
        return PRECISION; // Critical risk
    }

    // Internal functions
    function _getUserPortfolioValue(address user) internal view returns (uint256 collateralValue, uint256 debtValue) {
        address[] memory assets = liquidityPool.getSupportedAssets();
        
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 price = getAssetPrice(assets[i]);
            
            uint256 deposits = liquidityPool.getUserDeposits(user, assets[i]);
            uint256 borrows = liquidityPool.getUserBorrows(user, assets[i]);
            
            collateralValue += deposits.mulDiv(price, PRECISION);
            debtValue += borrows.mulDiv(price, PRECISION);
        }
    }

    function _applyRiskAdjustments(address user, uint256 collateralValue) internal view returns (uint256) {
        // Apply global risk multiplier
        uint256 adjustedValue = collateralValue.mulDiv(globalRiskMultiplier, PRECISION);
        
        // Apply user-specific risk adjustments
        uint256 riskScore = getRiskScore(user);
        if (riskScore > 0.5e18) {
            uint256 penalty = riskScore.mulDiv(0.2e18, PRECISION); // Up to 20% penalty
            adjustedValue = adjustedValue.mulDiv(PRECISION - penalty, PRECISION);
        }
        
        return adjustedValue;
    }

    function _getUserCollateralAssets(address user) internal view returns (address[] memory) {
        address[] memory allAssets = liquidityPool.getSupportedAssets();
        address[] memory collateralAssets = new address[](allAssets.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (liquidityPool.getUserDeposits(user, allAssets[i]) > 0) {
                collateralAssets[count] = allAssets[i];
                count++;
            }
        }
        
        // Resize array
        assembly {
            mstore(collateralAssets, count)
        }
        
        return collateralAssets;
    }

    function _getUserDebtAssets(address user) internal view returns (address[] memory) {
        address[] memory allAssets = liquidityPool.getSupportedAssets();
        address[] memory debtAssets = new address[](allAssets.length);
        uint256 count = 0;
        
        for (uint256 i = 0; i < allAssets.length; i++) {
            if (liquidityPool.getUserBorrows(user, allAssets[i]) > 0) {
                debtAssets[count] = allAssets[i];
                count++;
            }
        }
        
        // Resize array
        assembly {
            mstore(debtAssets, count)
        }
        
        return debtAssets;
    }

    function _calculateCorrelationRisk(address asset) internal view returns (uint256) {
        // Simplified correlation risk calculation
        address[] memory assets = liquidityPool.getSupportedAssets();
        uint256 totalCorrelation = 0;
        uint256 count = 0;
        
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] != asset) {
                totalCorrelation += correlationMatrix[asset][assets[i]];
                count++;
            }
        }
        
        return count > 0 ? totalCorrelation / count : 0;
    }

    function _calculateAssetRisk(address asset) internal view returns (uint256) {
        uint256 utilizationRate = liquidityPool.getUtilizationRate(asset);
        uint256 volatilityFactor = riskParameters[asset].volatilityFactor;
        
        return utilizationRate.mulDiv(volatilityFactor, PRECISION);
    }

    function _calculateMarketStress(address asset) internal view returns (uint256) {
        uint256 utilizationRate = liquidityPool.getUtilizationRate(asset);
        uint256 volatilityFactor = riskParameters[asset].volatilityFactor;
        
        return (utilizationRate + volatilityFactor) / 2;
    }

    function _removeFromHighRisk(address user) internal {
        for (uint256 i = 0; i < highRiskUsers.length; i++) {
            if (highRiskUsers[i] == user) {
                highRiskUsers[i] = highRiskUsers[highRiskUsers.length - 1];
                highRiskUsers.pop();
                isHighRisk[user] = false;
                break;
            }
        }
    }

    // Admin functions
    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = _priceOracle;
    }

    function setMaxPriceAge(uint256 _maxPriceAge) external onlyOwner {
        maxPriceAge = _maxPriceAge;
    }

    function setGlobalEmergencyPause(bool _paused) external onlyOwner {
        globalEmergencyPause = _paused;
    }
}