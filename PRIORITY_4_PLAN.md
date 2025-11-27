# Priority 4: Testing, Deployment & Integration Setup

## Overview
After completing Priority 3 (CapitalEfficiencyEngine implementation), we now focus on:
1. **Comprehensive Testing** - Ensure all Priority 1-3 implementations work correctly
2. **Testnet Deployment** - Deploy to Polygon Amoy with proper configuration
3. **Integration Setup** - Configure vault, staking, and AMM integrations
4. **End-to-End Validation** - Test complete user flows

---

## Phase 4.1: Comprehensive Testing Suite

### 4.1.1 Unit Tests - CapitalEfficiencyEngine

**Test File**: `test/CapitalEfficiencyEngine.test.ts`

#### Test Group 1: allocateCollateral() - AMM Integration
```typescript
describe("allocateCollateral() - AMM Integration", () => {
  it("Should allocate collateral to AMM with correct ratios")
  it("Should calculate USDF pairing amount from pool reserves")
  it("Should handle zero pool reserves gracefully")
  it("Should respect slippage tolerance (1%)")
  it("Should update lpTokensOwned correctly")
  it("Should revert if AMM not set")
  it("Should revert if asset not active")
  it("Should revert if insufficient collateral")
  it("Should emit AllocationUpdated event")
  it("Should handle edge case: very small allocation")
  it("Should handle edge case: very large allocation")
})
```

#### Test Group 2: rebalance() - ADD Liquidity Path
```typescript
describe("rebalance() - Add Liquidity Path", () => {
  it("Should add liquidity when currentAMM < targetAMM")
  it("Should calculate correct LP tokens to mint")
  it("Should respect 5% slippage tolerance")
  it("Should handle drift > 5% threshold")
  it("Should update _allocations[asset].amm correctly")
  it("Should transfer USDF from LiquidityCore")
  it("Should return excess USDF to LiquidityCore")
  it("Should emit Rebalanced event with ADD reason")
  it("Should revert if pool has no liquidity")
})
```

#### Test Group 3: rebalance() - REMOVE Liquidity Path
```typescript
describe("rebalance() - Remove Liquidity Path", () => {
  it("Should remove liquidity when currentAMM > targetAMM")
  it("Should calculate correct LP tokens to burn")
  it("Should respect 5% slippage tolerance")
  it("Should return collateral to LiquidityCore")
  it("Should return USDF to LiquidityCore")
  it("Should update lpTokensOwned correctly")
  it("Should handle case when lpTokensOwned = 0")
  it("Should emit Rebalanced event with REMOVE reason")
  it("Should handle drift < -5% threshold")
})
```

#### Test Group 4: emergencyRecallAll() - Fund Recovery
```typescript
describe("emergencyRecallAll() - Fund Recovery", () => {
  it("Should recall all collateral from AMM")
  it("Should recall all collateral from vaults")
  it("Should recall all collateral from staking")
  it("Should return funds to LiquidityCore via depositCollateral()")
  it("Should handle cascading withdrawal if earlier stage fails")
  it("Should emit FundsRecalled event with amounts")
  it("Should revert if asset not active")
  it("Should set asset.totalAllocated = 0 after recall")
  it("Should handle case where some strategies unavailable")
})
```

#### Test Group 5: Access Control & Security
```typescript
describe("Access Control & Security", () => {
  it("Should only allow ADMIN_ROLE for allocateCollateral()")
  it("Should only allow ADMIN_ROLE for rebalance()")
  it("Should only allow ADMIN_ROLE for setFluidAMM()")
  it("Should only allow ADMIN_ROLE for setVaultManager()")
  it("Should only allow TROVE_MANAGER_ROLE for updateHealth()")
  it("Should be protected by nonReentrant guard")
  it("Should respect whenNotPaused modifier")
  it("Should validate all zero-address inputs")
})
```

---

### 4.1.2 Integration Tests - Full Protocol Flow

**Test File**: `test/V2FullFlow.test.ts`

#### Test 1: User Opens Trove → Allocates Collateral → Rebalances
```typescript
it("Should handle complete flow: open trove -> allocate -> rebalance", async () => {
  // Step 1: User opens trove with 100 WETH
  // Step 2: CapitalEfficiencyEngine allocates 100 WETH
  //   - 30 WETH stays in reserve
  //   - 40 WETH goes to AMM
  //   - 20 WETH goes to vault (future)
  //   - 10 WETH goes to staking (future)
  // Step 3: Verify allocations match targets
  // Step 4: Trigger rebalance after drift
  // Step 5: Verify final state
})
```

