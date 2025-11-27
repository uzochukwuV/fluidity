// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IStakingPool
 * @notice Interface for staking strategy management
 * @dev Staking pools allow capital deployment to earn yield through staking mechanisms
 *      Users stake collateral and earn staking rewards over time
 */
interface IStakingPool {
    // ============ Events ============

    /// @notice Emitted when collateral is staked
    event Staked(address indexed asset, address indexed staker, uint256 amount, uint256 sharesReceived);

    /// @notice Emitted when collateral is unstaked
    event Unstaked(address indexed asset, address indexed unstaker, uint256 shares, uint256 amountWithdrawn);

    /// @notice Emitted when staking rewards are claimed
    event RewardsClaimed(address indexed asset, address indexed claimer, uint256 rewards);

    /// @notice Emitted when staking reward rate is updated
    event RewardRateUpdated(address indexed asset, uint256 newRate);

    // ============ Stake/Unstake Functions ============

    /**
     * @notice Stake collateral to earn rewards
     * @param asset The collateral token to stake
     * @param amount The amount of collateral to stake
     * @return sharesReceived The staking shares received
     * @dev Allows delegation to earn staking rewards
     *      Shares are proportional to the contribution
     */
    function stake(address asset, uint256 amount) external returns (uint256 sharesReceived);

    /**
     * @notice Unstake collateral from the staking pool
     * @param asset The collateral token to unstake
     * @param shares The number of staking shares to burn
     * @return amountWithdrawn The collateral amount received
     * @dev Shares are burned and proportional collateral is returned
     *      Pending rewards may be forfeited depending on implementation
     */
    function unstake(address asset, uint256 shares) external returns (uint256 amountWithdrawn);

    /**
     * @notice Emergency withdrawal of all staked collateral
     * @param asset The collateral token to withdraw
     * @param amount The amount of collateral to withdraw
     * @dev Used in emergencies to quickly exit staking positions
     *      May incur penalties
     */
    function emergencyWithdraw(address asset, uint256 amount) external;

    /**
     * @notice Claim accumulated staking rewards
     * @param asset The collateral token
     * @return rewardsAmount The rewards claimed
     * @dev Distributes earned staking rewards to the caller
     *      Rewards are typically in the same token as the stake
     */
    function claimRewards(address asset) external returns (uint256 rewardsAmount);

    // ============ View Functions ============

    /**
     * @notice Get total staked amount in the pool for an asset
     * @param asset The collateral token
     * @return The total amount of collateral staked
     */
    function getTotalStaked(address asset) external view returns (uint256);

    /**
     * @notice Get a user's staked amount
     * @param asset The collateral token
     * @param user The user address
     * @return The user's staked amount
     */
    function getUserStaked(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the number of staking shares held by a user
     * @param asset The collateral token
     * @param user The user address
     * @return The number of shares held
     */
    function getUserShares(address asset, address user) external view returns (uint256);

    /**
     * @notice Get accumulated rewards for a user
     * @param asset The collateral token
     * @param user The user address
     * @return The unclaimed rewards amount
     */
    function getUserRewards(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the current staking APY (Annual Percentage Yield)
     * @param asset The collateral token
     * @return The APY in basis points (e.g., 5000 = 50%)
     */
    function getStakingAPY(address asset) external view returns (uint256);

    /**
     * @notice Get the staking reward rate
     * @param asset The collateral token
     * @return The reward rate per block/time unit
     */
    function getRewardRate(address asset) external view returns (uint256);

    /**
     * @notice Get the share price (1 share = X tokens)
     * @param asset The collateral token
     * @return The value of one share in the base token (1e18 scale)
     */
    function getSharePrice(address asset) external view returns (uint256);

    /**
     * @notice Check if staking is enabled for an asset
     * @param asset The collateral token
     * @return True if staking is currently enabled
     */
    function isStakingEnabled(address asset) external view returns (bool);

    /**
     * @notice Get the minimum stake amount for an asset
     * @param asset The collateral token
     * @return The minimum amount required to stake
     */
    function getMinStake(address asset) external view returns (uint256);

    /**
     * @notice Get the lock-up period for staking
     * @param asset The collateral token
     * @return The lock-up period in seconds (0 = no lock-up)
     */
    function getLockupPeriod(address asset) external view returns (uint256);

    /**
     * @notice Get total accumulated rewards that have been distributed
     * @param asset The collateral token
     * @return The total rewards distributed from this pool
     */
    function getTotalRewardsDistributed(address asset) external view returns (uint256);

    // ============ Admin Functions ============

    /**
     * @notice Enable/disable staking for an asset
     * @param asset The collateral token
     * @param enabled True to enable staking, false to disable
     */
    function setStakingEnabled(address asset, bool enabled) external;

    /**
     * @notice Update the staking reward rate
     * @param asset The collateral token
     * @param newRate The new reward rate
     */
    function setRewardRate(address asset, uint256 newRate) external;

    /**
     * @notice Update the minimum stake amount
     * @param asset The collateral token
     * @param minAmount The new minimum stake amount
     */
    function setMinStake(address asset, uint256 minAmount) external;

    /**
     * @notice Update the lock-up period
     * @param asset The collateral token
     * @param lockupSeconds The new lock-up period in seconds
     */
    function setLockupPeriod(address asset, uint256 lockupSeconds) external;
}
