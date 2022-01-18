// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

interface IPoolRegistry {
    /* Structs */

    struct PoolInputData {
        address poolAddress;
        uint8 typeOfAsset;
        bytes32 poolName;
        address targetAddress;
        address metaSwapDepositAddress;
        uint80 pid;
        bool isSaddleApproved;
        bool isRemoved;
    }

    struct PoolData {
        address poolAddress;
        address lpToken;
        uint8 typeOfAsset;
        bytes32 poolName;
        address targetAddress;
        address[] tokens;
        address[] underlyingTokens;
        address basePoolAddress;
        address metaSwapDepositAddress;
        uint80 pid;
        bool isSaddleApproved;
        bool isRemoved;
    }

    /* Public Variables */

    function poolsIndexOfPlusOne(address poolAddress)
        external
        returns (uint256);

    function poolsIndexOfNamePlusOne(bytes32 poolName)
        external
        returns (uint256);

    /* Functions */

    /**
     * @notice Add a new pool to the registry
     * @param inputData PoolInputData struct for the new pool
     */
    function addPool(PoolInputData memory inputData) external;

    /**
     * @notice Approve community deployed pools to be upgraded as Saddle owned
     * @dev since array entries are difficult to remove, we modify the entry to mark it
     * as a Saddle owned pool.
     * @param poolAddress address of the community pool
     */
    function approvePool(address poolAddress) external;

    /**
     * @notice Overwrite existing entry with new PoolData
     * @param poolData new PoolData struct to store
     */
    function updatePool(PoolData memory poolData) external;

    /**
     * @notice Remove pool from the registry
     * @dev Since arrays are not easily reducable, the entry will be marked as removed.Q
     * @param poolAddress address of the pool to remove
     */
    function removePool(address poolAddress) external;

    /**
     * @notice Returns PoolData for given pool address
     * @param poolAddress address of the pool to read
     */
    function getPoolData(address poolAddress)
        external
        view
        returns (PoolData memory);

    /**
     * @notice Returns PoolData for given pool address
     * @param index index of the pool to read
     */
    function getPoolData(uint256 index) external view returns (PoolData memory);

    /**
     * @notice Returns virtual price of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getVirtualPrice(address poolAddress)
        external
        view
        returns (uint256);

    /**
     * @notice Returns A of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getA(address poolAddress) external view returns (uint256);

    /**
     * @notice Returns the paused status of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getPaused(address poolAddress) external view returns (bool);

    /**
     * @notice Returns the swap fee of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getSwapFee(address poolAddress) external view returns (uint256);

    /**
     * @notice Returns the admin fee of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getAdminFee(address poolAddress)
        external
        view
        returns (uint256 adminFee);

    /**
     * @notice Returns the SwapStorage struct of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getSwapStorage(address poolAddress)
        external
        view
        returns (
            uint256 initialA,
            uint256 futureA,
            uint256 initialATime,
            uint256 futureATime,
            uint256 swapFee,
            uint256 adminFee,
            address lpToken
        );

    /**
     * @notice Returns the tokens of the given pool address
     * @param poolAddress address of the pool to read
     */
    function getTokens(address poolAddress)
        external
        view
        returns (address[] memory);

    /**
     * @notice Returns the underlhying tokens of the given pool address. Base pools will return an empty array.
     * @param poolAddress address of the pool to read
     */
    function getUnderlyingTokens(address poolAddress)
        external
        view
        returns (address[] memory);

    /**
     * @notice Returns number of entries in the registry
     */
    function getPoolsLength() external view returns (uint256);

    /**
     * @notice Returns an array of pool addresses that can swap between from and to
     * @param from address of the token to swap from
     * @param to address of the token to swap to
     * @return eligiblePools array of pool addresses that can swap between from and to
     */
    function getEligiblePools(address from, address to)
        external
        view
        returns (address[] memory eligiblePools);
}