#### Test 2: Multiple Users → Cross-Collateral Debt Aggregation
```typescript
it("Should aggregate debt across multiple users and collaterals", async () => {
  // Step 1: Alice opens trove with 50 WETH, borrows 5000 USDF
  // Step 2: Bob opens trove with 100 WBTC, borrows 10000 USDF
  // Step 3: Carol opens trove with 25 WETH, borrows 2500 USDF
  // Step 4: Verify cross-collateral debt aggregation:
  //   - Alice debt: 5000 USDF
  //   - Bob debt: 10000 USDF
  //   - Carol debt: 2500 USDF
  // Step 5: Verify MCR checks use total debt value
  // Step 6: Verify liquidation considers all debt
})
```

#### Test 3: Capital Efficiency Engine Recall → Close Trove
```typescript
it("Should handle emergency recall during closeTrove", async () => {
  // Step 1: User opens trove with collateral
  // Step 2: CapitalEfficiencyEngine allocates to AMM
  // Step 3: Trigger emergencyRecallAll()
  // Step 4: User closes trove
  // Step 5: Verify all collateral returned to user
  // Step 6: Verify AMM position fully exited
})
```

---

### 4.1.3 Edge Case Tests

**Test File**: `test/EdgeCases.test.ts`

```typescript
describe("Edge Cases & Stress Tests", () => {
  describe("Pool Liquidity Edge Cases", () => {
    it("Should handle when AMM pool has minimal liquidity")
    it("Should handle when AMM pool becomes empty")
    it("Should handle slippage exceeding tolerance")
    it("Should handle flash loan scenarios")
  })

  describe("Allocation Edge Cases", () => {
    it("Should handle zero allocation amount")
    it("Should handle very large allocation (>1M collateral)")
    it("Should handle allocation when reserve full")
    it("Should handle multiple sequential allocations")
  })

  describe("Rebalancing Edge Cases", () => {
    it("Should handle tiny drift (e.g., 0.01%)")
    it("Should handle massive drift (e.g., >50%)")
    it("Should handle rapid price swings")
    it("Should handle rebalance when all strategies at capacity")
  })

  describe("Vault/Staking Integration Edge Cases", () => {
    it("Should handle vault returning 0 shares")
    it("Should handle staking pool fully utilized")
    it("Should handle strategy contract becoming non-responsive")
    it("Should handle strategy withdrawal reverting")
  })

  describe("Cross-Collateral Edge Cases", () => {
    it("Should handle MCR check with 100+ collateral types")
    it("Should handle liquidation with multiple collaterals")
    it("Should handle debt accrual across different collaterals")
    it("Should handle rebalancing with unequal collateral values")
  })
})
```

---

## Phase 4.2: Polygon Amoy Testnet Deployment

### 4.2.1 Pre-Deployment Checklist

- [ ] Verify all 67 contracts compile with no errors
- [ ] Verify deployment script includes USDF token parameter
- [ ] Verify gas estimates for all deployments
- [ ] Verify environment variables set correctly:
  - [ ] PRIVATE_KEY (deployer account)
  - [ ] POLYGONSCAN_API_KEY (for verification)
  - [ ] RPC_URL (Polygon Amoy endpoint)
- [ ] Get free MATIC from faucet (minimum 1 MATIC for deployment)

### 4.2.2 Deployment Steps

```bash
# Step 1: Get testnet MATIC
# https://faucet.polygon.technology/

# Step 2: Deploy to Amoy
npx hardhat run scripts/deploy-polygon-amoy.ts --network polygon-amoy

# Step 3: Verify contracts on Polygonscan
# Deployment script will attempt verification automatically
# Manual verification: npx hardhat verify --network polygon-amoy <ADDRESS> <CONSTRUCTOR_ARGS>

# Step 4: Save deployment addresses
# Script automatically saves to deployments/polygon-amoy-latest.json
```

### 4.2.3 Expected Deployment Order

1. AccessControlManager
2. USDF Token (MockERC20)
3. Mock WETH (MockERC20)
4. Mock WBTC (MockERC20)
5. MockOrochiOracle
6. PriceOracle (with Oracle address)
7. UnifiedLiquidityPool
8. LiquidityCore
9. SortedTroves
10. BorrowerOperationsV2
11. TroveManagerV2
12. **CapitalEfficiencyEngine** (with USDF token parameter)
13. FluidAMM
14. Setup: Grant roles to each contract
15. Setup: Configure USDF minting

### 4.2.4 Post-Deployment Verification

```typescript
// Verify deployments
- [ ] Check each contract address on Polygonscan
- [ ] Verify AccessControlManager has ADMIN_ROLE
- [ ] Verify USDF has correct decimals (6)
- [ ] Verify WETH has correct decimals (18)
- [ ] Verify WBTC has correct decimals (8)
- [ ] Verify PriceOracle oracle address set correctly
- [ ] Verify CapitalEfficiencyEngine has usdfToken set
- [ ] Verify FluidAMM has correct oracle reference
- [ ] Verify LiquidityCore has borrower ops and trove manager set
- [ ] Test setter functions: setFluidAMM(), setVaultManager(), etc.
- [ ] Test basic flow: openTrove() → allocateCollateral()
```

