/* eslint-disable prettier/prettier */
/*eslint max-len: ["error", { "code": 150 }]*/

import { ContractFactory, Signer } from "ethers"
import { solidity } from "ethereum-waffle"

import chai from "chai"
import { deployments } from "hardhat"
import { ZERO_ADDRESS } from "./testUtils"
import {
  PoolRegistry,
  PoolDataStruct,
  PoolInputDataStruct,
} from "../build/typechain/PoolRegistry"

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
  let usdv2InputData: PoolInputDataStruct
  let susdMetaV2InputData: PoolInputDataStruct

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture() // ensure you start from a fresh deployments

      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      registryFactory = await ethers.getContractFactory("PoolRegistry")
      poolRegistry = (await registryFactory.deploy(
        ownerAddress,
      )) as PoolRegistry

      usdv2InputData = {
        poolAddress: (await get("SaddleUSDPoolV2")).address,
        typeOfAsset: PoolType.USD,
        poolName: "USDv2",
        metaSwapDepositAddress: ZERO_ADDRESS,
        isSaddleApproved: true,
        isRemoved: false,
      }

      usdv2Data = {
        poolAddress: (await get("SaddleUSDPoolV2")).address,
        lpToken: (await get("SaddleUSDPoolV2LPToken")).address,
        typeOfAsset: PoolType.USD,
        poolName: "USDv2",
        tokens: [
          (await get("DAI")).address,
          (await get("USDC")).address,
          (await get("USDT")).address,
        ],
        underlyingTokens: [],
        basePoolAddress: ZERO_ADDRESS,
        metaSwapDepositAddress: ZERO_ADDRESS,
        isSaddleApproved: true,
        isRemoved: false,
      }

      susdMetaV2InputData = {
        poolAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        typeOfAsset: PoolType.USD,
        poolName: "sUSD meta v2",
        metaSwapDepositAddress: (await get("SaddleSUSDMetaPoolUpdatedDeposit"))
          .address,
        isSaddleApproved: true,
        isRemoved: false,
      }

      susdMetaV2Data = {
        poolAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        lpToken: (await get("SaddleSUSDMetaPoolUpdatedLPToken")).address,
        typeOfAsset: PoolType.USD,
        poolName: "sUSD meta v2",
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
        isSaddleApproved: true,
        isRemoved: false,
      }
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
        "poolAddress == 0",
      )
    })
    it("Reverts when adding a meta pool without adding the base pool", async () => {
      await expect(
        poolRegistry.addPool(susdMetaV2InputData),
      ).to.be.revertedWith("base pool not found")
    })
  })

  describe("saddlePoolData", () => {
    it("Successfully reads saddlePoolData", async () => {
      await poolRegistry.addPool(usdv2Data)
      await poolRegistry.addPool(susdMetaV2Data)
      const poolDataArray: PoolDataStruct[] = await poolRegistry.poolData()
      expect(poolDataArray).to.eql(
        [usdv2Data, susdMetaV2Data].map((x) => Object.values(x)),
      )
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
})
