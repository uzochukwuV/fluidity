import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { EnhancedStabilityPool, USDF, FluidToken } from "../typechain-types";

describe("EnhancedStabilityPool", function () {
  async function deployStabilityPoolFixture() {
    const [owner, user1, user2, user3] = await ethers.getSigners();

    // Deploy USDF token
    const USDF = await ethers.getContractFactory("USDF");
    const usdf = await USDF.deploy();

    // Deploy FluidToken
    const FluidToken = await ethers.getContractFactory("FluidToken");
    const fluidToken = await FluidToken.deploy();

    // Deploy EnhancedStabilityPool
    const EnhancedStabilityPool = await ethers.getContractFactory("EnhancedStabilityPool");
    const stabilityPool = await EnhancedStabilityPool.deploy();

    // Mock WETH address
    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    return {
      stabilityPool,
      usdf,
      fluidToken,
      owner,
      user1,
      user2,
      user3,
      WETH
    };
  }

  describe("Deployment", function () {
    it("Should deploy successfully", async function () {
      const { stabilityPool } = await loadFixture(deployStabilityPoolFixture);
      expect(await stabilityPool.getAddress()).to.be.properAddress;
    });

    it("Should have correct initial state", async function () {
      const { stabilityPool } = await loadFixture(deployStabilityPoolFixture);
      
      expect(await stabilityPool.currentEpoch()).to.equal(0);
      expect(await stabilityPool.currentScale()).to.equal(0);
      expect(await stabilityPool.P()).to.equal(ethers.parseEther("1"));
    });
  });

  describe("Deposits", function () {
    it("Should allow USDF deposits", async function () {
      const { stabilityPool, usdf, user1 } = await loadFixture(deployStabilityPoolFixture);
      
      const depositAmount = ethers.parseEther("1000");
      
      // Mint USDF to user1
      await usdf.mint(user1.address, depositAmount);
      await usdf.connect(user1).approve(await stabilityPool.getAddress(), depositAmount);
      
      await expect(
        stabilityPool.connect(user1).provideToSP(depositAmount, user1.address)
      ).to.emit(stabilityPool, "UserDepositChanged");
      
      expect(await stabilityPool.getCompoundedUSDF(user1.address)).to.equal(depositAmount);
    });

    it("Should track deposits correctly", async function () {
      const { stabilityPool, usdf, user1, user2 } = await loadFixture(deployStabilityPoolFixture);
      
      const deposit1 = ethers.parseEther("1000");
      const deposit2 = ethers.parseEther("2000");
      
      // Setup deposits
      await usdf.mint(user1.address, deposit1);
      await usdf.mint(user2.address, deposit2);
      await usdf.connect(user1).approve(await stabilityPool.getAddress(), deposit1);
      await usdf.connect(user2).approve(await stabilityPool.getAddress(), deposit2);
      
      await stabilityPool.connect(user1).provideToSP(deposit1, user1.address);
      await stabilityPool.connect(user2).provideToSP(deposit2, user2.address);
      
      expect(await stabilityPool.getTotalUSDF()).to.equal(deposit1 + deposit2);
    });
  });

  describe("Withdrawals", function () {
    it("Should allow partial withdrawals", async function () {
      const { stabilityPool, usdf, user1 } = await loadFixture(deployStabilityPoolFixture);
      
      const depositAmount = ethers.parseEther("1000");
      const withdrawAmount = ethers.parseEther("500");
      
      // Setup deposit
      await usdf.mint(user1.address, depositAmount);
      await usdf.connect(user1).approve(await stabilityPool.getAddress(), depositAmount);
      await stabilityPool.connect(user1).provideToSP(depositAmount);
      
      await expect(
        stabilityPool.connect(user1).withdrawFromSP(withdrawAmount)
      ).to.emit(stabilityPool, "UserDepositChanged");
      
      expect(await stabilityPool.getCompoundedUSDF(user1.address)).to.equal(depositAmount - withdrawAmount);
    });

    it("Should allow full withdrawals", async function () {
      const { stabilityPool, usdf, user1 } = await loadFixture(deployStabilityPoolFixture);
      
      const depositAmount = ethers.parseEther("1000");
      
      // Setup deposit
      await usdf.mint(user1.address, depositAmount);
      await usdf.connect(user1).approve(await stabilityPool.getAddress(), depositAmount);
      await stabilityPool.connect(user1).provideToSP(depositAmount);
      
      await stabilityPool.connect(user1).withdrawFromSP(depositAmount);
      
      expect(await stabilityPool.getCompoundedUSDF(user1.address)).to.equal(0);
    });
  });

  describe("Epoch and Scale Management", function () {
    it("Should handle epoch transitions correctly", async function () {
      const { stabilityPool } = await loadFixture(deployStabilityPoolFixture);
      
      // This would require triggering conditions that cause epoch transitions
      // Such as large liquidations that significantly reduce P
    });

    it("Should handle scale transitions correctly", async function () {
      const { stabilityPool } = await loadFixture(deployStabilityPoolFixture);
      
      // This would require triggering conditions that cause scale transitions
    });
  });

  describe("Reward Distribution", function () {
    it("Should calculate collateral gains correctly", async function () {
      const { stabilityPool, user1, WETH } = await loadFixture(deployStabilityPoolFixture);
      
      // This would require setting up liquidations to generate collateral gains
      const gain = await stabilityPool.getDepositorCollateralGain(user1.address, WETH);
      expect(gain).to.equal(0); // Initially zero
    });

    it("Should calculate FLUID rewards correctly", async function () {
      const { stabilityPool, user1 } = await loadFixture(deployStabilityPoolFixture);
      
      // This would require setting up FLUID token rewards
      const reward = await stabilityPool.getDepositorFLUIDGain(user1.address);
      expect(reward).to.equal(0); // Initially zero
    });
  });

  describe("Liquidation Offset", function () {
    it("Should handle liquidation offsets correctly", async function () {
      const { stabilityPool, WETH } = await loadFixture(deployStabilityPoolFixture);
      
      // This would require proper authorization and liquidation setup
      // await stabilityPool.offset(WETH, debtToOffset, collToAdd);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero deposits gracefully", async function () {
      const { stabilityPool, user1 } = await loadFixture(deployStabilityPoolFixture);
      
      expect(await stabilityPool.getCompoundedUSDF(user1.address)).to.equal(0);
    });

    it("Should prevent unauthorized operations", async function () {
      const { stabilityPool, user1, WETH } = await loadFixture(deployStabilityPoolFixture);
      
      await expect(
        stabilityPool.connect(user1).offset(WETH, 1000, 1000)
      ).to.be.revertedWith("Caller is not TroveManager");
    });
  });
});
