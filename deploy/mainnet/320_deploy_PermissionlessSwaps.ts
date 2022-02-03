import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"
import { MULTISIG_ADDRESSES } from "../../utils/accounts"

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, getChainId, ethers } = hre
  const { deploy, get, getOrNull, execute } = deployments
  const { deployer } = await getNamedAccounts()

  const permissionlessSwap = await getOrNull("PermissionlessSwapFlashLoan")
  const permissionlessMetaSwap = await getOrNull(
    "PermissionlessMetaSwapFlashLoan",
  )
  const permissionlessDeployer = await getOrNull("PermissionlessDeployer")
  const masterRegistryAddress = (await get("MasterRegistry")).address

  if (permissionlessSwap == null) {
    await deploy("PermissionlessSwapFlashLoan", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [masterRegistryAddress],
      libraries: {
        SwapUtils: (await get("SwapUtils")).address,
        AmplificationUtils: (await get("AmplificationUtils")).address,
      },
    })
  }

  if (permissionlessMetaSwap == null) {
    await deploy("PermissionlessMetaSwapFlashLoan", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [masterRegistryAddress],
      libraries: {
        SwapUtils: (await get("SwapUtils")).address,
        MetaSwapUtils: (await get("MetaSwapUtils")).address,
        AmplificationUtils: (await get("AmplificationUtils")).address,
      },
    })
  }

  if (permissionlessDeployer == null) {
    await deploy("PermissionlessDeployer", {
      from: deployer,
      log: true,
      skipIfAlreadyDeployed: true,
      args: [
        MULTISIG_ADDRESSES[await getChainId()],
        (await get("MasterRegistry")).address,
        (await get("LPToken")).address,
        (await get("PermissionlessSwapFlashLoan")).address,
        (await get("PermissionlessMetaSwapFlashLoan")).address,
        (await get("SaddleSUSDMetaPoolDeposit")).address,
      ],
    })

    await execute(
      "MasterRegistry",
      {
        from: deployer,
        log: true,
      },
      "addRegistry",
      ethers.utils.formatBytes32String("PermissionlessDeployer"),
      (
        await get("PermissionlessDeployer")
      ).address,
    )

    // TODO: Grant COMMUNITY_MANAGER_ROLE to PoolRegistry with the MultiSig
  }
}
export default func
func.tags = ["PermissionlessSwaps"]
