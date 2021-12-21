import { BigNumber, ContractFactory, Signer } from "ethers"
import { solidity } from "ethereum-waffle"

import chai from "chai"
import { deployments } from "hardhat"
import { ZERO_ADDRESS } from "./testUtils"
import { MasterRegistry } from "../build/typechain/MasterRegistry"

chai.use(solidity)
const { expect } = chai
const { get } = deployments

describe("Master Registry", async () => {
  let signers: Array<Signer>
  let owner: Signer
  let ownerAddress: string
  let masterRegistry: MasterRegistry
  let masterRegistryFactory: ContractFactory

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture() // ensure you start from a fresh deployments

      signers = await ethers.getSigners()
      owner = signers[0]
      ownerAddress = await owner.getAddress()
      masterRegistryFactory = await ethers.getContractFactory("MasterRegistry")
      masterRegistry = (await masterRegistryFactory.deploy()) as MasterRegistry
    },
  )

  beforeEach(async () => {
    await setupTest()
  })

  describe("addRegistry", () => {
    it("Reverts when using empty string", async () => {
      await expect(
        masterRegistry.addRegistry("", ownerAddress),
      ).to.be.revertedWith("name cannot be empty")
    })
    it("Reverts when using empty address", async () => {
      await expect(
        masterRegistry.addRegistry("TEST", ZERO_ADDRESS),
      ).to.be.revertedWith("address cannot be empty")
    })
    it("Reverts when using duplicate address", async () => {
      await masterRegistry.addRegistry("TEST", ownerAddress)
      await expect(
        masterRegistry.addRegistry("TEST-2", ownerAddress),
      ).to.be.revertedWith("duplicate registry address")
    })

    it("Successfully adds a new registry with a new name", async () => {
      await masterRegistry.addRegistry("TEST", ownerAddress)
      expect(await masterRegistry.resolveNameToLatestAddress("TEST")).to.eq(
        ownerAddress,
      )
    })

    it("Successfully adds a new registry with a same name", async () => {
      await masterRegistry.addRegistry("TEST", await signers[0].getAddress())
      expect(await masterRegistry.resolveNameToLatestAddress("TEST")).to.eq(
        await signers[0].getAddress(),
      )
      await masterRegistry.addRegistry("TEST", await signers[1].getAddress())
      expect(await masterRegistry.resolveNameToLatestAddress("TEST")).to.eq(
        await signers[1].getAddress(),
      )
    })
  })

  describe("resolveNameToLatestAddress", () => {
    it("Reverts when no match is found", async () => {
      await expect(
        masterRegistry.resolveNameToLatestAddress("RANDOM_NAME"),
      ).to.be.revertedWith("no match found for name")
    })
    it("Successfully resolves name to latest address", async () => {
      await masterRegistry.addRegistry("TEST", await signers[0].getAddress())
      await masterRegistry.addRegistry("TEST", await signers[1].getAddress())
      expect(await masterRegistry.resolveNameToLatestAddress("TEST")).to.eq(
        await signers[1].getAddress(),
      )
    })
  })

  describe("resolveAddressToRegistryData", () => {
    it("Reverts when no match is found", async () => {
      await expect(
        masterRegistry.resolveAddressToRegistryData(ownerAddress),
      ).to.be.revertedWith("no match found for address")
    })
    it("Successfully resolves addresses to registry data", async () => {
      await masterRegistry.addRegistry("TEST", await signers[0].getAddress())
      await masterRegistry.addRegistry("TEST", await signers[1].getAddress())
      await masterRegistry.addRegistry("TEST2", await signers[2].getAddress())
      expect(
        await masterRegistry.resolveAddressToRegistryData(
          await signers[0].getAddress(),
        ),
      ).to.eql(["TEST", BigNumber.from(0), false])
      expect(
        await masterRegistry.resolveAddressToRegistryData(
          await signers[1].getAddress(),
        ),
      ).to.eql(["TEST", BigNumber.from(1), true])
      expect(
        await masterRegistry.resolveAddressToRegistryData(
          await signers[2].getAddress(),
        ),
      ).to.eql(["TEST2", BigNumber.from(0), true])
    })
  })
})
