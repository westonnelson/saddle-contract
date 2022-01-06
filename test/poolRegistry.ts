import { ContractFactory, Signer } from "ethers"
import { solidity } from "ethereum-waffle"

import chai from "chai"
import { deployments } from "hardhat"
import { ZERO_ADDRESS } from "./testUtils"
import { PoolRegistry, PoolDataStruct } from "../build/typechain/PoolRegistry"

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
  let poolData: PoolDataStruct

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
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("addPool", () => {
    it("Successfully adds USDv2 pool", async () => {
      await poolRegistry.addPool({
        poolAddress: (await get("SaddleUSDPoolV2")).address,
        poolName: "USDv2",
        lpToken: (await get("SaddleUSDPoolV2LPToken")).address,
        typeOfAsset: PoolType.USD,
        tokens: [
          (await get("DAI")).address,
          (await get("USDC")).address,
          (await get("USDT")).address,
        ],
        underlyingTokens: [
          (await get("DAI")).address,
          (await get("USDC")).address,
          (await get("USDT")).address,
        ],
        basePoolAddress: ZERO_ADDRESS,
        metaPoolDepositAddress: ZERO_ADDRESS,
        isSaddlePool: true,
        isRemoved: false,
      })
    })
    it("Reverts adding USDv2 pool with incorrect token list", async () => {
      await expect(
        poolRegistry.addPool({
          poolAddress: (await get("SaddleUSDPoolV2")).address,
          poolName: "USDv2",
          lpToken: (await get("SaddleUSDPoolV2LPToken")).address,
          typeOfAsset: PoolType.USD,
          tokens: [
            (await get("DAI")).address,
            (await get("USDC")).address,
            (await get("SUSD")).address,
          ],
          underlyingTokens: [
            (await get("DAI")).address,
            (await get("USDC")).address,
            (await get("SUSD")).address,
          ],
          basePoolAddress: ZERO_ADDRESS,
          metaPoolDepositAddress: ZERO_ADDRESS,
          isSaddlePool: true,
          isRemoved: false,
        }),
      ).to.be.revertedWith("token address mismatch")
    })
    it("Successfully adds SUSD meta pool v2", async () => {
      await poolRegistry.addPool({
        poolAddress: (await get("SaddleSUSDMetaPoolUpdated")).address,
        poolName: "sUSD meta v2",
        lpToken: (await get("SaddleSUSDMetaPoolUpdatedLPToken")).address,
        typeOfAsset: PoolType.USD,
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
        metaPoolDepositAddress: (
          await get("SaddleSUSDMetaPoolUpdatedDeposit")
        ).address,
        isSaddlePool: true,
        isRemoved: false,
      })
    })
  })
})
