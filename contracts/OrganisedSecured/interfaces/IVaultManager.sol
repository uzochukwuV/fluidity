// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IVaultManager
 * @notice Interface for vault strategy management
 * @dev Vault managers handle yield-generating strategies for capital deployment
 *      Vaults are designed to maximize returns on deposited collateral
 */
interface IVaultManager {
    // ============ Events ============

    /// @notice Emitted when collateral is deposited into a vault
    event VaultDeposit(address indexed asset, uint256 amount, uint256 sharesReceived);

    /// @notice Emitted when collateral is withdrawn from a vault
    event VaultWithdraw(address indexed asset, uint256 shares, uint256 amountWithdrawn);

    /// @notice Emitted when rewards are claimed from a vault
    event RewardsClaimed(address indexed asset, uint256 rewards);

    // ============ Deposit/Withdraw Functions ============

    /**
     * @notice Deposit collateral into vault strategy
     * @param asset The collateral token to deposit
     * @param amount The amount of collateral to deposit
     * @return sharesReceived The vault shares received for the deposit
     * @dev Must return vault shares proportional to the deposit
     *      Shares should account for existing yield in the vault
     */
    function deposit(address asset, uint256 amount) external returns (uint256 sharesReceived);

    /**
     * @notice Withdraw collateral from vault strategy
     * @param asset The collateral token to withdraw
     * @param shares The number of vault shares to burn
     * @return amountWithdrawn The collateral amount received
     * @dev Shares are burned and proportional collateral is returned
     *      May trigger rebalancing within vault if needed
     */
    function withdraw(address asset, uint256 shares) external returns (uint256 amountWithdrawn);

    /**
     * @notice Emergency withdrawal of all collateral without share mechanics
     * @param asset The collateral token to withdraw
     * @param amount The amount of collateral to withdraw
     * @dev Used in emergencies to quickly exit vault positions
     *      May incur penalties or slippage
     */
    function emergencyWithdraw(address asset, uint256 amount) external;

    // ============ View Functions ============

    /**
     * @notice Get the vault's balance for a specific asset
     * @param asset The collateral token
     * @return The total collateral amount in the vault for this asset
     */
    function getVaultBalance(address asset) external view returns (uint256);

    /**
     * @notice Get the share price for a vault (1 share = X tokens)
     * @param asset The collateral token
     * @return The value of one share in the base token (1e18 scale)
     * @dev Used to calculate how many shares to burn for a withdrawal
     */
    function getSharePrice(address asset) external view returns (uint256);

    /**
     * @notice Get the user's share balance in a vault
     * @param asset The collateral token
     * @param user The user address
     * @return The number of vault shares held by the user
     */
    function getUserShares(address asset, address user) external view returns (uint256);

    /**
     * @notice Get the APY (Annual Percentage Yield) for a vault
     * @param asset The collateral token
     * @return The APY in basis points (e.g., 1000 = 10%)
     */
    function getAPY(address asset) external view returns (uint256);

    /**
     * @notice Check if a vault is accepting new deposits
     * @param asset The collateral token
     * @return True if deposits are enabled for this asset
     */
    function isDepositEnabled(address asset) external view returns (bool);

    /**
     * @notice Get the total collateral managed by this vault
     * @param asset The collateral token
     * @return The total collateral value in the vault
     */
    function getTotalAssets(address asset) external view returns (uint256);

    /**
     * @notice Get unrealized gains/losses in the vault
     * @param asset The collateral token
     * @return gains The total unrealized profit (can be negative)
     */
    function getUnrealizedGains(address asset) external view returns (int256 gains);

    // ============ Admin Functions ============

    /**
     * @notice Enable/disable deposits for an asset
     * @param asset The collateral token
     * @param enabled True to enable deposits, false to disable
     */
    function setDepositEnabled(address asset, bool enabled) external;

    /**
     * @notice Update the vault strategy
     * @param asset The collateral token
     * @param newStrategy The new strategy address
     * @dev May require migration of funds to new strategy
     */
    function updateStrategy(address asset, address newStrategy) external;

    /**
     * @notice Claim rewards earned by the vault
     * @param asset The collateral token
     * @return rewards The amount of rewards claimed
     */
    function claimRewards(address asset) external returns (uint256 rewards);
}
