// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/IMetaSwap.sol";
import "../meta/MetaSwapDeposit.sol";
import "hardhat/console.sol";

/**
 * @title PoolRegistry
 * @notice This contract holds list of pools deployed.
 */
contract PoolRegistry is Ownable, AccessControl, ReentrancyGuard {
    using SafeMath for uint256;

    bytes32 public constant SADDLE_MANAGER_ROLE =
        keccak256("SADDLE_MANAGER_ROLE");
    bytes32 public constant COMMUNITY_MANAGER_ROLE =
        keccak256("COMMUNITY_MANAGER_ROLE");

    PoolData[] public pools;
    mapping(address => uint256) public poolsIndexOfPlusOne;
    mapping(string => uint256) public poolsIndexOfNamePlusOne;

    event AddPool(
        address indexed poolAddress,
        uint256 index,
        PoolData poolData
    );
    event UpdatePool(
        address indexed poolAddress,
        uint256 index,
        PoolData poolData
    );
    event RemovePool(address indexed poolAddress, uint256 index);

    struct PoolOutputData {
        address poolAddress;
        address lpToken;
        string poolName;
        uint8 typeOfAsset;
        address[] tokens;
        address[] underlyingTokens;
        address basePoolAddress;
        address metaSwapDepositAddress;
        bool isSaddlePool;
        bool isRemoved;
    }

    struct PoolInputData {
        address poolAddress;
        string poolName;
        uint8 typeOfAsset;
        address metaSwapDepositAddress;
        bool isSaddleApproved;
        bool isRemoved;
    }

    struct PoolData {
        address poolAddress;
        address lpToken;
        string poolName;
        uint8 typeOfAsset;
        address[] tokens;
        address[] underlyingTokens;
        address basePoolAddress;
        address metaSwapDepositAddress;
        bool isSaddleApproved;
        bool isRemoved;
    }

    constructor(address governance) public Ownable() {
        _setupRole(DEFAULT_ADMIN_ROLE, governance);
        _setupRole(SADDLE_MANAGER_ROLE, msg.sender);
    }

    function addPool(PoolInputData memory inputData) external nonReentrant {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        require(inputData.poolAddress != address(0), "poolAddress == 0");
        require(
            poolsIndexOfPlusOne[inputData.poolAddress] == 0,
            "Pool is already added"
        );

        PoolData memory data = PoolData(
            inputData.poolAddress,
            address(0),
            inputData.poolName,
            inputData.typeOfAsset,
            new address[](8),
            new address[](8),
            address(0),
            inputData.metaSwapDepositAddress,
            inputData.isSaddleApproved,
            inputData.isRemoved
        );

        // Get lp token address
        (, , , , , , address lpToken) = _getSwapStorage(inputData.poolAddress);
        require(
            Ownable(lpToken).owner() == inputData.poolAddress,
            "lptoken owner mismatch"
        );
        data.lpToken = lpToken;

        // Check token addresses
        for (uint8 i = 0; i < 32; i++) {
            try ISwap(inputData.poolAddress).getToken(i) returns (
                IERC20 token
            ) {
                require(address(token) != address(0));
                data.tokens[i] = address(token);
            } catch {
                break;
            }
        }

        // Check meta swap deposit address
        if (inputData.metaSwapDepositAddress != address(0)) {
            // Get base pool address
            data.basePoolAddress = address(
                MetaSwapDeposit(inputData.metaSwapDepositAddress).baseSwap()
            );
            require(
                poolsIndexOfPlusOne[data.basePoolAddress] > 0,
                "base pool not found"
            );

            // Get underlying tokens
            address[] storage underlyingTokens;
            for (uint8 i = 0; i < 32; i++) {
                try
                    MetaSwapDeposit(inputData.metaSwapDepositAddress).getToken(
                        i
                    )
                returns (IERC20 token) {
                    require(address(token) != address(0));
                    data.underlyingTokens[i] = address(token);
                } catch {
                    break;
                }
            }
            require(
                address(
                    MetaSwapDeposit(inputData.metaSwapDepositAddress).metaSwap()
                ) == inputData.poolAddress,
                "meta swap deposit mismatch"
            );
        }

        pools.push(data);
        poolsIndexOfPlusOne[data.poolAddress] = pools.length;
        poolsIndexOfNamePlusOne[data.poolName] = pools.length;

        emit AddPool(inputData.poolAddress, pools.length - 1, data);
    }

    function approvePool(address poolAddress) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolsIndexOfPlusOne[poolAddress];
        require(saddleIndex > 0, "No matching pool");

        PoolData storage poolData = pools[saddleIndex];

        require(poolData.poolAddress == poolAddress, "Something went wrong");

        // Effect
        poolData.isSaddleApproved = true;

        // Interaction
        require(
            ISwap(poolAddress).owner() == owner(),
            "Pool is not owned by saddle"
        );

        emit UpdatePool(poolAddress, saddleIndex, poolData);
    }

    function updatePool(PoolData memory poolData) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolsIndexOfPlusOne[poolData.poolAddress];
        require(saddleIndex > 0, "No matching pool");
        saddleIndex -= 1;

        pools[saddleIndex] = poolData;

        emit UpdatePool(poolData.poolAddress, saddleIndex, poolData);
    }

    function removePool(address poolAddress) external {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "Caller is not saddle manager"
        );
        uint256 saddleIndex = poolsIndexOfPlusOne[poolAddress];
        require(saddleIndex > 0, "No matching pool");
        saddleIndex -= 1;

        pools[saddleIndex].isRemoved = true;

        emit RemovePool(poolAddress, saddleIndex);
    }

    function getPoolData(address poolAddress)
        external
        view
        returns (PoolData memory)
    {
        uint256 saddleIndex = poolsIndexOfPlusOne[poolAddress];
        if (saddleIndex > 0) {
            return pools[saddleIndex - 1];
        }
        revert("No matching pool found");
    }

    modifier hasMatchingPool(address poolAddress) {
        require(poolsIndexOfPlusOne[poolAddress] > 0, "No matching pool found");
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
        external
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
        return _getSwapStorage(poolAddress);
    }

    function _getSwapStorage(address poolAddress)
        internal
        view
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
        uint256 saddleIndex = poolsIndexOfPlusOne[poolAddress];

        if (saddleIndex > 0) {
            return pools[saddleIndex - 1].tokens;
        }
        revert("No matching pool found");
    }

    function getUnderlyingTokens(address poolAddress)
        external
        view
        returns (address[] memory)
    {
        uint256 saddleIndex = poolsIndexOfPlusOne[poolAddress];

        if (saddleIndex > 0) {
            return pools[saddleIndex - 1].underlyingTokens;
        }
        revert("No matching pool found");
    }

    function poolData() external view returns (PoolData[] memory) {
        return pools;
    }

    function poolLength() external view returns (uint256) {
        return pools.length;
    }
}
