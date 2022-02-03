/* eslint-disable prettier/prettier */
/*eslint max-len: ["error", { "code": 150 }]*/

import { BigNumber, ContractFactory, Signer } from "ethers"
import { solidity } from "ethereum-waffle"

import chai from "chai"
import { deployments } from "hardhat"
import {
  PoolRegistry,
  PoolDataStruct,
  PoolInputDataStruct,
} from "../../build/typechain/PoolRegistry"
import { PermissionlessDeployer } from "../../build/typechain"
import {
  DeployMetaSwapInputStruct,
  DeploySwapInputStruct,
} from "../../build/typechain/PermissionlessDeployer"
import { PoolType } from "../../utils/constants"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

describe("PermissionlessDeployer", async () => {
  let signers: Array<Signer>
  let deployer: Signer
  let deployerAddress: string
  let poolRegistry: PoolRegistry
  let registryFactory: ContractFactory
  let permissionlessDeployer: PermissionlessDeployer
  let deploySwapInput: DeploySwapInputStruct
  let deployMetaSwapInput: DeployMetaSwapInputStruct
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
      deployer = signers[0]
      deployerAddress = await deployer.getAddress()
      permissionlessDeployer = (await ethers.getContract(
        "PermissionlessDeployer",
      )) as PermissionlessDeployer
      poolRegistry = (await ethers.getContract("PoolRegistry")) as PoolRegistry
      poolRegistry.grantRole(
        await poolRegistry.COMMUNITY_MANAGER_ROLE(),
        permissionlessDeployer.address,
      )

      deploySwapInput = {
        poolName: ethers.utils.formatBytes32String("FraxUSD"),
        tokens: [
          (await get("USDC")).address,
          (await get("DAI")).address,
          (await get("FRAX")).address,
        ],
        decimals: [6, 18, 18],
        lpTokenName: "FraxUSD LP Token",
        lpTokenSymbol: "FraxUSD",
        a: BigNumber.from(1000),
        fee: BigNumber.from(0.04e8), // 4bps
        adminFee: BigNumber.from(50e8), // 50%
        owner: deployerAddress,
        typeOfAsset: PoolType.USD,
      }

      await permissionlessDeployer.deploySwap(deploySwapInput)

      const poolData: PoolDataStruct = await poolRegistry.getPoolDataByName(
        ethers.utils.formatBytes32String("FraxUSD"),
      )

      deployMetaSwapInput = {
        poolName: ethers.utils.formatBytes32String("sUSD-FraxUSD"),
        tokens: [(await get("SUSD")).address, poolData.lpToken],
        decimals: [18, 18],
        lpTokenName: "sUSD-FraxUSD LP Token",
        lpTokenSymbol: "sUSD-FraxUSD",
        a: BigNumber.from(1000),
        fee: BigNumber.from(0.04e8), // 4bps
        adminFee: BigNumber.from(50e8), // 50%
        owner: deployerAddress,
        typeOfAsset: PoolType.USD,
        baseSwap: poolData.poolAddress,
      }

      await permissionlessDeployer.deployMetaSwap(deployMetaSwapInput)
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("poolRegistryCached", () => {
    it("Successfully reads poolRegistryCached ", async () => {
      expect(await permissionlessDeployer.poolRegistryCached()).to.eq(
        (await get("PoolRegistry")).address,
      )
    })
  })
})
