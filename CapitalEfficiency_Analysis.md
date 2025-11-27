# CapitalEfficiencyEngine.sol - Comprehensive Analysis Report

**File:** `contracts/OrganisedSecured/core/CapitalEfficiencyEngine.sol`
**Total Lines:** 881
**Status:** Partially Implemented - Awaiting Critical Dependencies

---

## 1. COMPLETE STRUCTURE MAP

### 1.1 Data Structures

#### Structs (from ICapitalEfficiencyEngine interface):
```
CapitalAllocation (used in mapping _allocations)
  - uint128 totalCollateral       (total collateral tracked)
  - uint128 reserveBuffer         (safety reserve amount)
  - uint128 allocatedToAMM        (capital in AMM)
  - uint128 allocatedToVaults     (capital in vaults - future)
  - uint128 allocatedToStaking    (capital in staking - future)
  - uint128 lpTokensOwned         (LP tokens held)
  - uint32 lastRebalance          (timestamp of last rebalance)
  - bool isActive                 (allocation active flag)

AllocationConfig (used in mapping _configs)
  - uint16 reserveBufferPct       (reserve % - default 70% until vaults ready)
  - uint16 ammAllocationPct       (AMM % - default 40%)
  - uint16 vaultsAllocationPct    (vaults % - default 0% until ready)
  - uint16 stakingAllocationPct   (staking % - default 0% until ready)
  - uint16 rebalanceThreshold     (drift threshold - default 10%)
  - bool autoRebalance            (auto-rebalancing enabled)
```

### 1.2 State Variables

```solidity
// Immutables (set in constructor)
ILiquidityCore public immutable liquidityCore
ITroveManager public immutable troveManager

// Dynamic state
IFluidAMM public fluidAMM
address public vaultManager               // TODO: implementation pending
address public stakingPool                // TODO: implementation pending

// Core storage
mapping(address => CapitalAllocation) private _allocations
mapping(address => AllocationConfig) private _configs
address[] private _activeAssets
mapping(address => bool) private _isInActiveList
```

### 1.3 Constants

```solidity
uint16 constant MAX_AMM_ALLOCATION = 4000           // 40%
uint16 constant MAX_VAULTS_ALLOCATION = 2000        // 20%
uint16 constant MAX_STAKING_ALLOCATION = 1000       // 10%
uint16 constant MIN_RESERVE_BUFFER = 3000           // 30%
uint256 constant MAX_UTILIZATION = 9000             // 90%
uint256 private constant BASIS_POINTS = 10000
```

### 1.4 Inheritance & Modifiers

**Inherits from:**
- `OptimizedSecurityBase` (access control, pause mechanism)
- `ICapitalEfficiencyEngine` (interface implementation)

**Custom Modifiers:**
```solidity
activeAsset(address asset)              // Checks if asset allocation is active
onlyTroveManager()                      // Role-based access control
```

**Inherited Modifiers:**
- `nonReentrant` (from OptimizedSecurityBase)
- `whenNotPaused` (from OptimizedSecurityBase)
- `onlyValidRole()` (from OptimizedSecurityBase)

---

## 2. TODO ANALYSIS - ALL 117 LINES OF COMMENTS

### 2.1 Comment Block in Header (Lines 19-117)

**Total TODO items documented:** 24 comprehensive items organized by priority

#### CRITICAL - MUST COMPLETE BEFORE PRODUCTION (Lines 22-39)

1. **TODO 1: Complete rebalance() function - Lines 24-28**
   - Status: NOT STARTED
   - Lines: 231-236 need implementation
   - Required:
     - Logic to call `fluidAMM.addLiquidity()` when currentAMM < targetAMM
     - Logic to call `fluidAMM.removeLiquidity()` when currentAMM > targetAMM
     - Slippage protection parameters (minAmountOut)
     - Calculate optimal USDF pairing amount based on pool ratios
   - Dependency: FluidAMM contract must be deployed and functional
   - Impact: CRITICAL - Rebalancing cannot work without this

2. **TODO 2: Complete allocateCollateral() AMM integration - Lines 30-34**
   - Status: PARTIALLY IMPLEMENTED (Lines 302-316)
   - Required:
     - Calculate USDF amount needed to pair with collateral (Line 314 comment)
     - Query pool reserves to determine optimal ratio
     - Call `fluidAMM.addLiquidity()` with proper parameters
     - Store LP tokens received in `allocation.lpTokensOwned`
   - Dependency: FluidAMM interface and initialization
   - Impact: Capital cannot be deployed to AMM without this

3. **TODO 3: Implement emergencyRecallAll() return mechanism - Lines 36-39**
   - Status: PARTIALLY IMPLEMENTED (Lines 583-586)
   - Required:
     - Add `LiquidityCore.receiveReturn()` function OR
     - Transfer tokens then call `LiquidityCore.depositCollateral()`
     - Update accounting to reflect returned collateral
   - Dependency: LiquidityCore must support return mechanism
   - Impact: CRITICAL - Emergency funds cannot be returned to core

#### HIGH PRIORITY - TESTNET (Lines 41-51)

4. **TODO 4: Add vault integration - Lines 43-46**
   - Status: PLACEHOLDER ONLY (Lines 297-306, 359-364)
   - Required:
     - Implement vault withdrawal logic in `withdrawFromStrategies()`
     - Implement vault recall in `emergencyRecallAll()`
     - Create `IVaultManager` interface for vault contracts
   - Dependency: Vault contracts not yet implemented
   - Current code: Lines 490-496 show validation but no actual withdrawal
   - Impact: Cannot deploy capital to vaults

5. **TODO 5: Add staking integration - Lines 48-51**
   - Status: PLACEHOLDER ONLY (Lines 308-318, 366-371)
   - Required:
     - Implement staking withdrawal logic
     - Implement staking recall
     - Create `IStakingPool` interface for staking contracts
   - Dependency: Staking contracts not yet implemented
   - Current code: Lines 505-511 show validation but no actual unstaking
   - Impact: Cannot deploy capital to staking

6. **TODO 6: Implement LP token tracking - Lines 53-56**
   - Status: PARTIAL (struct has field, not used)
   - Required:
     - Update `allocation.lpTokensOwned` when adding/removing AMM liquidity
     - Add getter function for LP token balance
     - Track LP tokens per pool (if multiple AMM pools)
   - Dependency: AMM liquidity functions must be implemented first
   - Impact: Cannot track actual LP token positions

#### MEDIUM PRIORITY - ENHANCEMENTS (Lines 58-78)

