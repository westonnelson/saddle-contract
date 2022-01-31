/* eslint-disable prettier/prettier */
/*eslint max-len: ["error", { "code": 150 }]*/

import { BigNumber, ContractFactory, Signer } from "ethers"
import { ethers } from "hardhat"
import { solidity } from "ethereum-waffle"

import chai from "chai"
import { deployments } from "hardhat"
import { BIG_NUMBER_1E18, MAX_UINT256, ZERO_ADDRESS } from "../testUtils"
import {
  PoolRegistry,
  PoolDataStruct,
  PoolInputDataStruct,
} from "../../build/typechain/PoolRegistry"
import { Swap, SwapGuarded } from "../../build/typechain"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

enum PoolType {
  BTC,
  ETH,
  USD,
  OTHERS,
}

describe("Registry", async () => {
  let signers: Array<Signer>
  let owner: Signer
  let ownerAddress: string
  let poolRegistry: PoolRegistry
  let registryFactory: ContractFactory
  let usdv2Data: PoolDataStruct
  let susdMetaV2Data: PoolDataStruct
  let guardedBtcData: PoolDataStruct
  let usdv2InputData: PoolInputDataStruct
  let susdMetaV2InputData: PoolInputDataStruct
  let guardedBtcInputData: PoolInputDataStruct

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture() // ensure you start from a fresh deployments

      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      registryFactory = await ethers.getContractFactory("PoolRegistry")
      poolRegistry = (await registryFactory.deploy(
        ownerAddress,
        ownerAddress,
      )) as PoolRegistry

      usdv2InputData = {
        poolAddress: (await get("SaddleUSDPoolV2")).address,
        typeOfAsset: PoolType.USD,
        poolName: ethers.utils.formatBytes32String("USDv2"),
        targetAddress: (await get("SaddleUSDPoolV2")).address,
        metaSwapDepositAddress: ZERO_ADDRESS,
        pid: BigNumber.from(0),
        isSaddleApproved: true,
        isRemoved: false,
      }

      usdv2Data = {
        poolAddress: (await get("SaddleUSDPoolV2")).address,
        lpToken: (await get("SaddleUSDPoolV2LPToken")).address,
        typeOfAsset: PoolType.USD,
        poolName: ethers.utils.formatBytes32String("USDv2"),
        targetAddress: (await get("SaddleUSDPoolV2")).address,
        tokens: [
          (await get("DAI")).address,
          (await get("USDC")).address,
          (await get("USDT")).address,
        ],
        underlyingTokens: [],
        basePoolAddress: ZERO_ADDRESS,
        metaSwapDepositAddress: ZERO_ADDRESS,
        pid: BigNumber.from(0),
        isSaddleApproved: true,
        isRemoved: false,
      }

      susdMetaV2InputData = {
        poolAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        typeOfAsset: PoolType.USD,
        poolName: ethers.utils.formatBytes32String("sUSD meta v2"),
        targetAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        metaSwapDepositAddress: (await get("SaddleSUSDMetaPoolUpdatedDeposit"))
          .address,
        pid: BigNumber.from(1),
        isSaddleApproved: true,
        isRemoved: false,
      }

      susdMetaV2Data = {
        poolAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        lpToken: (await get("SaddleSUSDMetaPoolUpdatedLPToken")).address,
        typeOfAsset: PoolType.USD,
        poolName: ethers.utils.formatBytes32String("sUSD meta v2"),
        targetAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        tokens: [
          (await get("SUSD")).address,
          (await get("SaddleUSDPoolV2LPToken")).address,
        ],
        underlyingTokens: [
          (await get("SUSD")).address,
          (await get("DAI")).address,
          (await get("USDC")).address,
          (await get("USDT")).address,
        ],
        basePoolAddress: (await get("SaddleUSDPoolV2")).address,
        metaSwapDepositAddress: (await get("SaddleSUSDMetaPoolUpdatedDeposit"))
          .address,
        pid: BigNumber.from(1),
        isSaddleApproved: true,
        isRemoved: false,
      }

      guardedBtcInputData = {
        poolAddress: (await get("SaddleBTCPool")).address,
        typeOfAsset: PoolType.BTC,
        poolName: ethers.utils.formatBytes32String("BTC guarded pool"),
        targetAddress: (await get("SaddleBTCPool")).address,
        metaSwapDepositAddress: ZERO_ADDRESS,
        pid: BigNumber.from(0),
        isSaddleApproved: true,
        isRemoved: false,
      }

      guardedBtcData = {
        poolAddress: (await get("SaddleBTCPool")).address,
        lpToken: (await get("SaddleBTCPoolLPToken")).address,
        typeOfAsset: PoolType.BTC,
        poolName: ethers.utils.formatBytes32String("BTC guarded pool"),
        targetAddress: (await get("SaddleBTCPool")).address,
        tokens: [
          (await get("TBTC")).address,
          (await get("WBTC")).address,
          (await get("RENBTC")).address,
          (await get("SBTC")).address,
        ],
        underlyingTokens: [],
        basePoolAddress: ZERO_ADDRESS,
        metaSwapDepositAddress: ZERO_ADDRESS,
        pid: BigNumber.from(0),
        isSaddleApproved: true,
        isRemoved: false,
      }

      for (const token of usdv2Data.tokens) {
        const tokenContract = await ethers.getContractAt("GenericERC20", token)
        await tokenContract.approve(usdv2Data.poolAddress, MAX_UINT256)
      }
      const usdPoolContract = (await ethers.getContract(
        "SaddleUSDPoolV2",
      )) as Swap
      await usdPoolContract.addLiquidity(
        [String(1e18), String(1e6), String(1e6)],
        0,
        MAX_UINT256,
      )
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("addPool", () => {
    it("Successfully adds USDv2 pool", async () => {
      await poolRegistry.addPool(usdv2InputData)
    })
    it("Reverts adding USDv2 pool with incorrect pool address", async () => {
      const incorrectData = {
        ...usdv2InputData,
        poolAddress: ZERO_ADDRESS,
      }
      await expect(poolRegistry.addPool(incorrectData)).to.be.revertedWith(
        "PR: poolAddress is 0",
      )
    })
    it("Reverts when adding a meta pool without adding the base pool", async () => {
      await expect(
        poolRegistry.addPool(susdMetaV2InputData),
      ).to.be.revertedWith("base pool not found")
    })
  })

  describe("getPoolData & getPoolDataAtIndex", () => {
    it("Successfully reads getPoolData", async () => {
      await poolRegistry.addPool(usdv2Data)
      await poolRegistry.addPool(susdMetaV2Data)
      let fetchedByAddress = await poolRegistry.getPoolData(
        (
          await get("SaddleUSDPoolV2")
        ).address,
      )
      let fetchedByIndex = await poolRegistry.getPoolDataAtIndex(0)
      expect(fetchedByAddress).to.eql(Object.values(usdv2Data))
      expect(fetchedByIndex).to.eql(Object.values(usdv2Data))

      fetchedByAddress = await poolRegistry.callStatic.getPoolData(
        (
          await get("SaddleSUSDMetaPoolUpdated")
        ).address,
      )
      fetchedByIndex = await poolRegistry.callStatic.getPoolDataAtIndex(1)
      expect(fetchedByAddress).to.eql(Object.values(susdMetaV2Data))
      expect(fetchedByIndex).to.eql(Object.values(susdMetaV2Data))
    })

    it("Successfully reads getPoolData of guarded pools", async () => {
      await poolRegistry.addPool(guardedBtcInputData)
      const fetchedByAddress = await poolRegistry.getPoolData(
        (
          await get("SaddleBTCPool")
        ).address,
      )
      const fetchedByIndex = await poolRegistry.getPoolDataAtIndex(0)
      expect(fetchedByAddress).to.eql(Object.values(guardedBtcData))
      expect(fetchedByIndex).to.eql(Object.values(guardedBtcData))
    })

    it("Reverts when out of range", async () => {
      await expect(poolRegistry.getPoolDataAtIndex(0)).to.be.revertedWith(
        "PR: Index out of bounds",
      )
    })

    it("Reverts when address not found", async () => {
      await expect(poolRegistry.getPoolData(ZERO_ADDRESS)).to.be.revertedWith(
        "PR: No matching pool found",
      )
    })
  })

  describe("getVirtualPrice", () => {
    it("Successfully fetches virtual price for given pool address", async () => {
      await poolRegistry.addPool(usdv2Data)
      expect(
        await poolRegistry.callStatic.getVirtualPrice(usdv2Data.poolAddress),
      ).to.eq(BIG_NUMBER_1E18)
    })
  })

  describe("getA", () => {
    it("Successfully fetches A for given pool address", async () => {
      await poolRegistry.addPool(usdv2Data)
      expect(await poolRegistry.callStatic.getA(usdv2Data.poolAddress)).to.eq(
        200,
      )
    })
  })

  describe("getTokens", () => {
    it("Successfully fetches tokens for given pool address", async () => {
      await poolRegistry.addPool(usdv2Data)
      expect(
        await poolRegistry.callStatic.getTokens(usdv2Data.poolAddress),
      ).to.eql(usdv2Data.tokens)
    })
  })

  describe("getBalances", () => {
    it("Successfully fetches balances for given pool address", async () => {
      await poolRegistry.addPool(usdv2Data)
      expect(
        await poolRegistry.callStatic.getBalances(usdv2Data.poolAddress),
      ).to.eql([
        usdv2Data.tokens,
        [BIG_NUMBER_1E18, BigNumber.from(1e6), BigNumber.from(1e6)],
      ])
    })
  })

  describe("getEligiblePools", () => {
    it("Successfully gets all eligible pools", async () => {
      await poolRegistry.addPool(usdv2Data)
      await poolRegistry.addPool(susdMetaV2Data)

      // tokens
      const dai = (await get("DAI")).address
      const usdc = (await get("USDC")).address
      const saddleUSDLPToken = (await get("SaddleUSDPoolV2LPToken")).address
      const susd = (await get("SUSD")).address

      // pools
      const usdv2Pool = (await get("SaddleUSDPoolV2")).address
      const susdPool = (await get("SaddleSUSDMetaPoolUpdated")).address
      const susdPoolDeposit = (await get("SaddleSUSDMetaPoolUpdatedDeposit"))
        .address

      expect(
        await poolRegistry.getEligiblePools(dai, usdc),
        "dai, usdc",
      ).to.eql([usdv2Pool])
      expect(
        await poolRegistry.getEligiblePools(dai, saddleUSDLPToken),
        "dai, lptoken",
      ).to.eql([])
      expect(
        await poolRegistry.getEligiblePools(susd, usdc),
        "susd, usdc",
      ).to.eql([susdPoolDeposit])
      expect(
        await poolRegistry.getEligiblePools(saddleUSDLPToken, susd),
        "lptoken, susd",
      ).to.eql([susdPool])
      expect(
        await poolRegistry.getEligiblePools(dai, susd),
        "dai, susd",
      ).to.eql([susdPoolDeposit])
    })
  })

  describe("getSwapStorage", () => {
    it("Successfully fetches swapStorage from a regular Swap", async () => {
      await poolRegistry.addPool(usdv2Data)
      const swap = (await ethers.getContractAt(
        "Swap",
        usdv2Data.poolAddress,
      )) as Swap
      expect(await poolRegistry.getSwapStorage(usdv2Data.poolAddress)).to.eql(
        await swap.swapStorage(),
      )
    })

    it("Successfully fetches swapStorage from a guarded Swap", async () => {
      await poolRegistry.addPool(guardedBtcInputData)
      const guardedSwap = (await ethers.getContractAt(
        "SwapGuarded",
        guardedBtcInputData.poolAddress,
      )) as SwapGuarded
      const swapStorage = [...(await guardedSwap.swapStorage())]
      swapStorage.splice(6, 1)
      expect(
        await poolRegistry.getSwapStorage(guardedBtcInputData.poolAddress),
      ).to.eql(swapStorage)
    })

    it("Reverts when querying an unregistered pool address", async () => {
      await expect(
        poolRegistry.getSwapStorage(guardedBtcInputData.poolAddress),
      ).to.be.revertedWith("PR: No matching pool found")
    })
  })
})
