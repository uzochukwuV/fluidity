// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IStabilityPool.sol";
import "../tokens/USDF.sol";
import "../tokens/FluidToken.sol";
import "../libraries/Math.sol";

/**
 * @title StabilityPool
 * @dev Manages USDF deposits to liquidate user troves and earn rewards
 */
contract StabilityPool is IStabilityPool, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Constants
    uint256 public constant DECIMAL_PRECISION = 1e18;
    uint256 public constant SCALE_FACTOR = 1e9;

    // State variables
    USDF public usdfToken;
    FluidToken public fluidToken;
    address public troveManager;
    address public borrowerOperations;
    address public activePool;

    // Pool state
    uint256 public totalUSDF;
    mapping(address => uint256) public totalCollateral; // asset => total collateral
    
    // User deposits and snapshots
    mapping(address => uint256) public deposits; // user => USDF deposit
    mapping(address => Snapshots) public depositSnapshots; // user => snapshots
    
    // Reward tracking per asset
    mapping(address => uint256) public S; // asset => reward per unit staked (scaled)
    uint256 public P = DECIMAL_PRECISION; // USDF loss per unit staked
    uint256 public currentScale;
    uint256 public currentEpoch;
    
    // FLUID rewards
    uint256 public G; // FLUID reward per unit staked
    mapping(uint256 => mapping(uint256 => uint256)) public epochToScaleToG; // epoch => scale => G
    mapping(uint256 => mapping(uint256 => uint256)) public epochToScaleToSum; // epoch => scale => sum
    
    // Community issuance
    address public communityIssuance;
    uint256 public lastFLUIDError_Offset;

    struct Snapshots {
        mapping(address => uint256) S; // asset => S snapshot
        uint256 P;
        uint256 G;
        uint128 scale;
        uint128 epoch;
    }

    modifier onlyTroveManager() {
        require(msg.sender == troveManager, "Only TroveManager");
        _;
    }

    modifier onlyActivePool() {
        require(msg.sender == activePool, "Only ActivePool");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function initialize(
        address _usdfToken,
        address _fluidToken,
        address _troveManager,
        address _borrowerOperations,
        address _activePool,
        address _communityIssuance
    ) external onlyOwner {
        usdfToken = USDF(_usdfToken);
        fluidToken = FluidToken(_fluidToken);
        troveManager = _troveManager;
        borrowerOperations = _borrowerOperations;
        activePool = _activePool;
        communityIssuance = _communityIssuance;
    }

    /**
     * @dev Deposit USDF into stability pool
     */
    function provideToSP(uint256 amount, address frontEndTag) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(usdfToken.balanceOf(msg.sender) >= amount, "Insufficient USDF balance");

        uint256 initialDeposit = deposits[msg.sender];
        
        // Trigger FLUID issuance
        _triggerFLUIDIssuance();
        
        // Pay out FLUID gains
        if (initialDeposit > 0) {
            uint256 fluidGain = _getFLUIDGain(msg.sender);
            if (fluidGain > 0) {
                fluidToken.transfer(msg.sender, fluidGain);
            }
        }

        // Pay out collateral gains
        _payOutCollateralGains(msg.sender);

        // Update deposit
        uint256 compoundedUSDF = getCompoundedUSDF(msg.sender);
        uint256 newDeposit = compoundedUSDF + amount;
        
        deposits[msg.sender] = newDeposit;
        totalUSDF = totalUSDF - compoundedUSDF + newDeposit;

        // Update snapshots
        _updateDepositSnapshots(msg.sender);

        // Transfer USDF from user
        IERC20(address(usdfToken)).safeTransferFrom(msg.sender, address(this), amount);

        emit UserDepositChanged(msg.sender, newDeposit);
        emit StabilityPoolUSDF(totalUSDF);
    }

    /**
     * @dev Withdraw USDF from stability pool
     */
    function withdrawFromSP(uint256 amount) external nonReentrant {
        uint256 initialDeposit = deposits[msg.sender];
        require(initialDeposit > 0, "No deposit to withdraw");

        // Trigger FLUID issuance
        _triggerFLUIDIssuance();

        // Pay out FLUID gains
        uint256 fluidGain = _getFLUIDGain(msg.sender);
        if (fluidGain > 0) {
            fluidToken.transfer(msg.sender, fluidGain);
        }

        // Pay out collateral gains
        _payOutCollateralGains(msg.sender);

        uint256 compoundedUSDF = getCompoundedUSDF(msg.sender);
        uint256 withdrawalAmount = Math.min(amount, compoundedUSDF);
        
        uint256 newDeposit = compoundedUSDF - withdrawalAmount;
        deposits[msg.sender] = newDeposit;
        totalUSDF -= withdrawalAmount;

        // Update snapshots
        _updateDepositSnapshots(msg.sender);

        // Transfer USDF to user
        IERC20(address(usdfToken)).safeTransfer(msg.sender, withdrawalAmount);

        emit UserDepositChanged(msg.sender, newDeposit);
        emit StabilityPoolUSDF(totalUSDF);
    }

    /**
     * @dev Withdraw all USDF from stability pool
     */
    function withdrawAllFromSP() external nonReentrant {
        uint256 initialDeposit = deposits[msg.sender];
        require(initialDeposit > 0, "No deposit to withdraw");

        // Trigger FLUID issuance
        _triggerFLUIDIssuance();

        // Pay out FLUID gains
        uint256 fluidGain = _getFLUIDGain(msg.sender);
        if (fluidGain > 0) {
            fluidToken.transfer(msg.sender, fluidGain);
        }

        // Pay out collateral gains
        _payOutCollateralGains(msg.sender);

        uint256 compoundedUSDF = getCompoundedUSDF(msg.sender);
        
        deposits[msg.sender] = 0;
        totalUSDF -= compoundedUSDF;

        // Update snapshots
        _updateDepositSnapshots(msg.sender);

        // Transfer USDF to user
        IERC20(address(usdfToken)).safeTransfer(msg.sender, compoundedUSDF);

        emit UserDepositChanged(msg.sender, 0);
        emit StabilityPoolUSDF(totalUSDF);
    }

    /**
     * @dev Offset debt and collateral from liquidation
     */
    function offset(address asset, uint256 debtToOffset, uint256 collToAdd) external onlyTroveManager {
        require(debtToOffset > 0, "Debt to offset must be positive");
        require(totalUSDF > 0, "No USDF in pool");

        // Trigger FLUID issuance
        _triggerFLUIDIssuance();

        // Calculate loss per unit staked
        uint256 USFDLossPerUnitStaked = debtToOffset.mulDiv(DECIMAL_PRECISION, totalUSDF);
        uint256 collGainPerUnitStaked = collToAdd.mulDiv(DECIMAL_PRECISION, totalUSDF);

        // Update P (USDF loss tracker) - Fixed P calculation
        uint256 newP = P.mulDiv(DECIMAL_PRECISION - USFDLossPerUnitStaked, DECIMAL_PRECISION);
        
        // Check if we need to update scale/epoch
        if (newP < SCALE_FACTOR) {
            currentScale++;
            P = newP.mulDiv(SCALE_FACTOR, DECIMAL_PRECISION);
            
            // Store G for the previous scale
            epochToScaleToG[currentEpoch][currentScale - 1] = G;
            G = 0; // Reset G for new scale
        } else {
            P = newP;
        }

        // Update S (collateral gain tracker) - Fixed S calculation
        uint256 marginalCollGain = collGainPerUnitStaked.mulDiv(P, DECIMAL_PRECISION);
        S[asset] += marginalCollGain;

        // Update totals
        totalUSDF -= debtToOffset;
        totalCollateral[asset] += collToAdd;

        emit StabilityPoolUSDF(totalUSDF);
        emit StabilityPoolCollateral(asset, totalCollateral[asset]);
    }

    // View functions
    function getTotalUSDF() external view returns (uint256) {
        return totalUSDF;
    }

    function getTotalCollateral(address asset) external view returns (uint256) {
        return totalCollateral[asset];
    }

    function getCompoundedUSDF(address depositor) public view returns (uint256) {
        uint256 initialDeposit = deposits[depositor];
        if (initialDeposit == 0) return 0;

        Snapshots storage snapshots = depositSnapshots[depositor];
        
        // Fixed compounded deposit calculation
        uint256 compoundedDeposit = initialDeposit.mulDiv(P, snapshots.P);
        
        return compoundedDeposit;
    }

    function getDepositorCollateralGain(address depositor, address asset) public view returns (uint256) {
        uint256 initialDeposit = deposits[depositor];
        if (initialDeposit == 0) return 0;

        Snapshots storage snapshots = depositSnapshots[depositor];
        
        // Fixed collateral gain calculation
        uint256 firstPortion = S[asset] - snapshots.S[asset];
        uint256 secondPortion = firstPortion.mulDiv(snapshots.P, P);
        
        uint256 collateralGain = initialDeposit.mulDiv(secondPortion, DECIMAL_PRECISION);
        
        return collateralGain;
    }

    function getDepositorFLUIDGain(address depositor) external view returns (uint256) {
        return _getFLUIDGain(depositor);
    }

    // Internal functions
    function _payOutCollateralGains(address depositor) internal {
        uint256 initialDeposit = deposits[depositor];
        if (initialDeposit == 0) return;

        // Pay out gains for each collateral type
        address[] memory assets = _getSupportedAssets();
        
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            uint256 collateralGain = getDepositorCollateralGain(depositor, asset);
            
            if (collateralGain > 0) {
                totalCollateral[asset] -= collateralGain;
                IERC20(asset).safeTransfer(depositor, collateralGain);
                emit CollateralGainWithdrawn(depositor, asset, collateralGain);
            }
        }
    }

    function _updateDepositSnapshots(address depositor) internal {
        Snapshots storage snapshots = depositSnapshots[depositor];
        
        // Update S snapshots for all assets
        address[] memory assets = _getSupportedAssets();
        for (uint256 i = 0; i < assets.length; i++) {
            snapshots.S[assets[i]] = S[assets[i]];
        }
        
        snapshots.P = P;
        snapshots.G = G;
        snapshots.scale = uint128(currentScale);
        snapshots.epoch = uint128(currentEpoch);
    }

    function _getFLUIDGain(address depositor) internal view returns (uint256) {
        uint256 initialDeposit = deposits[depositor];
        if (initialDeposit == 0) return 0;

        Snapshots storage snapshots = depositSnapshots[depositor];
        
        // Fixed FLUID gain calculation
        uint256 firstPortion = G - snapshots.G;
        uint256 secondPortion = firstPortion.mulDiv(snapshots.P, P);
        
        uint256 fluidGain = initialDeposit.mulDiv(secondPortion, DECIMAL_PRECISION);
        return fluidGain;
    }

    function _triggerFLUIDIssuance() internal {
        // Would integrate with community issuance contract
        // For now, simplified implementation
        if (communityIssuance != address(0) && totalUSDF > 0) {
            // Simulate FLUID issuance
            uint256 fluidIssuance = 1000e18; // Placeholder amount
            G += fluidIssuance.mulDiv(DECIMAL_PRECISION, totalUSDF);
        }
    }

    function _getSupportedAssets() internal pure returns (address[] memory) {
        // Would return list of supported collateral assets
        address[] memory assets = new address[](1);
        assets[0] = address(0x1234567890123456789012345678901234567890); // Placeholder
        return assets;
    }

    // Admin functions
    function setAddresses(
        address _troveManager,
        address _borrowerOperations,
        address _activePool,
        address _communityIssuance
    ) external onlyOwner {
        troveManager = _troveManager;
        borrowerOperations = _borrowerOperations;
        activePool = _activePool;
        communityIssuance = _communityIssuance;
    }
}