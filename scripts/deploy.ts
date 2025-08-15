import { ethers } from "hardhat";
import * as fs from "fs";

async function main() {
  console.log("Deploying Fluid Protocol to Core Blockchain...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());

  // Deploy tokens first
  console.log("\n=== Deploying Tokens ===");
  
  const USDF = await ethers.getContractFactory("USDF");
  const usdf = await USDF.deploy();
  await usdf.waitForDeployment();
  console.log("USDF deployed to:", await usdf.getAddress());

  const FluidToken = await ethers.getContractFactory("FluidToken");
  const fluidToken = await FluidToken.deploy();
  await fluidToken.waitForDeployment();
  console.log("FluidToken deployed to:", await fluidToken.getAddress());

  // Deploy core contracts
  console.log("\n=== Deploying Core Contracts ===");

  // Deploy PriceOracle
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy();
  await priceOracle.waitForDeployment();
  console.log("PriceOracle deployed to:", await priceOracle.getAddress());

  // Deploy SortedTroves
  const SortedTroves = await ethers.getContractFactory("SortedTroves");
  const sortedTroves = await SortedTroves.deploy();
  await sortedTroves.waitForDeployment();
  console.log("SortedTroves deployed to:", await sortedTroves.getAddress());

  // Deploy TroveManager
  const TroveManager = await ethers.getContractFactory("TroveManager");
  const troveManager = await TroveManager.deploy();
  await troveManager.waitForDeployment();
  console.log("TroveManager deployed to:", await troveManager.getAddress());

  // Deploy EnhancedStabilityPool
  const EnhancedStabilityPool = await ethers.getContractFactory("EnhancedStabilityPool");
  const stabilityPool = await EnhancedStabilityPool.deploy();
  await stabilityPool.waitForDeployment();
  console.log("EnhancedStabilityPool deployed to:", await stabilityPool.getAddress());

  // Deploy BorrowerOperations
  const BorrowerOperations = await ethers.getContractFactory("BorrowerOperations");
  const borrowerOperations = await BorrowerOperations.deploy();
  await borrowerOperations.waitForDeployment();
  console.log("BorrowerOperations deployed to:", await borrowerOperations.getAddress());

  // Deploy RiskEngine
  const RiskEngine = await ethers.getContractFactory("RiskEngine");
  const riskEngine = await RiskEngine.deploy();
  await riskEngine.waitForDeployment();
  console.log("RiskEngine deployed to:", await riskEngine.getAddress());

  console.log("\n=== Initializing Contracts ===");

  // Set up price feeds (example with ETH)
  const ETH_USD_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // Mainnet Chainlink ETH/USD
  const WETH_ADDRESS = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Mainnet WETH
  
  try {
    await priceOracle.addAsset(
      WETH_ADDRESS,
      ETH_USD_FEED,
      3600, // 1 hour timeout
      ethers.parseEther("0.05") // 5% deviation threshold
    );
    console.log("ETH price feed configured");
  } catch (error) {
    console.log("Price feed setup skipped (likely testnet)");
  }

  console.log("\n=== Deployment Summary ===");
  console.log("USDF:", await usdf.getAddress());
  console.log("FluidToken:", await fluidToken.getAddress());
  console.log("PriceOracle:", await priceOracle.getAddress());
  console.log("SortedTroves:", await sortedTroves.getAddress());
  console.log("TroveManager:", await troveManager.getAddress());
  console.log("StabilityPool:", await stabilityPool.getAddress());
  console.log("BorrowerOperations:", await borrowerOperations.getAddress());
  console.log("RiskEngine:", await riskEngine.getAddress());

  // Save deployment addresses
  const deploymentInfo = {
    network: await deployer.provider.getNetwork(),
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      USDF: await usdf.getAddress(),
      FluidToken: await fluidToken.getAddress(),
      PriceOracle: await priceOracle.getAddress(),
      SortedTroves: await sortedTroves.getAddress(),
      TroveManager: await troveManager.getAddress(),
      StabilityPool: await stabilityPool.getAddress(),
      BorrowerOperations: await borrowerOperations.getAddress(),
      RiskEngine: await riskEngine.getAddress()
    }
  };

  fs.writeFileSync(
    './deployments.json',
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("\nDeployment info saved to deployments.json");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
  console.log("Updating RiskEngine with LiquidityPool address...");

  // Deploy DEX components
  console.log("\n=== Deploying DEX Components ===");

  const FluidAMM = await ethers.getContractFactory("FluidAMM");
  const fluidAMM = await FluidAMM.deploy(await liquidityPool.getAddress());
  await fluidAMM.waitForDeployment();
  console.log("FluidAMM deployed to:", await fluidAMM.getAddress());

  // Deploy Vault system
  console.log("\n=== Deploying Vault System ===");

  const VaultManager = await ethers.getContractFactory("VaultManager");
  const vaultManager = await VaultManager.deploy(
    await liquidityPool.getAddress(),
    deployer.address // Fee recipient
  );
  await vaultManager.waitForDeployment();
  console.log("VaultManager deployed to:", await vaultManager.getAddress());

  // Setup initial configuration
  console.log("\n=== Initial Configuration ===");

  // Grant minter role to liquidityPool for USDF
  await usdf.addMinter(await liquidityPool.getAddress());
  console.log("Granted USDF minter role to LiquidityPool");

  // Add some initial assets to the liquidity pool (example with mock tokens)
  // In production, you'd add real tokens like WCORE, USDT, etc.
  
  // Setup initial risk parameters for USDF
  const initialRiskParams = {
    baseLTV: ethers.parseEther("0.8"),           // 80% LTV
    liquidationLTV: ethers.parseEther("0.85"),   // 85% liquidation threshold
    liquidationBonus: ethers.parseEther("0.05"), // 5% liquidation bonus
    volatilityFactor: ethers.parseEther("0.1"),  // Low volatility for stablecoin
    correlationFactor: ethers.parseEther("0.1"), // Low correlation
    liquidityFactor: ethers.parseEther("1.0")    // High liquidity
  };

  await riskEngine.setRiskParameters(await usdf.getAddress(), initialRiskParams);
  console.log("Set initial risk parameters for USDF");

  // Setup interest rate model for USDF
  await liquidityPool.setInterestRateModel(
    await usdf.getAddress(),
    ethers.parseEther("0.02"),  // 2% base rate
    ethers.parseEther("0.1"),   // 10% multiplier
    ethers.parseEther("2.0"),   // 200% jump multiplier
    ethers.parseEther("0.8")    // 80% kink
  );
  console.log("Set interest rate model for USDF");

  // Distribute FluidToken
  console.log("\n=== Token Distribution ===");
  
  // For demo purposes, we'll set up some addresses
  const teamAddress = deployer.address;
  const communityAddress = deployer.address;
  const liquidityMiningAddress = deployer.address;
  const treasuryAddress = deployer.address;

  await fluidToken.distributeTokens(
    teamAddress,
    communityAddress,
    liquidityMiningAddress,
    treasuryAddress
  );
  console.log("Distributed FluidToken to initial allocations");

  // Create initial AMM pool (USDF/FluidToken)
  console.log("\n=== Creating Initial AMM Pool ===");
  
  const poolFee = ethers.parseEther("0.003"); // 0.3% fee
  await fluidAMM.createPool(
    await usdf.getAddress(),
    await fluidToken.getAddress(),
    poolFee
  );
  console.log("Created USDF/FLUID AMM pool");

  // Summary
  console.log("\n=== Deployment Summary ===");
  console.log("USDF:", await usdf.getAddress());
  console.log("FluidToken:", await fluidToken.getAddress());
  console.log("RiskEngine:", await riskEngine.getAddress());
  console.log("UnifiedLiquidityPool:", await liquidityPool.getAddress());
  console.log("FluidAMM:", await fluidAMM.getAddress());
  console.log("VaultManager:", await vaultManager.getAddress());

  // Save deployment addresses
  const deploymentInfo = {
    network: "core",
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      USDF: await usdf.getAddress(),
      FluidToken: await fluidToken.getAddress(),
      RiskEngine: await riskEngine.getAddress(),
      UnifiedLiquidityPool: await liquidityPool.getAddress(),
      FluidAMM: await fluidAMM.getAddress(),
      VaultManager: await vaultManager.getAddress()
    }
  };

  console.log("\n=== Deployment Info ===");
  console.log(JSON.stringify(deploymentInfo, null, 2));

  console.log("\n✅ Deployment completed successfully!");
  console.log("\nNext steps:");
  console.log("1. Verify contracts on Core blockchain explorer");
  console.log("2. Set up price oracles for supported assets");
  console.log("3. Create additional AMM pools for major assets");
  console.log("4. Deploy yield strategies for vault system");
  console.log("5. Set up governance system");
  console.log("6. Configure protocol parameters");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });