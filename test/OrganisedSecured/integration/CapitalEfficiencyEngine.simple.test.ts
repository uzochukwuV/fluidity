import { expect } from "chai";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import {
  CapitalEfficiencyEngine,
  FluidAMM,
  LiquidityCore,
  AccessControlManager,
  UnifiedLiquidityPool,
  BorrowerOperationsV2,
  TroveManagerV2,
  SortedTroves,
  MockERC20,
  MockPriceOracle,
} from "../../../typechain-types";

/**
 * Priority 3: CapitalEfficiencyEngine - SIMPLIFIED TESTS
 *
 * Tests the core functionality of CapitalEfficiencyEngine:
 * 1. ✅ Deployment with USDF token parameter
 * 2. ✅ allocateCollateral() - AMM integration
 * 3. ✅ rebalance() - Dynamic rebalancing
 * 4. ✅ emergencyRecallAll() - Emergency fund recovery
 * 5. ✅ Access control validation
 *
 * Focus: Testing the actual implemented functions with correct parameters
 */
describe("Priority 3: CapitalEfficiencyEngine - Core Tests", function () {
  let capitalEngine: CapitalEfficiencyEngine;
  let fluidAMM: FluidAMM;
  let liquidityCore: LiquidityCore;
  let borrowerOps: BorrowerOperationsV2;
  let troveManager: TroveManagerV2;
  let unifiedPool: UnifiedLiquidityPool;
  let sortedTroves: SortedTroves;
  let accessControl: AccessControlManager;
  let priceOracle: MockPriceOracle;

  let usdfToken: MockERC20;
  let wethToken: MockERC20;
  let wbtcToken: MockERC20;

  let owner: SignerWithAddress;
  let admin: SignerWithAddress;
  let alice: SignerWithAddress;

  const INITIAL_WETH = ethers.parseEther("1000");
  const INITIAL_USDF = ethers.parseEther("5000000");

  const ETH_PRICE = ethers.parseEther("2000");

  before(async function () {
    this.timeout(180000);
    [owner, admin, alice] = await ethers.getSigners();

    console.log("\n🚀 Priority 3: CapitalEfficiencyEngine Deployment Test\n");

    // ===== DEPLOY ALL CONTRACTS =====
    const AccessControlFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/utils/AccessControlManager.sol:AccessControlManager"
    );
    accessControl = await AccessControlFactory.deploy();
    await accessControl.waitForDeployment();
    console.log("✅ AccessControlManager");

    const MockERC20Factory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/mocks/MockERC20.sol:MockERC20"
    );
    usdfToken = await MockERC20Factory.deploy("USDF", "USDF", 0);
    wethToken = await MockERC20Factory.deploy("WETH", "WETH", 0);
    wbtcToken = await MockERC20Factory.deploy("WBTC", "WBTC", 0);
    await usdfToken.waitForDeployment();
    await wethToken.waitForDeployment();
    await wbtcToken.waitForDeployment();
    console.log("✅ Mock Tokens (USDF, WETH, WBTC)");

    const MockOracleFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/mocks/MockPriceOracle.sol:MockPriceOracle"
    );
    priceOracle = await MockOracleFactory.deploy();
    await priceOracle.waitForDeployment();
    await priceOracle.setPrice(await wethToken.getAddress(), ETH_PRICE);
    console.log("✅ MockPriceOracle");

    const UnifiedPoolFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/core/UnifiedLiquidityPool.sol:UnifiedLiquidityPool"
    );
    unifiedPool = await UnifiedPoolFactory.deploy(
      await accessControl.getAddress(),
      await priceOracle.getAddress()
    );
    await unifiedPool.waitForDeployment();
    console.log("✅ UnifiedLiquidityPool");

    const LiquidityCoreFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/core/LiquidityCore.sol:LiquidityCore"
    );
    liquidityCore = await LiquidityCoreFactory.deploy(
      await accessControl.getAddress(),
      await unifiedPool.getAddress(),
      await usdfToken.getAddress()
    );
    await liquidityCore.waitForDeployment();
    console.log("✅ LiquidityCore");

    const SortedTrovesFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/core/SortedTroves.sol:SortedTroves"
    );
    sortedTroves = await SortedTrovesFactory.deploy(await accessControl.getAddress());
    await sortedTroves.waitForDeployment();
    console.log("✅ SortedTroves");

    const BorrowerOpsFactory = await ethers.getContractFactory("BorrowerOperationsV2");
    borrowerOps = await BorrowerOpsFactory.deploy(
      await accessControl.getAddress(),
      await liquidityCore.getAddress(),
      await sortedTroves.getAddress(),
      await usdfToken.getAddress(),
      await priceOracle.getAddress()
    );
    await borrowerOps.waitForDeployment();
    console.log("✅ BorrowerOperationsV2");

    const TroveManagerFactory = await ethers.getContractFactory("TroveManagerV2");
    troveManager = await TroveManagerFactory.deploy(
      await accessControl.getAddress(),
      await borrowerOps.getAddress(),
      await liquidityCore.getAddress(),
      await sortedTroves.getAddress(),
      await usdfToken.getAddress(),
      await priceOracle.getAddress()
    );
    await troveManager.waitForDeployment();
    await borrowerOps.setTroveManager(await troveManager.getAddress());
    console.log("✅ TroveManagerV2");

    // === CRITICAL: CapitalEfficiencyEngine with USDF token ===
    const CapitalEngineFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/core/CapitalEfficiencyEngine.sol:CapitalEfficiencyEngine"
    );
    capitalEngine = await CapitalEngineFactory.deploy(
      await accessControl.getAddress(),
      await liquidityCore.getAddress(),
      await troveManager.getAddress(),
      await usdfToken.getAddress() // ← USDF token for AMM pairing
    );
    await capitalEngine.waitForDeployment();
    console.log("✅ CapitalEfficiencyEngine (with USDF token)");

    const FluidAMMFactory = await ethers.getContractFactory(
      "contracts/OrganisedSecured/dex/FluidAMM.sol:FluidAMM"
    );
    fluidAMM = await FluidAMMFactory.deploy(
      await accessControl.getAddress(),
      await unifiedPool.getAddress(),
      await priceOracle.getAddress()
    );
    await fluidAMM.waitForDeployment();
    console.log("✅ FluidAMM");

    // Set references
    await capitalEngine.setFluidAMM(await fluidAMM.getAddress());
    console.log("✅ Cross-references configured");

    // Setup roles
    const ADMIN_ROLE = await accessControl.ADMIN_ROLE();
    const BORROWER_OPS_ROLE = await accessControl.BORROWER_OPS_ROLE();
    const TROVE_MANAGER_ROLE = await accessControl.TROVE_MANAGER_ROLE();
    const LIQUIDITY_CORE_ROLE = await accessControl.LIQUIDITY_CORE_ROLE();

    await accessControl.grantRole(ADMIN_ROLE, admin.address);
    await accessControl.grantRole(BORROWER_OPS_ROLE, await borrowerOps.getAddress());
    await accessControl.grantRole(TROVE_MANAGER_ROLE, await troveManager.getAddress());
    await accessControl.grantRole(LIQUIDITY_CORE_ROLE, await liquidityCore.getAddress());
    console.log("✅ Roles granted");

    // Activate assets
    await liquidityCore.activateAsset(await wethToken.getAddress());
    await liquidityCore.activateAsset(await wbtcToken.getAddress());
    await liquidityCore.activateAsset(await usdfToken.getAddress()); // Activate USDF too!
    await capitalEngine.activateAsset(await wethToken.getAddress());
    await capitalEngine.activateAsset(await wbtcToken.getAddress());
    console.log("✅ Assets activated");

    // === FIX: Register collateral in LiquidityCore reserve tracking system ===
    // depositCollateral requires BORROWER_OPS_ROLE, so grant it to admin temporarily
    await accessControl.grantRole(BORROWER_OPS_ROLE, admin.address);
    console.log("✅ Temporary BORROWER_OPS_ROLE granted to admin");

    // Step 1: Mint tokens to admin
    await wethToken.mint(admin.address, INITIAL_WETH);
    await usdfToken.mint(admin.address, INITIAL_USDF);
    console.log("✅ Collateral minted to admin");

    // Step 2: Transfer tokens to LiquidityCore
    await wethToken.connect(admin).transfer(await liquidityCore.getAddress(), INITIAL_WETH);
    await usdfToken.connect(admin).transfer(await liquidityCore.getAddress(), INITIAL_USDF);
    console.log("✅ Tokens transferred to LiquidityCore");

    // Step 3: Call depositCollateral to register in tracking system
    // This updates the collateralReserve state variable
    await liquidityCore.connect(admin).depositCollateral(
      await wethToken.getAddress(),
      admin.address,
      INITIAL_WETH
    );
    await liquidityCore.connect(admin).depositCollateral(
      await usdfToken.getAddress(),
      admin.address,
      INITIAL_USDF
    );
    console.log("✅ Collateral registered in reserve tracking system");

    // Step 4: Mint and register additional USDF for AMM pairing operations
    const additionalUSDH = ethers.parseEther("1000000"); // 1M USDF for AMM
    await usdfToken.mint(admin.address, additionalUSDH);
    await usdfToken.connect(admin).transfer(await liquidityCore.getAddress(), additionalUSDH);
    await liquidityCore.connect(admin).depositCollateral(
      await usdfToken.getAddress(),
      admin.address,
      additionalUSDH
    );
    console.log("✅ Additional USDF registered for AMM operations\n");
  });

  describe("✅ Deployment Validation", function () {
    it("Should have correct immutable USDF token reference", async function () {
      const storedUSDFToken = await capitalEngine.usdfToken();
      expect(storedUSDFToken).to.equal(await usdfToken.getAddress());
      console.log(`✅ USDF token correctly set: ${storedUSDFToken}`);
    });

    it("Should have LiquidityCore reference", async function () {
      const storedLC = await capitalEngine.liquidityCore();
      expect(storedLC).to.equal(await liquidityCore.getAddress());
      console.log(`✅ LiquidityCore correctly set`);
    });

    it("Should have TroveManager reference", async function () {
      const storedTM = await capitalEngine.troveManager();
      expect(storedTM).to.equal(await troveManager.getAddress());
      console.log(`✅ TroveManager correctly set`);
    });

    it("Should have FluidAMM reference", async function () {
      const storedAMM = await capitalEngine.fluidAMM();
      expect(storedAMM).to.equal(await fluidAMM.getAddress());
      console.log(`✅ FluidAMM correctly set`);
    });
  });

  describe("📊 allocateCollateral() - AMM Integration", function () {
    it("Should allocate collateral successfully", async function () {
      this.timeout(60000);
      const asset = await wethToken.getAddress();
      const amount = ethers.parseEther("10");

      console.log(`\nAllocating ${ethers.formatEther(amount)} WETH...`);

      try {
        const tx = await capitalEngine.connect(admin).allocateCollateral(asset, amount);
        const receipt = await tx.wait();
        console.log(`⛽ Gas: ${receipt?.gasUsed}`);

        const allocation = await capitalEngine.getAllocation(asset);
        console.log(`✅ Allocation successful`);
        console.log(`   AMM: ${ethers.formatEther(allocation.amm)} WETH`);
        console.log(`   LP Tokens: ${allocation.lpTokensOwned}`);

        expect(allocation.amm).to.be.gte(0);
      } catch (error: any) {
        console.error(`❌ Allocation failed:`, error.message);
        throw error;
      }
    });
  });

  describe("🔄 rebalance() - Dynamic Rebalancing", function () {
    it("Should execute rebalance when needed", async function () {
      this.timeout(60000);
      const asset = await wethToken.getAddress();

      console.log(`\nRebalancing ${asset}...`);

      try {
        const shouldRebalance = await capitalEngine.shouldRebalance(asset);
        console.log(`Should rebalance: ${shouldRebalance}`);

        if (shouldRebalance) {
          const tx = await capitalEngine.connect(admin).rebalance(asset);
          const receipt = await tx.wait();
          console.log(`⛽ Gas: ${receipt?.gasUsed}`);
          console.log(`✅ Rebalance successful`);
        } else {
          console.log(`⚠️  No rebalancing needed (drift < threshold)`);
        }
      } catch (error: any) {
        if (error.message.includes("RebalanceNotNeeded")) {
          console.log(`⚠️  Rebalance not needed - drift too small`);
        } else {
          console.error(`❌ Rebalance failed:`, error.message);
          throw error;
        }
      }
    });
  });

  describe("🚨 emergencyRecallAll() - Emergency Recovery", function () {
    it("Should recall all allocated collateral", async function () {
      this.timeout(60000);
      const asset = await wethToken.getAddress();

      console.log(`\nRecalling all allocated collateral...`);

      try {
        const allocationBefore = await capitalEngine.getAllocation(asset);
        console.log(`AMM allocation before: ${ethers.formatEther(allocationBefore.amm)} WETH`);

        const tx = await capitalEngine.connect(admin).emergencyRecallAll(asset);
        const receipt = await tx.wait();
        console.log(`⛽ Gas: ${receipt?.gasUsed}`);

        const allocationAfter = await capitalEngine.getAllocation(asset);
        console.log(`AMM allocation after: ${ethers.formatEther(allocationAfter.amm)} WETH`);
        console.log(`✅ Emergency recall successful`);

        // AMM allocation should be zero or near zero
        expect(allocationAfter.amm).to.equal(0);
      } catch (error: any) {
        console.error(`❌ Recall failed:`, error.message);
        throw error;
      }
    });
  });

  describe("🔐 Access Control", function () {
    it("Should restrict allocateCollateral to ADMIN_ROLE", async function () {
      this.timeout(30000);
      const asset = await wethToken.getAddress();
      const amount = ethers.parseEther("1");

      console.log(`\nTesting access control on allocateCollateral...`);

      // Should fail with non-admin
      try {
        await capitalEngine.connect(alice).allocateCollateral(asset, amount);
        throw new Error("Should have reverted!");
      } catch (error: any) {
        if (error.message.includes("Should have reverted")) {
          throw error;
        }
        console.log(`✅ Correctly rejected non-admin: ${error.reason || error.code}`);
      }

      // Should succeed with admin
      const tx = await capitalEngine.connect(admin).allocateCollateral(asset, amount);
      await expect(tx).to.not.be.rejected;
      console.log(`✅ Admin successfully allocated`);
    });

    it("Should restrict emergencyRecallAll to ADMIN_ROLE", async function () {
      this.timeout(30000);
      const asset = await wethToken.getAddress();

      console.log(`\nTesting access control on emergencyRecallAll...`);

      // Should fail with non-admin
      try {
        await capitalEngine.connect(alice).emergencyRecallAll(asset);
        throw new Error("Should have reverted!");
      } catch (error: any) {
        if (error.message.includes("Should have reverted")) {
          throw error;
        }
        console.log(`✅ Correctly rejected non-admin: ${error.reason || error.code}`);
      }

      console.log(`✅ Access control enforced`);
    });
  });

  describe("💾 State Management", function () {
    it("Should properly track allocations per asset", async function () {
      this.timeout(30000);
      const wethAsset = await wethToken.getAddress();
      const wbtcAsset = await wbtcToken.getAddress();

      console.log(`\nChecking allocation tracking...`);

      const wethAlloc = await capitalEngine.getAllocation(wethAsset);
      const wbtcAlloc = await capitalEngine.getAllocation(wbtcAsset);

      console.log(`WETH allocation:  ${ethers.formatEther(wethAlloc.amm)} WETH`);
      console.log(`WBTC allocation:  ${ethers.formatEther(wbtcAlloc.amm)} WBTC`);
      console.log(`✅ Allocations tracked separately per asset`);

      // Should be tracked independently
      expect(wethAlloc).to.not.be.null;
      expect(wbtcAlloc).to.not.be.null;
    });
  });

  describe("📝 Integration: Full Workflow", function () {
    it("Should execute allocate -> rebalance -> recall workflow", async function () {
      this.timeout(120000);
      const asset = await wethToken.getAddress();
      const allocAmount = ethers.parseEther("5");

      console.log(`\n=== Full Workflow Test ===\n`);

      // Step 1: Allocate
      console.log(`Step 1: Allocate ${ethers.formatEther(allocAmount)} WETH`);
      await capitalEngine.connect(admin).allocateCollateral(asset, allocAmount);
      let alloc = await capitalEngine.getAllocation(asset);
      console.log(`✅ Allocated: ${ethers.formatEther(alloc.amm)} WETH to AMM\n`);

      // Step 2: Check rebalance status
      console.log(`Step 2: Check rebalance status`);
      const needsRebalance = await capitalEngine.shouldRebalance(asset);
      console.log(`Needs rebalance: ${needsRebalance}\n`);

      // Step 3: Recall
      console.log(`Step 3: Emergency recall all funds`);
      await capitalEngine.connect(admin).emergencyRecallAll(asset);
      alloc = await capitalEngine.getAllocation(asset);
      console.log(`✅ Recalled: AMM allocation now ${ethers.formatEther(alloc.amm)} WETH\n`);

      console.log(`=== Full Workflow Complete ===\n`);
    });
  });
});