7. **TODO 7: Add multi-pool AMM support - Lines 60-63**
   - Status: NOT STARTED
   - Required:
     - Add mapping: `asset => poolId[]` for multiple pools
     - Distribute liquidity across multiple pools
   - Impact: Limited to single pool per asset currently

8. **TODO 8: Dynamic allocation percentages - Lines 65-68**
   - Status: NOT STARTED
   - Required:
     - Adjust allocations based on yield rates
     - Prioritize highest yielding strategies
     - Integrate yield oracle

9. **TODO 9: Configurable slippage protection - Lines 70-73**
   - Status: NOT STARTED
   - Required:
     - Make slippage tolerance configurable per asset
     - Add `setSlippageTolerance(asset, bps)` function
     - Default to 1% (100 bps)

10. **TODO 10: Automated rebalancing keeper - Lines 75-78**
    - Status: NOT STARTED
    - Required:
      - External keeper bot calling `rebalance()`
      - Incentive mechanism (gas + reward)
      - Rate limiting (max 1 rebalance per hour)

#### LOW PRIORITY - ENHANCEMENTS (Lines 80-100)

11. **TODO 11: Comprehensive event logging - Lines 82-85**
    - Status: PARTIAL (basic events exist, could be enhanced)

12. **TODO 12: Batch operations - Lines 87-90**
    - Status: NOT STARTED
    - Required: `allocateCollateralMulti()`, `rebalanceMulti()`

13. **TODO 13: Emergency pause per asset - Lines 92-95**
    - Status: NOT STARTED (only global pause exists)

14. **TODO 14: Allocation history tracking - Lines 97-100**
    - Status: NOT STARTED
    - Required: Historical snapshots and performance metrics

#### TESTING & SECURITY (Lines 102-116)

15-20. **Testing Requirements** (Lines 104-109)
- Unit tests
- Integration tests
- Edge case tests
- Gas profiling
- Stress tests
- Fuzzing tests

21-24. **Security Requirements** (Lines 111-116)
- Professional security audit
- Economic model validation
- Mainnet fork simulation
- Bug bounty program

### 2.2 Inline TODOs in Code

**Line 364:** `// TODO: Add liquidity to AMM`
```solidity
// In rebalance() function when currentAMM < targetAMM
// Missing actual addLiquidity call
allocation.allocatedToAMM = _toUint128(targetAMM);  // <- Only updates state, doesn't execute
```

**Lines 377-392:** `// TODO:` comments (5 sub-tasks)
```solidity
// 4. TODO: Calculate optimal USDF amount based on pool reserves
// 5. TODO: Add liquidity to AMM with slippage protection
// 6. TODO: Update LP tokens owned
```

**Line 398:** `// TODO: Remove liquidity from AMM`
```solidity
// In rebalance() function when currentAMM > targetAMM
```

**Lines 401-416:** `// TODO:` comments (4 sub-tasks)
```solidity
// 1. TODO: Calculate LP tokens to burn
// 2. TODO: Remove liquidity from AMM
// 3. TODO: Update LP tokens owned
// 4. TODO: Return collateral to LiquidityCore
```

**Line 494:** `// TODO: Implement actual vault withdrawal when IVaultManager is ready`
```solidity
// In withdrawFromStrategies() - currently only validates vaultManager is set
require(vaultManager != address(0), "CEE: Vault withdrawal requested but vaultManager not set");
// vaultManager.withdraw(asset, vaultsWithdrawn, address(this));  <- commented out
withdrawn += vaultsWithdrawn;  // <- state update without actual withdrawal!
```

**Line 509:** `// TODO: Implement actual staking withdrawal when IStakingPool is ready`
```solidity
// In withdrawFromStrategies() - currently only validates stakingPool is set
require(stakingPool != address(0), "CEE: Staking withdrawal requested but stakingPool not set");
// stakingPool.unstake(asset, stakingWithdrawn, address(this));  <- commented out
withdrawn += stakingWithdrawn;  // <- state update without actual withdrawal!
```

