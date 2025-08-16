import { ethers } from "hardhat";
import fs from "fs";

async function main() {
  console.log("🚀 Starting Fluid Protocol deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Deploy USDF token
  console.log("\n📄 Deploying USDF token...");
  const USDF = await ethers.getContractFactory("USDF");
  const usdf = await USDF.deploy();
  await usdf.waitForDeployment();
  console.log("✅ USDF deployed to:", await usdf.getAddress());

  // Deploy FluidToken
  console.log("\n🌊 Deploying FluidToken...");
  const FluidToken = await ethers.getContractFactory("FluidToken");
  const fluidToken = await FluidToken.deploy();
  await fluidToken.waitForDeployment();
  console.log("✅ FluidToken deployed to:", await fluidToken.getAddress());

  // Deploy PriceOracle
  console.log("\n📊 Deploying PriceOracle...");
  const PriceOracle = await ethers.getContractFactory("PriceOracle");
  const priceOracle = await PriceOracle.deploy();
  await priceOracle.waitForDeployment();
  console.log("✅ PriceOracle deployed to:", await priceOracle.getAddress());

  // Deploy SortedTroves
  console.log("\n📋 Deploying SortedTroves...");
  const SortedTroves = await ethers.getContractFactory("SortedTroves");
  const sortedTroves = await SortedTroves.deploy();
  await sortedTroves.waitForDeployment();
  console.log("✅ SortedTroves deployed to:", await sortedTroves.getAddress());

  // Deploy LiquidationHelpers library
  console.log("\n🔧 Deploying LiquidationHelpers library...");
  const LiquidationHelpers = await ethers.getContractFactory("LiquidationHelpers");
  const liquidationHelpers = await LiquidationHelpers.deploy();
  await liquidationHelpers.waitForDeployment();
  console.log("✅ LiquidationHelpers deployed to:", await liquidationHelpers.getAddress());

  // Deploy TroveManager with library linking
  console.log("\n🏛️ Deploying TroveManager...");
  const TroveManager = await ethers.getContractFactory("TroveManager", {
    libraries: {
      LiquidationHelpers: await liquidationHelpers.getAddress(),
    },
  });
  const troveManager = await TroveManager.deploy();
  await troveManager.waitForDeployment();
  console.log("✅ TroveManager deployed to:", await troveManager.getAddress());

  // Deploy EnhancedStabilityPool
  console.log("\n🏦 Deploying EnhancedStabilityPool...");
  const EnhancedStabilityPool = await ethers.getContractFactory("EnhancedStabilityPool");
  const stabilityPool = await EnhancedStabilityPool.deploy();
  await stabilityPool.waitForDeployment();
  console.log("✅ EnhancedStabilityPool deployed to:", await stabilityPool.getAddress());

  // Deploy BorrowerOperations
  console.log("\n💰 Deploying BorrowerOperations...");
  const BorrowerOperations = await ethers.getContractFactory("BorrowerOperations");
  const borrowerOperations = await BorrowerOperations.deploy();
  await borrowerOperations.waitForDeployment();
  console.log("✅ BorrowerOperations deployed to:", await borrowerOperations.getAddress());

  // Deploy AdvancedRiskEngine
  console.log("\n⚖️ Deploying AdvancedRiskEngine...");
  const AdvancedRiskEngine = await ethers.getContractFactory("AdvancedRiskEngine");
  const riskEngine = await AdvancedRiskEngine.deploy();
  await riskEngine.waitForDeployment();
  console.log("✅ AdvancedRiskEngine deployed to:", await riskEngine.getAddress());

  // Deploy EnhancedFeeManager
  console.log("\n💸 Deploying EnhancedFeeManager...");
  const EnhancedFeeManager = await ethers.getContractFactory("EnhancedFeeManager");
  const feeManager = await EnhancedFeeManager.deploy();
  await feeManager.waitForDeployment();
  console.log("✅ EnhancedFeeManager deployed to:", await feeManager.getAddress());

  // Initialize contracts
  console.log("\n🔧 Initializing contracts...");

  // Initialize TroveManager
  await troveManager.initialize(
    await usdf.getAddress(),
    await stabilityPool.getAddress(),
    await priceOracle.getAddress(),
    await sortedTroves.getAddress(),
    await borrowerOperations.getAddress(),
    ethers.ZeroAddress, // activePool - placeholder
    ethers.ZeroAddress, // defaultPool - placeholder
    ethers.ZeroAddress, // collSurplusPool - placeholder
    ethers.ZeroAddress  // gasPool - placeholder
  );
  console.log("✅ TroveManager initialized");

  // Initialize StabilityPool
  await stabilityPool.initialize(
    await usdf.getAddress(),
    await troveManager.getAddress(),
    await fluidToken.getAddress(),
    ethers.ZeroAddress // communityIssuance - placeholder
  );
  console.log("✅ StabilityPool initialized");

  // Initialize BorrowerOperations
  await borrowerOperations.initialize(
    await troveManager.getAddress(),
    await stabilityPool.getAddress(),
    await priceOracle.getAddress(),
    await sortedTroves.getAddress(),
    await usdf.getAddress(),
    ethers.ZeroAddress, // activePool - placeholder
    ethers.ZeroAddress, // defaultPool - placeholder
    ethers.ZeroAddress, // collSurplusPool - placeholder
    ethers.ZeroAddress  // gasPool - placeholder
  );
  console.log("✅ BorrowerOperations initialized");

  // Setup price feeds
  console.log("\n📈 Setting up price feeds...");
  
  // Example: Add ETH price feed (Chainlink ETH/USD on mainnet)
  const ETH_USD_FEED = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"; // Mainnet
  const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // Mainnet WETH
  
  try {
    await priceOracle.addPriceFeed(WETH, ETH_USD_FEED);
    console.log("✅ ETH price feed configured");
  } catch (error) {
    console.log("⚠️ Price feed setup skipped (likely testnet)");
  }

  // Save deployment info
  const deploymentInfo = {
    network: await ethers.provider.getNetwork(),
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      USDF: await usdf.getAddress(),
      FluidToken: await fluidToken.getAddress(),
      PriceOracle: await priceOracle.getAddress(),
      SortedTroves: await sortedTroves.getAddress(),
      LiquidationHelpers: await liquidationHelpers.getAddress(),
      TroveManager: await troveManager.getAddress(),
      EnhancedStabilityPool: await stabilityPool.getAddress(),
      BorrowerOperations: await borrowerOperations.getAddress(),
      AdvancedRiskEngine: await riskEngine.getAddress(),
      EnhancedFeeManager: await feeManager.getAddress()
    }
  };

  fs.writeFileSync(
    "deployment-info.json",
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\n🎉 Deployment completed successfully!");
  console.log("📄 Deployment info saved to deployment-info.json");
  
  console.log("\n📋 Contract Addresses:");
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