---

## Phase 4.3: Integration Setup

### 4.3.1 FluidAMM Integration

**Current Status**: ✅ Deployed in script

**Verification Needed**:
1. Test `getReserves()` returns correct values
2. Test `addLiquidity()` with actual CapitalEfficiencyEngine
3. Test `removeLiquidity()` with LP token burning
4. Verify price oracle integration
5. Verify slippage protection works

**Test Scenario**:
```typescript
it("Should integrate with FluidAMM correctly", async () => {
  // Create WETH-USDF pair
  await fluidAMM.createPair(weth.address, usdf.address);

  // Add initial liquidity: 100 WETH + 200000 USDF (arbitrary ratio)
  await weth.approve(fluidAMM.address, 100);
  await usdf.approve(fluidAMM.address, 200000);
  await fluidAMM.addLiquidity(weth.address, usdf.address, 100, 200000, 99, 198000);

  // Now allocate collateral through CapitalEfficiencyEngine
  await capitalEngine.allocateCollateral(weth.address, 40);

  // Verify LP tokens received
  const lpBalance = await fluidAMM.balanceOf(capitalEngine.address);
  expect(lpBalance).to.be.gt(0);
});
```

### 4.3.2 Vault Manager Placeholder

**Status**: Interface created, implementation pending

**Temporary Setup** (for testing):
```solidity
// Create mock vault for testing
contract MockVaultManager {
  mapping(address => mapping(address => uint256)) balances;

  function deposit(address asset, uint256 amount) external {
    // Just store collateral
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    balances[msg.sender][asset] += amount;
  }

  function emergencyWithdraw(address asset, uint256 amount) external {
    // Return collateral
    require(balances[msg.sender][asset] >= amount, "Insufficient balance");
    balances[msg.sender][asset] -= amount;
    IERC20(asset).transfer(msg.sender, amount);
  }
}
```

### 4.3.3 Staking Pool Placeholder

**Status**: Interface created, implementation pending

**Temporary Setup** (for testing):
```solidity
// Create mock staking for testing
contract MockStakingPool {
  mapping(address => mapping(address => uint256)) staked;

  function stake(address asset, uint256 amount) external returns (uint256 shares) {
    // 1:1 share ratio for testing
    IERC20(asset).transferFrom(msg.sender, address(this), amount);
    staked[msg.sender][asset] += amount;
    return amount; // shares = amount
  }

  function emergencyWithdraw(address asset, uint256 amount) external {
    // Return staked collateral
    require(staked[msg.sender][asset] >= amount, "Insufficient stake");
    staked[msg.sender][asset] -= amount;
    IERC20(asset).transfer(msg.sender, amount);
  }
}
```

### 4.3.4 Integration Test Flow

```typescript
describe("Full Integration Setup", () => {
  before(async () => {
    // Deploy all contracts
    // Deploy mock vault & staking
    // Set addresses in CapitalEfficiencyEngine
  })

  it("Should allocate collateral through all three strategies", async () => {
    // Allocate 100 WETH:
    // - 30 WETH in reserve
    // - 40 WETH to AMM (actual)
    // - 20 WETH to vault (mock)
    // - 10 WETH to staking (mock)

    await capitalEngine.allocateCollateral(weth.address, 100);

    // Verify allocations
    expect(await liquidityCore.getAvailable(weth.address)).to.equal(30);
    expect(await fluidAMM.balanceOf(capitalEngine.address)).to.be.gt(0); // LP tokens
    expect(await mockVault.balanceOf(capitalEngine.address)).to.equal(20);
    expect(await mockStaking.balanceOf(capitalEngine.address)).to.equal(10);
  });

  it("Should rebalance across all strategies", async () => {
    // Trigger rebalance with new targets
    // Verify funds move between strategies
  });

  it("Should recall all funds in emergency", async () => {
    // Call emergencyRecallAll()
    // Verify all funds returned to LiquidityCore
  });
});
```

---

## Phase 4.4: End-to-End Validation

### 4.4.1 User Flow Tests

**Test 1: New User Opening Trove**
```
1. User deposits 50 WETH as collateral
2. User borrows 5000 USDF (against 50 WETH)
3. System allocates:
   - 15 WETH (30%) to reserve
   - 20 WETH (40%) to AMM
   - 10 WETH (20%) to vault
   - 5 WETH (10%) to staking
4. Verify user can withdraw USDF
5. Verify interest accrues correctly
6. Verify AMM earns fees (tracked via LP tokens)
```

**Test 2: User Adjusting Trove**
```
1. User adds 10 more WETH collateral
2. User increases borrow to 6000 USDF
3. Verify cross-collateral MCR still satisfied
4. Verify rebalancing triggered if drift > 5%
5. Verify capital efficiency unchanged
```

**Test 3: User Closing Trove**
```
1. Capital efficiency engine recalls allocated collateral
2. User returns USDF with accrued interest
3. User receives collateral back
4. Verify no dust left in system
5. Verify AMM position fully exited
```

### 4.4.2 Admin Operations Tests

**Test 1: Emergency Pause**
```
- Verify ADMIN_ROLE can pause contract
- Verify no allocations possible while paused
- Verify no rebalancing while paused
- Verify recall still works in emergency
```

**Test 2: Configuration Updates**
```
- Admin updates allocation percentages
- Admin updates rebalance thresholds
- Admin sets vault manager address
- Admin sets staking pool address
- Verify changes take effect immediately
```

### 4.4.3 Multi-Collateral Scenario

```typescript
it("Should handle full multi-collateral scenario", async () => {
  // Alice: Opens trove with WETH
  // Bob: Opens trove with WBTC
  // Carol: Opens trove with WETH + WBTC (multiple collaterals)

  // Verify debt aggregation across all three
  const aliceDebt = 5000;  // USDF value
  const bobDebt = 10000;   // USDF value
  const carolDebtTotal = 7500; // Combined across both collaterals

  // Verify MCR checks consider total debt
  // Verify liquidation considers all collateral values
  // Verify capital allocation spread across assets

  // Carol adjusts position (add WETH, borrow more)
  // Verify system rebalances efficiently
});
```

---

## Testing Timeline & Checklist

### Week 1: Unit Tests & Local Testing
- [ ] Write all CapitalEfficiencyEngine unit tests
- [ ] Run tests locally with hardhat network
- [ ] Verify >95% code coverage
- [ ] Fix any bugs found during testing

### Week 2: Integration Tests & Amoy Deployment
- [ ] Write integration tests
- [ ] Deploy to Polygon Amoy testnet
- [ ] Verify deployments on Polygonscan
- [ ] Run integration tests against testnet contracts

### Week 3: End-to-End Testing & Fixes
- [ ] Write end-to-end user flow tests
- [ ] Test multi-collateral scenarios
- [ ] Stress test with multiple users
- [ ] Test edge cases and emergency scenarios
- [ ] Fix any issues found

### Week 4: Security & Performance
- [ ] Run security audit on critical functions
- [ ] Measure gas usage for all operations
- [ ] Optimize high-cost operations
- [ ] Create security documentation

---

## What's Already Done (for reference)

### Priority 1: Access Control & Emergency Mechanisms
✅ Fixed access control vulnerabilities
✅ Implemented proper emergency recall mechanism
✅ Added LIQUIDITY_CORE_ROLE validation

### Priority 2: Cross-Collateral Debt Aggregation
✅ Added userTotalDebtValue mapping
✅ Implemented getTotalUserCollateralValue()
✅ Cross-collateral MCR validation in borrow()
✅ Cross-collateral liquidation logic

### Priority 3: Capital Efficiency Engine
✅ Fixed usdfToken undefined variable
✅ Implemented allocateCollateral() with AMM integration
✅ Implemented rebalance() with add/remove liquidity paths
✅ Implemented emergencyRecallAll() with cascading withdrawal
✅ Created IVaultManager and IStakingPool interfaces
✅ Implemented withdrawFromStrategies() vault/staking calls
✅ Updated deployment script with usdfToken parameter
✅ All 67 contracts compile successfully

---

## Success Criteria

✅ Priority 4 is considered complete when:

1. **Testing**: >95% code coverage on all critical functions
2. **Deployment**: All contracts deployed to Polygon Amoy testnet successfully
3. **Integration**: FluidAMM, vault, and staking integrations working
4. **Validation**: All end-to-end user flows tested and working
5. **Security**: No critical or high-severity issues found
6. **Documentation**: Complete API and integration documentation

---

## Next Steps

**Immediate** (Today):
1. Create unit test file structure
2. Begin writing CapitalEfficiencyEngine tests
3. Set up mock contracts for vault/staking

**This Week**:
1. Complete all unit tests (>95% coverage)
2. Run tests locally with hardhat network
3. Fix any bugs found

**Next Week**:
1. Deploy to Polygon Amoy testnet
2. Verify all deployments
3. Run integration tests against testnet

**Following Week**:
1. Write and run end-to-end tests
2. Conduct security review
3. Optimize gas usage

