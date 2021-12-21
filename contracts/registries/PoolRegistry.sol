// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/IMetaSwap.sol";
import "../meta/MetaSwapDeposit.sol";

/**
 * @title PoolRegistry
 * @notice This contract holds list of pools deployed.
 */
contract PoolRegistry is Ownable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant SADDLE_MANAGER_ROLE =
        keccak256("SADDLE_MANAGER_ROLE");
    bytes32 public constant COMMUNITY_MANAGER_ROLE =
        keccak256("COMMUNITY_MANAGER_ROLE");

    PoolData[] public saddlePools;
    mapping(address => uint256) public poolToSaddleIndexPlusOne;
    PoolData[] public communityPools;
    mapping(address => uint256) public poolToCommunityIndexPlusOne;

    enum PoolType {
        BTC,
        ETH,
        USD,
        OTHERS
    }

    event AddPool(address indexed poolAddress, PoolData poolData);
    event UpdatePool(address indexed poolAddress, PoolData poolData);
    event RemovePool(address indexed poolAddress);

    struct PoolData {
        address poolAddress;
        string poolName;
        address lpToken;
        PoolType typeOfAsset;
        address[] tokens;
        address[] underlyingTokens;
        address basePoolAddress;
        address metaPoolDepositAddress;
        bool isSaddlePool;
        bool isRemoved;
    }

    constructor(address governance) public Ownable() {
        _setupRole(DEFAULT_ADMIN_ROLE, governance);
        _setupRole(SADDLE_MANAGER_ROLE, msg.sender);
    }

    function addPool(PoolData memory poolData) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        require(
            poolToSaddleIndexPlusOne[poolData.poolAddress] == 0 &&
                poolToCommunityIndexPlusOne[poolData.poolAddress] == 0,
            "Pool is already added"
        );

        // Effect
        saddlePools.push(poolData);

        // Checks and Interactions
        // Check lp token address
        {
            (, , , , , , address lpToken) = getSwapStorage(
                poolData.poolAddress
            );
            require(lpToken == poolData.lpToken);
            require(Ownable(lpToken).owner() == poolData.poolAddress);
        }

        // Check token addresses
        for (uint8 i = 0; i < 32; i++) {
            try ISwap(poolData.poolAddress).getToken(i) returns (IERC20 token) {
                require(address(token) == poolData.tokens[i]);
            } catch {
                require(i == poolData.tokens.length);
            }
        }

        // Check base pool
        if (poolData.basePoolAddress != address(0)) {
            (address baseSwap, , ) = IMetaSwap(poolData.poolAddress)
                .metaSwapStorage();
            require(baseSwap == poolData.basePoolAddress);

            for (uint8 i = 0; i < 32; i++) {
                try
                    MetaSwapDeposit(poolData.metaPoolDepositAddress).getToken(i)
                returns (IERC20 token) {
                    require(address(token) == poolData.underlyingTokens[i]);
                } catch {
                    require(i == poolData.underlyingTokens.length);
                }
            }
            require(
                address(
                    MetaSwapDeposit(poolData.metaPoolDepositAddress).baseSwap()
                ) == poolData.basePoolAddress
            );
            require(
                address(
                    MetaSwapDeposit(poolData.metaPoolDepositAddress).metaSwap()
                ) == poolData.poolAddress
            );
        }

        emit AddPool(poolData.poolAddress, poolData);
    }

    function addCommunityPool(PoolData memory poolData) external {
        require(
            hasRole(COMMUNITY_MANAGER_ROLE, msg.sender),
            "Caller is not community manager"
        );
        require(
            poolToSaddleIndexPlusOne[poolData.poolAddress] == 0 &&
                poolToCommunityIndexPlusOne[poolData.poolAddress] == 0,
            "Pool is already added"
        );
        communityPools.push(poolData);

        emit AddPool(poolData.poolAddress, poolData);
    }

    function approvePool(address poolAddress) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[poolAddress];
        require(saddleIndex == 0, "Pool is already approved");
        require(communityIndex > 0, "No matching pool found");

        communityIndex -= 1;
        PoolData storage poolData = communityPools[communityIndex];

        require(poolData.poolAddress == poolAddress, "Something went wrong");

        // Effect
        poolData.isSaddlePool = true;
        saddlePools.push(poolData);

        // Interaction
        require(
            ISwap(poolAddress).owner() == owner(),
            "Pool is not owned by saddle"
        );

        emit AddPool(poolAddress, poolData);
    }

    function updatePool(PoolData memory poolData) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolData.poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[
            poolData.poolAddress
        ];
        require(
            saddleIndex > 0 || communityIndex > 0,
            "No matching pool found"
        );

        if (saddleIndex > 0) {
            saddlePools[saddleIndex - 1] = poolData;
        }
        if (communityIndex > 0) {
            communityPools[communityIndex - 1] = poolData;
        }

        emit UpdatePool(poolData.poolAddress, poolData);
    }

    function removePool(address poolAddress) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[poolAddress];
        require(
            saddleIndex > 0 || communityIndex > 0,
            "No matching pool found"
        );

        if (saddleIndex > 0) {
            saddlePools[saddleIndex - 1].isRemoved = true;
            poolToSaddleIndexPlusOne[poolAddress] = 0;
        }
        if (communityIndex > 0) {
            communityPools[communityIndex - 1].isRemoved = true;
            poolToCommunityIndexPlusOne[poolAddress] = 0;
        }

        emit RemovePool(poolAddress);
    }

    function getPoolData(address poolAddress)
        external
        view
        returns (PoolData memory)
    {
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[poolAddress];

        if (saddleIndex > 0) {
            return saddlePools[saddleIndex - 1];
        } else if (communityIndex > 0) {
            return communityPools[communityIndex - 1];
        } else {
            revert("No matching pool found");
        }
    }

    modifier hasMatchingPool(address poolAddress) {
        require(
            poolToSaddleIndexPlusOne[poolAddress] > 0 ||
                poolToCommunityIndexPlusOne[poolAddress] > 0,
            "No matching pool found"
        );
        _;
    }

    function getVirtualPrice(address poolAddress)
        external
        view
        hasMatchingPool(poolAddress)
        returns (uint256)
    {
        return ISwap(poolAddress).getVirtualPrice();
    }

    function getA(address poolAddress)
        external
        view
        hasMatchingPool(poolAddress)
        returns (uint256)
    {
        return ISwap(poolAddress).getA();
    }

    function getPaused(address poolAddress)
        external
        view
        hasMatchingPool(poolAddress)
        returns (bool)
    {
        return ISwap(poolAddress).paused();
    }

    function getSwapFee(address poolAddress)
        external
        view
        hasMatchingPool(poolAddress)
        returns (uint256 swapFee)
    {
        (, , , , swapFee, , ) = ISwap(poolAddress).swapStorage();
    }

    function getAdminFee(address poolAddress)
        external
        view
        hasMatchingPool(poolAddress)
        returns (uint256 adminFee)
    {
        (, , , , , adminFee, ) = ISwap(poolAddress).swapStorage();
    }

    function getSwapStorage(address poolAddress)
        public
        view
        hasMatchingPool(poolAddress)
        returns (
            uint256 initialA,
            uint256 futureA,
            uint256 initialATime,
            uint256 futureATime,
            uint256 swapFee,
            uint256 adminFee,
            address lpToken
        )
    {
        return ISwap(poolAddress).swapStorage();
    }

    function getTokens(address poolAddress)
        external
        view
        returns (address[] memory)
    {
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[poolAddress];

        if (saddleIndex > 0) {
            return saddlePools[saddleIndex - 1].tokens;
        } else if (communityIndex > 0) {
            return communityPools[communityIndex - 1].tokens;
        } else {
            revert("No matching pool found");
        }
    }

    function getUnderlyingTokens(address poolAddress)
        external
        view
        returns (address[] memory)
    {
        uint256 saddleIndex = poolToSaddleIndexPlusOne[poolAddress];
        uint256 communityIndex = poolToCommunityIndexPlusOne[poolAddress];

        if (saddleIndex > 0) {
            return saddlePools[saddleIndex - 1].underlyingTokens;
        } else if (communityIndex > 0) {
            return communityPools[communityIndex - 1].underlyingTokens;
        } else {
            revert("No matching pool found");
        }
    }

    function saddlePoolData() external view returns (PoolData[] memory) {
        return saddlePools;
    }

    function saddlePoolDataLength() external view returns (uint256) {
        return saddlePools.length;
    }

    function communityPoolData() external view returns (PoolData[] memory) {
        return communityPools;
    }

    function communityPoolDataLength() external view returns (uint256) {
        return communityPools.length;
    }
}