**Summary of inline TODOs:**
- Total inline TODO markers: 12 (beyond the comment block)
- Critical path TODOs: 6 (rebalance add/remove, vault/staking withdrawal)
- State without implementation: 2 (vault and staking withdrawal count to total but don't transfer)

---

## 3. MISSING IMPLEMENTATIONS

### 3.1 AMM Liquidity Provision Logic

**Status:** INCOMPLETE

**Location:** `allocateCollateral()` Lines 302-316
```solidity
if (toAMM > 0 && address(fluidAMM) != address(0)) {
    uint256 coreBalance = IERC20(asset).balanceOf(address(liquidityCore));
    require(coreBalance >= toAMM, "Insufficient LiquidityCore balance");
    liquidityCore.transferCollateral(asset, address(this), toAMM);
    IERC20(asset).forceApprove(address(fluidAMM), toAMM);
    
    // MISSING: Calculate USDF amount needed
    // MISSING: Call fluidAMM.addLiquidity()
    // MISSING: Handle LP tokens returned
}
```

**What's Missing:**
1. Query `fluidAMM.getReserves(asset, usdfToken)` to get pool ratio
2. Calculate `usdfAmount = (toAMM * reserve1) / reserve0`
3. Call `fluidAMM.addLiquidity(asset, usdf, toAMM, usdfAmount, minA, minB)`
4. Store returned `liquidity` tokens in `allocation.lpTokensOwned`
5. Track USDF spend - USDF must come from where?

**Critical Issue:** Where does USDF come from?
- Contract receives collateral asset from LiquidityCore
- FluidAMM requires both asset AND USDF to add liquidity
- Current code has no USDF balance or approval mechanism
- **This is a design gap** - need USDF sourcing strategy

### 3.2 Vault Integration (Deposit/Withdraw)

**Status:** NOT IMPLEMENTED

**Current Code:** Lines 266-274, 297-306, 359-364
```solidity
// Only validation, no actual implementation
require(vaultManager != address(0), "CEE: Vault allocation enabled but vaultManager not set");

// In allocateCollateral: Lines 297-306 - NO INTERACTION CODE
// In rebalance: Lines 359-364 - NO REBALANCING CODE
// In withdrawFromStrategies: Lines 490-496
    require(vaultManager != address(0), "CEE: Vault withdrawal requested but vaultManager not set");
    // vaultManager.withdraw(asset, vaultsWithdrawn, address(this));  <- COMMENTED OUT
```

**What's Needed:**
```solidity
interface IVaultManager {
    function deposit(address asset, uint256 amount) external returns (uint256 shares);
    function withdraw(address asset, uint256 shares) external returns (uint256 amount);
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Issues:**
1. IVaultManager interface doesn't exist
2. No vault deposit logic in `allocateCollateral()`
3. No vault rebalancing logic in `rebalance()`
4. Withdrawal attempt is commented out, state updated without transfer

### 3.3 Staking Integration (Stake/Unstake)

**Status:** NOT IMPLEMENTED

**Current Code:** Lines 271-274, 308-318, 366-371
```solidity
// Only validation, no actual implementation
require(stakingPool != address(0), "CEE: Staking allocation enabled but stakingPool not set");

// In allocateCollateral: Lines 308-318 - NO INTERACTION CODE
// In rebalance: Lines 366-371 - NO REBALANCING CODE
// In withdrawFromStrategies: Lines 505-511
    require(stakingPool != address(0), "CEE: Staking withdrawal requested but stakingPool not set");
    // stakingPool.unstake(asset, stakingWithdrawn, address(this));  <- COMMENTED OUT
```

**What's Needed:**
```solidity
interface IStakingPool {
    function stake(address asset, uint256 amount) external returns (uint256 shares);
    function unstake(address asset, uint256 shares) external returns (uint256 amount);
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Issues:**
1. IStakingPool interface doesn't exist
2. No staking deposit logic in `allocateCollateral()`
3. No staking rebalancing logic in `rebalance()`
4. Unstaking attempt is commented out, state updated without transfer

### 3.4 Rebalance Logic Completion

**Status:** PARTIALLY IMPLEMENTED

**Location:** `rebalance()` Lines 326-430

**What's Implemented:**
- Checks if rebalancing needed
- Calculates target allocations based on config percentages
- Validates strategy availability (CRIT-1 fix)
- Updates state variables (allocation tracking, reserve buffer)
- Emits events

**What's Missing:**

#### When currentAMM < targetAMM (Lines 363-396):
```solidity
if (currentAMM < targetAMM && address(fluidAMM) != address(0)) {
    uint256 toAdd = targetAMM - currentAMM;
    uint256 coreBalance = IERC20(asset).balanceOf(address(liquidityCore));
    require(coreBalance >= toAdd, "Insufficient LiquidityCore balance");
    liquidityCore.transferCollateral(asset, address(this), toAdd);
    IERC20(asset).forceApprove(address(fluidAMM), toAdd);
    
    // TODO: Step 4 - Calculate USDF amount
    // TODO: Step 5 - Call fluidAMM.addLiquidity()
    // TODO: Step 6 - Update lpTokensOwned
    
    allocation.allocatedToAMM = _toUint128(targetAMM);  // <- State only, no actual deployment
}
```

#### When currentAMM > targetAMM (Lines 397-422):
```solidity
else if (currentAMM > targetAMM && address(fluidAMM) != address(0)) {
    uint256 toRemove = currentAMM - targetAMM;
    
    // TODO: Step 1 - Calculate LP tokens to burn
    // TODO: Step 2 - Call fluidAMM.removeLiquidity()
    // TODO: Step 3 - Update lpTokensOwned
    // TODO: Step 4 - Return collateral to LiquidityCore
    
    allocation.allocatedToAMM = _toUint128(targetAMM);  // <- State only, no actual withdrawal
}
```

#### Vault/Staking Rebalancing:
- No rebalancing logic for vaults (Lines 357-358, 369-371)
- No rebalancing logic for staking (Line 372)
- Only allocation calculation, no actual transfers

---

## 4. DEPENDENCY MAPPING

### 4.1 IFluidAMM - Required Functions

**From IFluidAMM.sol, these functions are USED:**

```solidity
// Liquidity Management
function addLiquidity(
    address token0,
    address token1,
    uint256 amount0Desired,
    uint256 amount1Desired,
    uint256 amount0Min,
    uint256 amount1Min
) external returns (uint256 amount0, uint256 amount1, uint256 liquidity);
// USED IN: allocateCollateral() and rebalance() - CURRENTLY NOT CALLED

function removeLiquidity(
    address token0,
    address token1,
    uint256 liquidity,
    uint256 amount0Min,
    uint256 amount1Min
) external returns (uint256 amount0, uint256 amount1);
// USED IN: rebalance() - CURRENTLY NOT CALLED

function emergencyWithdrawLiquidity(
    address token,
    uint256 amount,
    address destination
) external;
// USED IN: withdrawFromStrategies() Line 480, emergencyRecallAll() Line 560
// STATUS: CALLED

// View Functions (for calculations)
function getReserves(address token0, address token1)
    external
    view
    returns (uint256 reserve0, uint256 reserve1);
// NEEDED FOR: Calculating optimal USDF amount - NOT CURRENTLY USED

function quote(
    address tokenIn,
    address tokenOut,
    uint256 amountIn
) external view returns (uint256 amountOut, uint256 fee);
// NEEDED FOR: Price calculation and slippage validation - NOT USED
```

**Critical Issue:** 
- `addLiquidity()` and `removeLiquidity()` are NOT called anywhere
- Only `emergencyWithdrawLiquidity()` is implemented
- This means normal allocation and rebalancing are BROKEN

**Missing USDF Integration:**
- No way to get or approve USDF tokens
- `addLiquidity()` requires both tokens
- Current design only has collateral asset

### 4.2 ILiquidityCore - Functions Used

```solidity
// Functions CALLED BY CapitalEfficiencyEngine:
function getCollateralReserve(address asset) external view returns (uint256);
// USED: Lines 285, 341, 602, 622, 644, 708
// STATUS: WORKING

function getDebtReserve(asset) external view returns (uint256);
// USED: Line 709
// STATUS: WORKING

function transferCollateral(asset, to, amount) external;
// USED: Lines 308, 372
// STATUS: WORKING

// Functions NEEDED BUT NOT CALLED:
function depositCollateral(asset, account, amount) external;
// NEEDED FOR: Returning collateral in emergencyRecallAll()
// CURRENTLY: Only does forceApprove (Line 584), no actual deposit call

function returnToUnifiedPool(asset, amount) external;
// ALTERNATIVE: Could return to unified pool instead of depositing
// CURRENTLY: Not called
```

**Critical Issue:**
- `emergencyRecallAll()` approves tokens to LiquidityCore but doesn't call deposit/return
- Line 584: `IERC20(asset).forceApprove(address(liquidityCore), totalRecalled);`
- No actual transfer mechanism implemented
- This is a CRITICAL BUG - emergency withdrawal is incomplete

### 4.3 ITroveManager - Functions Used

```solidity
function hasValidRole(bytes32 role, address account) external view returns (bool);
// USED: Line 222 for access control
// STATUS: INHERITED FROM accessControl
```

**Status:** Working (via access control)

### 4.4 MISSING Interfaces - Need to Create

#### IVaultManager (NOT YET DEFINED)
```solidity
// Recommended interface
interface IVaultManager {
    function deposit(address asset, uint256 amount) external returns (uint256 shares);
    function withdraw(address asset, uint256 shares) external returns (uint256 amount);
    function getUserShares(address asset, address user) external view returns (uint256);
    function getShareValue(address asset) external view returns (uint256);
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Where it's needed:**
- Lines 267-269: Existence check
- Lines 297-306: Allocation (NOT IMPLEMENTED)
- Lines 359-364: Rebalancing (NOT IMPLEMENTED)
- Lines 490-496: Withdrawal (COMMENTED OUT)
- Lines 566-570: Emergency recall (NO-OP)

#### IStakingPool (NOT YET DEFINED)
```solidity
// Recommended interface
interface IStakingPool {
    function stake(address asset, uint256 amount) external returns (uint256 shares);
    function unstake(address asset, uint256 shares) external returns (uint256 amount);
    function getStakedAmount(address asset, address user) external view returns (uint256);
    function getRewardRate(address asset) external view returns (uint256);
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Where it's needed:**
- Lines 271-273: Existence check
- Lines 308-318: Allocation (NOT IMPLEMENTED)
- Lines 366-371: Rebalancing (NOT IMPLEMENTED)
- Lines 505-511: Withdrawal (COMMENTED OUT)
- Lines 572-577: Emergency recall (NO-OP)

---

## 5. ALLOCATION FLOW - COLLATERAL JOURNEY

### 5.1 Full Allocation Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ STARTING POSITION: All collateral in LiquidityCore             │
│ Total Collateral: X                                             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ allocateCollateral(asset, amount) ENTRY                        │
│ Called by: Admin only (onlyValidRole ADMIN_ROLE)              │
│ Inputs: asset address, amount to allocate                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
                    ┌─────────┴────────┐
                    │                  │
         ┌──────────▼─────────┐   ┌───▼──────────────┐
         │ CHECKS (Lines 247-274)│   │ Calculate allocations│
         │ • Validate amount      │   │ based on percentages │
         │ • Check utilization    │   │ (Lines 276-279)     │
         │ • Circuit breaker      │   │                      │
         │ • Available balance    │   │ toAMM = amount *    │
         │ • Vault/staking ready  │   │   ammAllocationPct  │
         └────────┬──────────┘   └────┬──────────────┘
                  │                   │
                  └───────────┬───────┘
                              ↓
         ┌────────────────────────────────────────┐
         │ EFFECTS - Update State (Lines 281-298) │
         │ • Update totalCollateral in state      │
         │ • Update allocations tracking          │
         │ • Update reserve buffer                │
         │ • Set lastRebalance timestamp          │
         └────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────────────┐
         │ INTERACTIONS - Deploy Capital (Lines 300-316)
         │ IF toAMM > 0:                           │
         │   1. Verify LiquidityCore has balance  │
         │   2. Transfer from LiquidityCore → CEE │
         │   3. Approve fluidAMM to spend         │
         │   4. [TODO] Call fluidAMM.addLiquidity()
         │   5. [TODO] Handle LP tokens received  │
         │                                         │
         │ IF toVaults > 0:                        │
         │   [NOT IMPLEMENTED - placeholder]      │
         │                                         │
         │ IF toStaking > 0:                       │
         │   [NOT IMPLEMENTED - placeholder]      │
         └────────────────────────────────────────┘
                              ↓
         ┌────────────────────────────────────────┐
         │ RESULT STATE (after allocation)        │
         │ • LiquidityCore: X - toAMM - toVaults  │
         │   - toStaking                          │
         │ • CEE.allocatedToAMM: += toAMM         │
         │ • CEE.allocatedToVaults: += toVaults   │
         │ • CEE.allocatedToStaking: += toStaking │
         │ • CEE.reserveBuffer: updated           │
         │                                         │
         │ CRITICAL ISSUE:                        │
         │ • Vaults: only state update, no actual │
         │   funds moved (placeholder)             │
         │ • Staking: only state update, no actual│
         │   funds moved (placeholder)            │
         │ • AMM: transfers occur but addLiquidity│
         │   not called (broken for both tokens)  │
         └────────────────────────────────────────┘
```

### 5.2 Rebalance Flow

```
┌──────────────────────────────────────┐
│ rebalance(asset) ENTRY              │
│ Called by: Any address              │
│ Checks: shouldRebalance() true       │
└──────────────────────────────────────┘
                    ↓
         ┌──────────────────┐
         │ Get Current State│
         │ • totalCollateral│
         │ • currentAMM     │
         │ • targetAMM      │
         │ • etc            │
         └─────────┬────────┘
                   ↓
         ┌─────────────────────┐
         │ IF currentAMM < targetAMM
         │ (Need to ADD liquidity) │
         └────────┬──────────────┘
                  ↓
         ┌────────────────────────┐
         │ Withdraw from LCore    │
         │ 1. Verify balance      │
         │ 2. Transfer collateral │
         │ 3. Approve fluidAMM    │
         │ [TODO] 4. Get reserves  │
         │ [TODO] 5. Call addLiq   │
         │ [TODO] 6. Update LP tokens
         └────────────────────────┘
                  ↓
         ┌─────────────────────────┐
         │ IF currentAMM > targetAMM
         │ (Need to REMOVE liquidity)
         └────────┬───────────────┘
                  ↓
         ┌────────────────────────┐
         │ [TODO] 1. Calc LP tokens
         │ [TODO] 2. Call removeLiq
         │ [TODO] 3. Update LP tokens
         │ [TODO] 4. Return to LCore
         └────────────────────────┘
                  ↓
         ┌────────────────────────┐
         │ Update all allocations │
         │ Update reserve buffer  │
         │ Update lastRebalance   │
         │ Emit event             │
         └────────────────────────┘
```

### 5.3 Emergency Withdrawal Flow

```
┌────────────────────────────────────────────┐
│ withdrawFromStrategies() - For Liquidations│
│ Called by: TroveManager (onlyTroveManager) │
│ Inputs: asset, amount, destination         │
└────────┬───────────────────────────────────┘
         ↓
┌────────────────────────────────┐
│ CASCADING WITHDRAWAL STRATEGY   │
│ 1. Try AMM first (most liquid) │
│ 2. Try Vaults next             │
│ 3. Try Staking last            │
└────────┬───────────────────────┘
         ↓
    ┌────────────────────────┐
    │ AMM Withdrawal (WORKS) │
    │ IF allocated > 0:      │
    │ - Call emergencyWithdraw
    │ - Update state         │
    │ - Track withdrawn      │
    └────────┬───────────────┘
             ↓
    ┌────────────────────────┐
    │ Vault Withdrawal (BROKEN)
    │ IF allocated > 0:      │
    │ - Validate mgr exists  │
    │ - [TODO] withdrawal    │
    │ - Update state         │
    │ - Track withdrawn      │
    │ ISSUE: No actual call  │
    └────────┬───────────────┘
             ↓
    ┌────────────────────────┐
    │ Staking Withdrawal (BROKEN)
    │ IF allocated > 0:      │
    │ - Validate pool exists │
    │ - [TODO] unstake       │
    │ - Update state         │
    │ - Track withdrawn      │
    │ ISSUE: No actual call  │
    └────────┬───────────────┘
             ↓
┌────────────────────────────────┐
│ TRANSFER TO DESTINATION        │
│ SafeTransfer total withdrawn   │
│ to destination address         │
└────────────────────────────────┘
```

### 5.4 Emergency Recall Flow

```
┌──────────────────────────────────────┐
│ emergencyRecallAll(asset) - Full Exit│
│ Called by: Emergency admin           │
│ Goal: Return all capital to LCore    │
└──────────────────────────────────────┘
                 ↓
    ┌─────────────────────────┐
    │ Recall from AMM         │
    │ IF allocated > 0:       │
    │ - Call emergencyWithdraw│
    │ - Set allocated to 0    │
    │ - Track total recalled  │
    │ STATUS: WORKS           │
    └────────┬────────────────┘
             ↓
    ┌─────────────────────────┐
    │ Recall from Vaults      │
    │ IF allocated > 0:       │
    │ - [NOT IMPLEMENTED]     │
    │ - Set allocated to 0    │
    │ - Track total recalled  │
    │ STATUS: NO-OP (BUG)     │
    └────────┬────────────────┘
             ↓
    ┌─────────────────────────┐
    │ Recall from Staking     │
    │ IF allocated > 0:       │
    │ - [NOT IMPLEMENTED]     │
    │ - Set allocated to 0    │
    │ - Track total recalled  │
    │ STATUS: NO-OP (BUG)     │
    └────────┬────────────────┘
             ↓
    ┌──────────────────────────┐
    │ Return to LiquidityCore  │
    │ IF totalRecalled > 0:    │
    │ - forceApprove tokens    │
    │ - [TODO] deposit OR      │
    │ - [TODO] return call     │
    │ STATUS: APPROVAL ONLY    │
    │         NO TRANSFER      │
    └──────────────────────────┘
```

---

## 6. CRITICAL GAPS - WILL BREAK IF NOT IMPLEMENTED

### 6.1 CRITICAL BUG #1: emergencyRecallAll() Incomplete

**Severity:** CRITICAL - Emergency funds stuck

**Location:** Lines 583-586

```solidity
if (totalRecalled > 0) {
    IERC20(asset).forceApprove(address(liquidityCore), totalRecalled);
    // Note: Would need LiquidityCore function to accept returns
}
```

**Issue:** 
- Only approves, doesn't transfer
- No call to `depositCollateral()` or `returnToUnifiedPool()`
- Tokens remain in CEE contract
- Emergency situation cannot be resolved

**Impact:** 
- CRITICAL - Protocol cannot recover from emergency
- Collateral becomes unreachable
- System remains in unsafe state

**Fix Required:**
```solidity
if (totalRecalled > 0) {
    IERC20(asset).safeTransfer(address(liquidityCore), totalRecalled);
    // OR call depositCollateral() if contract-to-contract requires it
    // liquidityCore.depositCollateral(asset, address(this), totalRecalled);
}
```

### 6.2 CRITICAL BUG #2: allocateCollateral() AMM Incomplete

**Severity:** CRITICAL - Capital deployment broken

**Location:** Lines 302-316

```solidity
if (toAMM > 0 && address(fluidAMM) != address(0)) {
    uint256 coreBalance = IERC20(asset).balanceOf(address(liquidityCore));
    require(coreBalance >= toAMM, "Insufficient LiquidityCore balance");
    liquidityCore.transferCollateral(asset, address(this), toAMM);
    IERC20(asset).forceApprove(address(fluidAMM), toAMM);
    // MISSING IMPLEMENTATION
    // No addLiquidity call
}
```

**Issues:**
1. Transfers collateral to CEE
2. Approves fluidAMM to spend
3. Never calls `addLiquidity()`
4. Never handles USDF pairing (design gap)
5. LP tokens never stored in state

**Impact:**
- CRITICAL - Cannot allocate any capital to AMM
- Collateral sits idle in CEE, never deployed
- Capital allocation feature is broken
- State gets updated (ledger wrong) but no actual deployment

### 6.3 CRITICAL BUG #3: withdrawFromStrategies() Vaults/Staking

**Severity:** CRITICAL - Withdrawal incomplete for vaults/staking

**Location:** Lines 490-496 (vaults), 505-511 (staking)

```solidity
// VAULTS
if (withdrawn < amount && allocation.allocatedToVaults > 0) {
    uint256 needed = amount - withdrawn;
    vaultsWithdrawn = needed.min(allocation.allocatedToVaults);
    require(vaultManager != address(0), "...");
    // vaultManager.withdraw(asset, vaultsWithdrawn, address(this));  <- COMMENTED OUT
    withdrawn += vaultsWithdrawn;  // STATE UPDATED BUT NO TRANSFER
}

// STAKING
if (withdrawn < amount && allocation.allocatedToStaking > 0) {
    uint256 needed = amount - withdrawn;
    stakingWithdrawn = needed.min(allocation.allocatedToStaking);
    require(stakingPool != address(0), "...");
    // stakingPool.unstake(asset, stakingWithdrawn, address(this));  <- COMMENTED OUT
    withdrawn += stakingWithdrawn;  // STATE UPDATED BUT NO TRANSFER
}
```

**Issues:**
1. Withdrawal calls are commented out (not implemented)
2. State is updated without actual transfer
3. Contract balance check would fail (Line 517)
4. Liquidation could be incomplete

**Impact:**
- CRITICAL - Liquidations may fail if vaults/staking deployed
- Under-withdrawal of funds
- State becomes inconsistent with actual balances
- Line 517 validation would catch this and revert

### 6.4 CRITICAL BUG #4: rebalance() Add Liquidity Incomplete

**Severity:** CRITICAL - Rebalancing broken

**Location:** Lines 363-396

```solidity
if (currentAMM < targetAMM && address(fluidAMM) != address(0)) {
    uint256 toAdd = targetAMM - currentAMM;
    uint256 coreBalance = IERC20(asset).balanceOf(address(liquidityCore));
    require(coreBalance >= toAdd, "Insufficient LiquidityCore balance");
    liquidityCore.transferCollateral(asset, address(this), toAdd);
    IERC20(asset).forceApprove(address(fluidAMM), toAdd);
    
    // MISSING: getReserves, calculate USDF, addLiquidity call
    // Updates state without actual deployment
    allocation.allocatedToAMM = _toUint128(targetAMM);
}
```

**Issues:**
1. No `getReserves()` call to determine ratio
2. No USDF amount calculation
3. No `addLiquidity()` call
4. No LP token tracking
5. State updated but no actual deployment

**Impact:**
- CRITICAL - Rebalancing non-functional
- Collateral transferred but not deployed
- State inconsistent with actual holdings

### 6.5 CRITICAL BUG #5: rebalance() Remove Liquidity Incomplete

**Severity:** CRITICAL - Rebalancing broken

**Location:** Lines 397-422

```solidity
else if (currentAMM > targetAMM && address(fluidAMM) != address(0)) {
    uint256 toRemove = currentAMM - targetAMM;
    
    // MISSING: Calculate LP tokens, removeLiquidity call, state update
    // Updates state without actual withdrawal
    allocation.allocatedToAMM = _toUint128(targetAMM);
}
```

**Issues:**
1. No LP token calculation
2. No `removeLiquidity()` call
3. No collateral return to LiquidityCore
4. No state update for LP tokens
5. State updated but collateral not withdrawn

**Impact:**
- CRITICAL - Cannot reduce AMM allocation
- Trapped capital in AMM
- Rebalancing impossible in this direction

### 6.6 CRITICAL DESIGN GAP: USDF Sourcing

**Severity:** CRITICAL - Architecture issue

**Problem:**
- `addLiquidity()` requires both tokens (asset + USDF)
- CEE only handles asset transfer from LiquidityCore
- No mechanism to get/approve USDF tokens
- Where does USDF come from?

**Current Code:** Lines 314-315
```solidity
// Note: This would need the USDF pair amount, simplified here
// In production, would calculate optimal USDF amount based on pool ratio
```

**Options:**
1. **Mint USDF:** CEE mints USDF as needed (requires USDF interface)
2. **Borrow from LiquidityCore:** Request USDF from LCore (needs new function)
3. **Protocol-owned USDF reserves:** Keep USDF buffer in CEE
4. **Use different strategy:** Only deploy one-sided assets

**This needs architectural decision before implementation**

### 6.7 MEDIUM SEVERITY: Vault/Staking Not Ready

**Severity:** MEDIUM (can be disabled but implementation planned)

**Status:**
- Vault interface not defined
- Staking interface not defined
- No integration code
- Default config sets both to 0%

**Current Workaround:**
- Lines 736-744: `activateAsset()` sets vaults/staking to 0% by default
- Can enable later when implementation complete
- Allows safe deployment without these features

**Remaining Work:**
- Define IVaultManager interface
- Define IStakingPool interface
- Implement allocation logic
- Implement rebalancing logic
- Implement withdrawal logic
- Implement emergency recall logic
- Comprehensive testing

---

## 7. INTEGRATION POINTS

### 7.1 Integration with LiquidityCore

**Dependency Flow:**
```
LiquidityCore (holds all collateral)
    ↓
    ├─ allocateCollateral() → transferCollateral()
    │   └─ Withdraws idle capital from LCore
    │
    ├─ rebalance() → transferCollateral()
    │   └─ Moves collateral between strategies
    │
    ├─ withdrawFromStrategies() → getCollateralReserve()
    │   └─ For liquidations, pulls from strategies
    │
    ├─ emergencyRecallAll() → [BROKEN]
    │   └─ Should return all capital via depositCollateral()
    │
    └─ View functions → getCollateralReserve(), getDebtReserve()
        └─ Calculations use LCore data
```

**Integration Points:**
1. **transferCollateral()** - Called to move capital OUT of LCore
   - Line 308: In `allocateCollateral()` for AMM deployment
   - Line 372: In `rebalance()` for adding liquidity
   
2. **getCollateralReserve()** - Called to check available capital
   - Line 285: Update total collateral tracking
   - Line 341: During rebalance calculation
   - Line 602: In `getAvailableForAllocation()` view
   - Line 622: In `getRequiredReserve()` view
   - Line 644: In `shouldRebalance()` view
   - Line 708: In `getUtilizationRate()` view

3. **getDebtReserve()** - Called to calculate utilization
   - Line 709: In `getUtilizationRate()` calculation

4. **Missing: Return mechanism**
   - `emergencyRecallAll()` needs to return capital
   - Should call `depositCollateral()` or `returnToUnifiedPool()`
   - Currently only approves, doesn't transfer

### 7.2 Integration with FluidAMM

**Dependency Flow:**
```
FluidAMM (handles liquidity provision)
    ↓
    ├─ allocateCollateral() → [BROKEN]
    │   ├─ Should: addLiquidity()
    │   └─ Actually: only approves
    │
    ├─ rebalance() → [BROKEN]
    │   ├─ Should: addLiquidity() / removeLiquidity()
    │   └─ Actually: only state updates
    │
    ├─ withdrawFromStrategies() → emergencyWithdrawLiquidity() [WORKS]
    │   └─ Withdraws capital during liquidations
    │
    └─ emergencyRecallAll() → emergencyWithdrawLiquidity() [WORKS]
        └─ Full emergency withdrawal
```

**Implemented Functions:**
- `emergencyWithdrawLiquidity()` - Line 480, 560
  - Status: WORKING
  - Used for emergency withdrawals
  - Deployed when liquidations needed

**Missing Functions:**
- `addLiquidity()` - NEVER CALLED
  - Line 314: Approval happens but no call
  - Line 377: TODO comment for add liquidity
  - Line 381: TODO comment for add liquidity call
  - Needed for capital deployment

- `removeLiquidity()` - NEVER CALLED
  - Line 404: TODO comment for remove liquidity
  - Needed for rebalancing down

- `getReserves()` - NEVER CALLED
  - Line 378: TODO comment to use it
  - Needed to calculate USDF amount

**Integration Requirements:**
1. Must support `addLiquidity()` with both tokens
2. Must track LP tokens returned
3. Must support `removeLiquidity()` to exit positions
4. Must handle slippage parameters
5. Must provide reserve querying

### 7.3 Integration with TroveManager

**Dependency Flow:**
```
TroveManager (manages borrowing)
    ↓
    └─ withdrawFromStrategies() → Called during liquidations
        └─ TroveManager requests collateral for repayment
```

**Integration Points:**
1. **Access Control** - Line 222
   - Requires TROVE_MANAGER_ROLE
   - Ensures only legitimate liquidations call withdrawal

2. **withdrawFromStrategies()** - Called during liquidations
   - Input: asset, amount, destination
   - Purpose: Get collateral for repayment
   - Uses: Cascading withdrawal strategy
   - Status: Partially broken (vaults/staking not implemented)

### 7.4 Integration with AccessControl

**Access Control Architecture:**
```
AccessControl (manages roles)
    ↓
    ├─ ADMIN_ROLE - allocateCollateral(), rebalance() admin functions
    │   ├─ setFluidAMM()
    │   ├─ setVaultManager()
    │   ├─ setStakingPool()
    │   ├─ activateAsset()
    │   ├─ deactivateAsset()
    │   ├─ setAllocationConfig()
    │   └─ unpause()
    │
    ├─ EMERGENCY_ROLE
    │   ├─ emergencyRecallAll()
    │   ├─ pause()
    │   └─ withdrawFromStrategies() [via onlyTroveManager]
    │
    └─ TROVE_MANAGER_ROLE
        └─ withdrawFromStrategies()
```

**Status:** Working as designed

### 7.5 Integration with Vault Manager (When Implemented)

**Required Interface:**
```solidity
interface IVaultManager {
    function deposit(address asset, uint256 amount) external;
    function withdraw(address asset, uint256 amount) external;
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Integration Points:**
1. **allocateCollateral()** - Lines 266-274
   - Check manager exists if vaults enabled
   - [NOT IMPLEMENTED] Transfer collateral and call deposit()

2. **rebalance()** - Lines 345-348, 357-359
   - Check manager exists if vaults enabled
   - [NOT IMPLEMENTED] Rebalance to/from vaults

3. **withdrawFromStrategies()** - Lines 490-496
   - Check manager exists
   - [NOT IMPLEMENTED] Call withdraw()
   - State update happens but transfer doesn't

4. **emergencyRecallAll()** - Lines 566-570
   - [NOT IMPLEMENTED] Call emergency withdrawal
   - State update only (NO-OP)

**Status:** PLACEHOLDER ONLY

### 7.6 Integration with Staking Pool (When Implemented)

**Required Interface:**
```solidity
interface IStakingPool {
    function stake(address asset, uint256 amount) external;
    function unstake(address asset, uint256 amount) external;
    function emergencyWithdraw(address asset, uint256 amount) external;
}
```

**Integration Points:**
1. **allocateCollateral()** - Lines 271-274
   - Check pool exists if staking enabled
   - [NOT IMPLEMENTED] Transfer collateral and call stake()

2. **rebalance()** - Lines 350-353, 360-361
   - Check pool exists if staking enabled
   - [NOT IMPLEMENTED] Rebalance to/from staking

3. **withdrawFromStrategies()** - Lines 505-511
   - Check pool exists
   - [NOT IMPLEMENTED] Call unstake()
   - State update happens but transfer doesn't

4. **emergencyRecallAll()** - Lines 572-577
   - [NOT IMPLEMENTED] Call emergency withdrawal
   - State update only (NO-OP)

**Status:** PLACEHOLDER ONLY

---

## 8. RECOMMENDED FIX ORDER

### Priority 1: CRITICAL (Blocks deployment)

#### 1.1 Fix emergencyRecallAll() Return Mechanism
**Lines:** 583-586
**Work:** 2-4 hours
**Steps:**
1. Add call to `liquidityCore.depositCollateral()` or `returnToUnifiedPool()`
2. Actually transfer tokens (not just approve)
3. Add tests for emergency return
4. Test with mainnet fork simulation

**Code:**
```solidity
// BEFORE
if (totalRecalled > 0) {
    IERC20(asset).forceApprove(address(liquidityCore), totalRecalled);
    // Note: Would need LiquidityCore function to accept returns
}

// AFTER
if (totalRecalled > 0) {
    IERC20(asset).safeTransfer(address(liquidityCore), totalRecalled);
    // Call the appropriate method to register return
    liquidityCore.depositCollateral(asset, address(this), totalRecalled);
}
```

#### 1.2 Implement allocateCollateral() AMM Deployment
**Lines:** 302-316
**Work:** 4-6 hours
**Dependencies:**
- Need USDF sourcing strategy decided
- Need FluidAMM integration tested
**Steps:**
1. Query pool reserves
2. Calculate optimal USDF amount
3. Handle USDF approval/sourcing
4. Call addLiquidity()
5. Track LP tokens
6. Test with mock AMM

**Issues to solve:**
- Where does USDF come from?
- How to handle slippage?
- LP token tracking?

#### 1.3 Implement rebalance() AMM Operations
**Lines:** 363-422
**Work:** 6-8 hours
**Dependencies:**
- Depends on 1.2 (allocateCollateral AMM)
- FluidAMM fully integrated
**Steps:**
1. Implement add liquidity path (currentAMM < targetAMM)
   - Query reserves
   - Calculate USDF needed
   - Call addLiquidity()
   - Update LP tokens
2. Implement remove liquidity path (currentAMM > targetAMM)
   - Calculate LP tokens to burn
   - Call removeLiquidity()
   - Return collateral to LCore
   - Update LP tokens
3. Test both rebalancing directions

#### 1.4 Fix withdrawFromStrategies() Vault/Staking
**Lines:** 490-496, 505-511
**Work:** 3-4 hours (after vault/staking ready)
**Dependencies:**
- IVaultManager interface
- IStakingPool interface
- Vault/Staking contracts deployed
**Steps:**
1. Uncomment and complete vault withdrawal
2. Uncomment and complete staking unstaking
3. Ensure actual tokens transferred before state update
4. Test withdrawal paths

---

### Priority 2: HIGH (Enables vault/staking)

#### 2.1 Create IVaultManager Interface
**Work:** 2-3 hours
**Steps:**
1. Define vault deposit/withdraw/emergency functions
2. Plan vault integration architecture
3. Create interface file
4. Document vault requirements

#### 2.2 Create IStakingPool Interface
**Work:** 2-3 hours
**Steps:**
1. Define staking stake/unstake/emergency functions
2. Plan staking integration architecture
3. Create interface file
4. Document staking requirements

#### 2.3 Implement Vault Integration
**Work:** 8-12 hours (after vaults ready)
**Steps:**
1. Implement allocateCollateral vault allocation
2. Implement rebalance vault logic
3. Implement withdrawFromStrategies vault withdrawal
4. Implement emergencyRecallAll vault recall
5. Test all vault paths

#### 2.4 Implement Staking Integration
**Work:** 8-12 hours (after staking ready)
**Steps:**
1. Implement allocateCollateral staking allocation
2. Implement rebalance staking logic
3. Implement withdrawFromStrategies staking unstaking
4. Implement emergencyRecallAll staking recall
5. Test all staking paths

---

### Priority 3: MEDIUM (Enhancements)

#### 3.1 Add LP Token Tracking
**Work:** 2-3 hours
**Steps:**
1. Update allocation struct (done - lpTokensOwned field exists)
2. Track LP tokens in addLiquidity()
3. Subtract LP tokens in removeLiquidity()
4. Add getter function for LP token balance
5. Test LP token accounting

#### 3.2 Multi-Pool Support
**Work:** 4-6 hours
**Steps:**
1. Add mapping asset => poolId[]
2. Distribute liquidity across pools
3. Rebalance across multiple pools
4. Emergency withdrawal from all pools

#### 3.3 Slippage Configuration
**Work:** 2-3 hours
**Steps:**
1. Add setSlippageTolerance() function
2. Store slippage per asset
3. Use in addLiquidity/removeLiquidity
4. Default to 1% (100 bps)

#### 3.4 Automated Rebalancing Keeper
**Work:** 6-8 hours
**Steps:**
1. Design keeper bot interface
2. Add keeper incentive mechanism
3. Implement rate limiting
4. Deploy and monitor keeper

---

### Priority 4: TESTING

#### 4.1 Unit Tests
**Work:** 16-20 hours
**Coverage:**
- All view functions
- All state transitions
- Error conditions
- Access control

#### 4.2 Integration Tests
**Work:** 12-16 hours
**Coverage:**
- LiquidityCore integration
- FluidAMM integration
- Vault integration
- Staking integration

#### 4.3 Security Testing
**Work:** 8-12 hours
**Coverage:**
- Reentrancy tests
- Slippage tests
- Liquidation scenarios
- Emergency scenarios

#### 4.4 Mainnet Fork Tests
**Work:** 4-8 hours
**Coverage:**
- Real token interactions
- Realistic utilization
- Edge cases
- Gas optimization

---

## 9. SUMMARY TABLE

| Component | Status | Lines | Issues | Priority |
|-----------|--------|-------|--------|----------|
| **allocateCollateral() AMM** | BROKEN | 302-316 | No addLiquidity call | CRITICAL |
| **rebalance() Add Liquidity** | BROKEN | 363-396 | No addLiquidity call | CRITICAL |
| **rebalance() Remove Liquidity** | BROKEN | 397-422 | No removeLiquidity call | CRITICAL |
| **emergencyRecallAll()** | BROKEN | 583-586 | No deposit/return call | CRITICAL |
| **withdrawFromStrategies() Vaults** | BROKEN | 490-496 | Commented out, state-only | CRITICAL |
| **withdrawFromStrategies() Staking** | BROKEN | 505-511 | Commented out, state-only | CRITICAL |
| **Access Control** | WORKING | 214-226, 222-226 | N/A | N/A |
| **View Functions** | WORKING | 593-720 | N/A | N/A |
| **Admin Functions** | WORKING | 727-862 | N/A | N/A |
| **IVaultManager Interface** | MISSING | N/A | Need to create | HIGH |
| **IStakingPool Interface** | MISSING | N/A | Need to create | HIGH |
| **Vault Allocation** | NOT IMPL | 297-306 | Need implementation | HIGH |
| **Staking Allocation** | NOT IMPL | 308-318 | Need implementation | HIGH |
| **Vault Rebalancing** | NOT IMPL | 359-364 | Need implementation | HIGH |
| **Staking Rebalancing** | NOT IMPL | 366-371 | Need implementation | HIGH |
| **LP Token Tracking** | PARTIAL | 35, 391, 413 | Need full tracking | MEDIUM |
| **Multi-Pool Support** | NOT IMPL | N/A | Need implementation | MEDIUM |
| **Dynamic Allocation** | NOT IMPL | N/A | Need implementation | MEDIUM |

---

## 10. QUICK REFERENCE - LINE NUMBERS

### Critical Sections
- **Header TODOs:** Lines 19-117 (99 lines of TODO documentation)
- **Constructor:** Lines 200-210
- **Modifiers:** Lines 214-226
- **allocateCollateral():** Lines 235-319 (85 lines)
- **rebalance():** Lines 326-430 (105 lines)
- **withdrawFromStrategies():** Lines 439-540 (102 lines)
- **emergencyRecallAll():** Lines 546-589 (44 lines)
- **View Functions:** Lines 593-720 (128 lines)
- **Admin Functions:** Lines 727-862 (136 lines)
- **Helper Functions:** Lines 866-881 (16 lines)

### Broken Code Sections
- **allocateCollateral AMM:** Lines 302-316
- **rebalance Add:** Lines 363-396
- **rebalance Remove:** Lines 397-422
- **withdrawFromStrategies Vaults:** Lines 490-496
- **withdrawFromStrategies Staking:** Lines 505-511
- **emergencyRecallAll Return:** Lines 583-586

### TODO Comments in Code
- Line 314: AMM pairing amount calculation
- Line 364: Add liquidity to AMM
- Lines 377-392: Add liquidity implementation (6 steps)
- Line 398: Remove liquidity from AMM
- Lines 401-416: Remove liquidity implementation (4 steps)
- Line 494: Vault withdrawal
- Line 509: Staking unstaking

---

## 11. INTERFACE DEPENDENCIES

### Currently Defined Interfaces Used
1. **ICapitalEfficiencyEngine** - 235 lines (this contract implements)
2. **IFluidAMM** - 377 lines (partially integrated)
3. **ILiquidityCore** - 352 lines (partially integrated)
4. **ITroveManager** - (role checking only)

### Missing Interfaces (Need to Create)
1. **IVaultManager** - Should define vault operations
2. **IStakingPool** - Should define staking operations

### Optional/Future Interfaces
1. **IYieldOracle** - For dynamic allocation (TODO 8)
2. **IKeeper** - For automated rebalancing (TODO 10)

---

**END OF ANALYSIS**

Generated with comprehensive review of CapitalEfficiencyEngine.sol (881 lines)
Date: 2025-11-27

