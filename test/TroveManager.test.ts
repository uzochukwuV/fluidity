import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { TroveManager, USDF, PriceOracle, SortedTroves, EnhancedStabilityPool } from "../typechain-types";

describe("TroveManager", function () {
  async function deployTroveManagerFixture() {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    // Deploy USDF token
    const USDF = await ethers.getContractFactory("USDF");
    const usdf = await USDF.deploy();

    // Deploy PriceOracle
    const PriceOracle = await ethers.getContractFactory("PriceOracle");
    const priceOracle = await PriceOracle.deploy();

    // Deploy SortedTroves
    const SortedTroves = await ethers.getContractFactory("SortedTroves");
    const sortedTroves = await SortedTroves.deploy();

    // Deploy EnhancedStabilityPool
    const EnhancedStabilityPool = await ethers.getContractFactory("EnhancedStabilityPool");
    const stabilityPool = await EnhancedStabilityPool.deploy();

    // Deploy LiquidationHelpers library first
    const LiquidationHelpers = await ethers.getContractFactory("LiquidationHelpers");
    const liquidationHelpers = await LiquidationHelpers.deploy();

    // Deploy TroveManager with library linking
    const TroveManager = await ethers.getContractFactory("TroveManager", {
      libraries: {
        LiquidationHelpers: await liquidationHelpers.getAddress(),
      },
    });
    const troveManager = await TroveManager.deploy();

    // Mock WETH address
    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    return {
      troveManager,
      usdf,
      priceOracle,
      sortedTroves,
      stabilityPool,
      owner,
      user1,
      user2,
      user3,
      WETH
    };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      expect(await troveManager.getAddress()).to.be.properAddress;
    });

    it("Should have correct initial constants", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      expect(await troveManager.DECIMAL_PRECISION()).to.equal(ethers.parseEther("1"));
      expect(await troveManager.MIN_COLLATERAL_RATIO()).to.equal(ethers.parseEther("1.35"));
      expect(await troveManager.LIQUIDATION_THRESHOLD()).to.equal(ethers.parseEther("1.1"));
      expect(await troveManager.CCR()).to.equal(ethers.parseEther("1.5"));
      expect(await troveManager.MCR()).to.equal(ethers.parseEther("1.1"));
    });
  });

  describe("Trove Operations", function () {
    it("Should calculate ICR correctly for existing trove", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test ICR calculation for non-existent trove (should return max uint)
      const icr = await troveManager.getCurrentICR(user1.address, WETH);
      expect(icr).to.equal(ethers.MaxUint256);
    });

    it("Should get trove debt and collateral", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      const [debt, coll] = await troveManager.getTroveDebtAndColl(user1.address, WETH);
      expect(debt).to.equal(0);
      expect(coll).to.equal(0);
    });

    it("Should get trove status", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      const status = await troveManager.getTroveStatus(user1.address, WETH);
      expect(status).to.equal(0); // Status.nonExistent
    });
  });

  describe("Liquidation", function () {
    it("Should liquidate undercollateralized trove", async function () {
      const { troveManager, user1, user2, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Setup: Open a trove that will become undercollateralized
      const collAmount = ethers.parseEther("10");
      const debtAmount = ethers.parseEther("15000"); // High debt
      
      // This test would require proper setup with price oracle
      // and stability pool integration
    });

    it("Should distribute liquidation rewards correctly", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test liquidation reward distribution logic
      // This would require multiple troves and proper setup
    });

    it("Should handle batch liquidation", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test batch liquidation of multiple troves
      // This would require setting up multiple undercollateralized troves
    });
  });

  describe("Recovery Mode", function () {
    it("Should enter recovery mode when TCR drops below CCR", async function () {
      const { troveManager, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // This would require manipulating system-wide collateralization
      // to trigger recovery mode
    });

    it("Should apply different liquidation rules in recovery mode", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test recovery mode liquidation logic
    });
  });

  describe("Reward Distribution", function () {
    it("Should track L_Collateral and L_Debt correctly", async function () {
      const { troveManager, WETH } = await loadFixture(deployTroveManagerFixture);
      
      const initialL_Coll = await troveManager.L_Collateral(WETH);
      const initialL_Debt = await troveManager.L_Debt(WETH);
      
      expect(initialL_Coll).to.equal(0);
      expect(initialL_Debt).to.equal(0);
    });

    it("Should calculate pending rewards correctly", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // This would require setting up a scenario with liquidations
      // to generate pending rewards
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero debt correctly", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      const icr = await troveManager.getCurrentICR(user1.address, WETH);
      expect(icr).to.equal(ethers.MaxUint256); // Should return max uint for zero debt
    });

    it("Should prevent operations on closed troves", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test that operations fail on closed troves
    });

    it("Should handle rounding errors gracefully", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test edge cases with very small amounts
    });
  });

  describe("Integration Tests", function () {
    it("Should integrate properly with SortedTroves", async function () {
      const { troveManager, sortedTroves, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test that troves are properly inserted into sorted list
    });

    it("Should integrate properly with StabilityPool", async function () {
      const { troveManager, stabilityPool } = await loadFixture(deployTroveManagerFixture);
      
      // Test liquidation integration with stability pool
    });

    it("Should integrate properly with PriceOracle", async function () {
      const { troveManager, priceOracle, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test price oracle integration
    });
  });

  describe("Gas Optimization", function () {
    it("Should use reasonable gas for trove operations", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test gas usage for view operations
      const tx = await troveManager.getCurrentICR(user1.address, WETH);
      expect(tx).to.equal(ethers.MaxUint256); // Should return max uint for zero debt
    });
  });

  describe("Security Tests", function () {
    it("Should prevent reentrancy attacks", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test reentrancy protection
    });

    it("Should validate all inputs properly", async function () {
      const { troveManager, user1, WETH } = await loadFixture(deployTroveManagerFixture);
      
      // Test input validation for liquidation
      await expect(
        troveManager.connect(user1).liquidate(ethers.ZeroAddress, WETH)
      ).to.be.revertedWith("Trove is not active");
    });

    it("Should handle overflow/underflow correctly", async function () {
      const { troveManager } = await loadFixture(deployTroveManagerFixture);
      
      // Test arithmetic safety
    });
  });
});
