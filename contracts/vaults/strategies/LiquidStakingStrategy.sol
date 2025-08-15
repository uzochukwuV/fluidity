// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../../interfaces/IYieldStrategy.sol";
import "../../libraries/Math.sol";

/**
 * @title LiquidStakingStrategy
 * @dev Strategy for liquid staking on Core blockchain
 */
contract LiquidStakingStrategy is IYieldStrategy, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // Constants
    uint256 public constant PRECISION = 1e18;
    uint256 public constant MIN_STAKE_AMOUNT = 1e18; // 1 CORE minimum
    uint256 public constant UNSTAKE_DELAY = 7 days;

    // State variables
    address public override asset;
    address public override vault;
    address public stakingContract;
    address public liquidStakingToken; // stCORE or similar
    
    uint256 public totalStaked;
    uint256 public totalRewards;
    uint256 public lastHarvestTime;
    uint256 public performanceFee = 0.1e18; // 10%
    
    // Unstaking queue
    struct UnstakeRequest {
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }
    
    mapping(uint256 => UnstakeRequest) public unstakeRequests;
    uint256 public nextUnstakeId;
    uint256 public totalPendingUnstake;

    // Events
    event Staked(uint256 amount, uint256 shares);
    event UnstakeRequested(uint256 indexed requestId, uint256 amount);
    event UnstakeProcessed(uint256 indexed requestId, uint256 amount);
    event RewardsHarvested(uint256 rewards, uint256 fees);

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault can call");
        _;
    }

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Initialize the strategy
     */
    function initialize(address _asset, address _vault) external override onlyOwner {
        require(_asset != address(0) && _vault != address(0), "Invalid addresses");
        require(asset == address(0), "Already initialized");
        
        asset = _asset;
        vault = _vault;
        lastHarvestTime = block.timestamp;
        
        // In a real implementation, you'd set the actual staking contract addresses
        // For Core blockchain, this would be the validator staking contract
        stakingContract = address(0x1234567890123456789012345678901234567890); // Placeholder
        liquidStakingToken = address(0x0987654321098765432109876543210987654321); // Placeholder
    }

    /**
     * @dev Deposit assets into the strategy
     */
    function deposit(uint256 amount) external override onlyVault nonReentrant {
        require(amount >= MIN_STAKE_AMOUNT, "Amount below minimum");
        
        // Transfer assets from vault
        IERC20(asset).safeTransferFrom(vault, address(this), amount);
        
        // Stake the assets
        _stake(amount);
        
        emit Deposited(amount);
    }

    /**
     * @dev Withdraw assets from the strategy
     */
    function withdraw(uint256 amount) public override onlyVault nonReentrant returns (uint256) {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= balanceOf(), "Insufficient balance");
        
        // Check if we have enough liquid assets
        uint256 liquidBalance = IERC20(asset).balanceOf(address(this));
        
        if (liquidBalance >= amount) {
            // Direct transfer if we have enough liquid assets
            IERC20(asset).safeTransfer(vault, amount);
            emit Withdrawn(amount);
            return amount;
        } else {
            // Need to unstake some assets
            uint256 unstakeAmount = amount - liquidBalance;
            _requestUnstake(unstakeAmount);
            
            // Transfer available liquid assets
            if (liquidBalance > 0) {
                IERC20(asset).safeTransfer(vault, liquidBalance);
            }
            
            emit Withdrawn(liquidBalance);
            return liquidBalance; // Return what we could immediately withdraw
        }
    }

    /**
     * @dev Withdraw all assets from the strategy
     */
    function withdrawAll() external override onlyVault nonReentrant returns (uint256) {
        uint256 totalBalance = balanceOf();
        
        // Check if we have enough liquid assets
        uint256 liquidBalance = IERC20(asset).balanceOf(address(this));
        
        if (liquidBalance >= totalBalance) {
            // Direct transfer if we have enough liquid assets
            IERC20(asset).safeTransfer(vault, totalBalance);
            emit Withdrawn(totalBalance);
            return totalBalance;
        } else {
            // Need to unstake some assets
            uint256 unstakeAmount = totalBalance - liquidBalance;
            _requestUnstake(unstakeAmount);
            
            // Transfer available liquid assets
            if (liquidBalance > 0) {
                IERC20(asset).safeTransfer(vault, liquidBalance);
            }
            
            emit Withdrawn(liquidBalance);
            return liquidBalance; // Return what we could immediately withdraw
        }
    }

    /**
     * @dev Harvest rewards from staking
     */
    function harvest() external override nonReentrant returns (uint256 profit) {
        require(block.timestamp >= lastHarvestTime + 1 hours, "Too early to harvest");
        
        // Calculate rewards (simplified - in reality would query staking contract)
        uint256 stakingRewards = _calculateStakingRewards();
        
        if (stakingRewards > 0) {
            // Claim rewards from staking contract
            _claimRewards();
            
            // Calculate performance fee
            uint256 fees = stakingRewards.mulDiv(performanceFee, PRECISION);
            profit = stakingRewards - fees;
            
            // Update tracking
            totalRewards += stakingRewards;
            lastHarvestTime = block.timestamp;
            
            // Transfer fees to owner
            if (fees > 0) {
                IERC20(asset).safeTransfer(owner(), fees);
            }
            
            emit RewardsHarvested(stakingRewards, fees);
            emit Harvested(profit);
        }
        
        return profit;
    }

    /**
     * @dev Rebalance the strategy
     */
    function rebalance() external override onlyVault {
        // Process any pending unstake requests that are ready
        _processPendingUnstakes();
        
        // Restake any idle assets
        uint256 idleBalance = IERC20(asset).balanceOf(address(this));
        if (idleBalance >= MIN_STAKE_AMOUNT) {
            _stake(idleBalance);
        }
        
        emit Rebalanced();
    }

    /**
     * @dev Emergency withdraw all assets
     */
    function emergencyWithdraw() external override onlyOwner returns (uint256) {
        // Unstake everything immediately (may incur penalties)
        uint256 stakedAmount = getAllocatedAmount();
        if (stakedAmount > 0) {
            _emergencyUnstake(stakedAmount);
        }
        
        // Transfer all available assets to vault
        uint256 totalBalance = IERC20(asset).balanceOf(address(this));
        if (totalBalance > 0) {
            IERC20(asset).safeTransfer(vault, totalBalance);
        }
        
        emit EmergencyWithdraw(totalBalance);
        return totalBalance;
    }

    // View functions
    function balanceOf() public view override returns (uint256) {
        return IERC20(asset).balanceOf(address(this)) + getAllocatedAmount() - totalPendingUnstake;
    }

    function getAllocatedAmount() public view override returns (uint256) {
        // In reality, this would query the staking contract for our staked balance
        return totalStaked;
    }

    function getPendingRewards() external view override returns (uint256) {
        return _calculateStakingRewards();
    }

    function getAPY() external view override returns (uint256) {
        if (totalStaked == 0) return 0;
        
        // Calculate APY based on historical rewards
        uint256 timePeriod = block.timestamp - lastHarvestTime;
        if (timePeriod == 0) return 0;
        
        uint256 annualizedRewards = totalRewards.mulDiv(365 days, timePeriod);
        return annualizedRewards.mulDiv(PRECISION, totalStaked);
    }

    function isHealthy() external view override returns (bool) {
        // Strategy is healthy if we're not over-allocated and have reasonable liquidity
        uint256 liquidBalance = IERC20(asset).balanceOf(address(this));
        uint256 totalBalance = balanceOf();
        
        return totalBalance > 0 && liquidBalance >= totalBalance.mulDiv(0.05e18, PRECISION); // 5% liquidity buffer
    }

    function strategyName() external pure override returns (string memory) {
        return "Liquid Staking Strategy";
    }

    function version() external pure override returns (string memory) {
        return "1.0.0";
    }

    // Internal functions
    function _stake(uint256 amount) internal {
        // In a real implementation, this would interact with Core's staking contract
        // For now, we'll simulate by updating our tracking
        totalStaked += amount;
        
        // Simulate receiving liquid staking tokens
        // IERC20(liquidStakingToken).mint(address(this), amount);
        
        emit Staked(amount, amount); // 1:1 ratio for simplicity
    }

    function _requestUnstake(uint256 amount) internal {
        require(amount <= totalStaked, "Insufficient staked amount");
        
        unstakeRequests[nextUnstakeId] = UnstakeRequest({
            amount: amount,
            timestamp: block.timestamp,
            processed: false
        });
        
        totalPendingUnstake += amount;
        totalStaked -= amount;
        
        emit UnstakeRequested(nextUnstakeId, amount);
        nextUnstakeId++;
    }

    function _processPendingUnstakes() internal {
        for (uint256 i = 0; i < nextUnstakeId; i++) {
            UnstakeRequest storage request = unstakeRequests[i];
            
            if (!request.processed && block.timestamp >= request.timestamp + UNSTAKE_DELAY) {
                // Process the unstake request
                request.processed = true;
                totalPendingUnstake -= request.amount;
                
                // In reality, this would claim the unstaked tokens from the staking contract
                // For simulation, we assume the tokens are now available
                
                emit UnstakeProcessed(i, request.amount);
            }
        }
    }

    function _calculateStakingRewards() internal view returns (uint256) {
        // Simplified reward calculation - in reality would query staking contract
        uint256 timeSinceLastHarvest = block.timestamp - lastHarvestTime;
        uint256 annualRewardRate = 0.05e18; // 5% APY
        
        return totalStaked.mulDiv(annualRewardRate, PRECISION).mulDiv(timeSinceLastHarvest, 365 days);
    }

    function _claimRewards() internal {
        // In reality, this would call the staking contract to claim rewards
        // For simulation, we assume rewards are automatically added to our balance
    }

    function _emergencyUnstake(uint256 amount) internal {
        // Emergency unstake with potential penalties
        totalStaked -= amount;
        
        // In reality, this would call emergency unstake on the staking contract
        // which might incur penalties but gives immediate access to funds
    }

    // Admin functions
    function setPerformanceFee(uint256 _performanceFee) external onlyOwner {
        require(_performanceFee <= 0.3e18, "Fee too high"); // Max 30%
        performanceFee = _performanceFee;
    }

    function setStakingContract(address _stakingContract) external onlyOwner {
        require(_stakingContract != address(0), "Invalid address");
        stakingContract = _stakingContract;
    }

    function setLiquidStakingToken(address _liquidStakingToken) external onlyOwner {
        require(_liquidStakingToken != address(0), "Invalid address");
        liquidStakingToken = _liquidStakingToken;
    }

    // Emergency functions
    function recoverERC20(address token, uint256 amount) external onlyOwner {
        require(token != asset, "Cannot recover strategy asset");
        IERC20(token).safeTransfer(owner(), amount);
    }
}