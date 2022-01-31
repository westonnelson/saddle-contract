// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/ISwap.sol";
import "../interfaces/ISwapGuarded.sol";
import "../interfaces/IMetaSwap.sol";
import "../interfaces/IPoolRegistry.sol";
import "../meta/MetaSwapDeposit.sol";
import "hardhat/console.sol";

/**
 * @title PoolRegistry
 * @notice This contract holds list of pools deployed.
 */
contract PoolRegistry is AccessControl, ReentrancyGuard, IPoolRegistry {
    using SafeMath for uint256;

    /// @notice Role responsible for managing pools.
    bytes32 public constant SADDLE_MANAGER_ROLE =
        keccak256("SADDLE_MANAGER_ROLE");
    /// @notice Role responsible for managing community pools
    bytes32 public constant COMMUNITY_MANAGER_ROLE =
        keccak256("COMMUNITY_MANAGER_ROLE");
    /// @notice Role that represents approved owners of pools.
    bytes32 public constant SADDLE_APPROVED_POOL_OWNER_ROLE =
        keccak256("SADDLE_APPROVED_POOL_OWNER_ROLE");

    /// @inheritdoc IPoolRegistry
    mapping(address => uint256) public override poolsIndexOfPlusOne;
    /// @inheritdoc IPoolRegistry
    mapping(bytes32 => uint256) public override poolsIndexOfNamePlusOne;

    PoolData[] private pools;
    mapping(uint256 => address[]) private eligiblePairsMap;

    /**
     * @notice Add a new registry entry to the master list.
     * @param poolAddress address of the added pool
     * @param index index of the added pool in the pools list
     * @param poolData added pool data
     */
    event AddPool(
        address indexed poolAddress,
        uint256 index,
        PoolData poolData
    );

    /**
     * @notice Add a new registry entry to the master list.
     * @param poolAddress address of the updated pool
     * @param index index of the updated pool in the pools list
     * @param poolData updated pool data
     */
    event UpdatePool(
        address indexed poolAddress,
        uint256 index,
        PoolData poolData
    );

    /**
     * @notice Add a new registry entry to the master list.
     * @param poolAddress address of the removed pool
     * @param index index of the removed pool in the pools list
     */
    event RemovePool(address indexed poolAddress, uint256 index);

    /**
     * @notice Deploy this contract and set appropriate roles
     * @param admin address who should have the DEFAULT_ADMIN_ROLE
     * @dev caller of this function will be set as the owner on deployment
     */
    constructor(address admin, address poolOwner) public {
        require(admin != address(0), "admin == 0");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(SADDLE_MANAGER_ROLE, msg.sender);
        _setupRole(SADDLE_APPROVED_POOL_OWNER_ROLE, poolOwner);
    }

    /// @inheritdoc IPoolRegistry
    function addPool(PoolInputData memory inputData)
        external
        override
        nonReentrant
    {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender) ||
                (hasRole(COMMUNITY_MANAGER_ROLE, msg.sender) &&
                    !inputData.isSaddleApproved),
            "PR: Only managers can add pools"
        );
        require(inputData.poolAddress != address(0), "PR: poolAddress is 0");
        require(
            poolsIndexOfPlusOne[inputData.poolAddress] == 0,
            "PR: Pool is already added"
        );

        address[] memory tokens = new address[](8);
        address[] memory underlyingTokens = new address[](8);

        PoolData memory data = PoolData(
            inputData.poolAddress,
            address(0),
            inputData.typeOfAsset,
            inputData.poolName,
            inputData.targetAddress,
            tokens,
            underlyingTokens,
            address(0),
            inputData.metaSwapDepositAddress,
            inputData.pid,
            inputData.isSaddleApproved,
            inputData.isRemoved
        );

        // Get lp token address
        (, , , , , , data.lpToken) = _getSwapStorage(inputData.poolAddress);

        // Check token addresses
        for (uint8 i = 0; i < 8; i++) {
            try ISwap(inputData.poolAddress).getToken(i) returns (
                IERC20 token
            ) {
                require(address(token) != address(0), "PR: token is 0");
                tokens[i] = address(token);
                // add combinations of tokens to eligible pairs map
                for (uint8 j = 0; j < i; j++) {
                    eligiblePairsMap[uint160(tokens[i]) ^ uint160(tokens[j])]
                        .push(inputData.poolAddress);
                }
            } catch {
                assembly {
                    mstore(tokens, sub(mload(tokens), sub(8, i)))
                }
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
                "PR: base pool not found"
            );

            // Get underlying tokens
            for (uint8 i = 0; i < 8; i++) {
                try
                    MetaSwapDeposit(inputData.metaSwapDepositAddress).getToken(
                        i
                    )
                returns (IERC20 token) {
                    require(address(token) != address(0), "PR: token is 0");
                    underlyingTokens[i] = address(token);
                    // add combinations of tokens to eligible pairs map
                    // i reprents the indexes of the underlying tokens of metaLPToken.
                    // j represents the indexes of MetaSwap level tokens that are not metaLPToken.
                    // Example: tokens = [sUSD, baseLPToken]
                    //         underlyingTokens = [sUSD, DAI, USDC, USDT]
                    // i represents index of [DAI, USDC, USDT] in underlyingTokens
                    // j represents index of [sUSD] in underlyingTokens
                    if (i > tokens.length.sub(2))
                        for (uint256 j = 0; j < tokens.length - 1; j++) {
                            eligiblePairsMap[
                                uint160(underlyingTokens[i]) ^
                                    uint160(underlyingTokens[j])
                            ].push(inputData.metaSwapDepositAddress);
                        }
                } catch {
                    assembly {
                        mstore(
                            underlyingTokens,
                            sub(mload(underlyingTokens), sub(8, i))
                        )
                    }
                    break;
                }
            }
            require(
                address(
                    MetaSwapDeposit(inputData.metaSwapDepositAddress).metaSwap()
                ) == inputData.poolAddress,
                "PR: metaSwap address mismatch"
            );
        } else {
            assembly {
                mstore(underlyingTokens, sub(mload(underlyingTokens), 8))
            }
        }

        pools.push(data);
        poolsIndexOfPlusOne[data.poolAddress] = pools.length;
        poolsIndexOfNamePlusOne[data.poolName] = pools.length;

        emit AddPool(inputData.poolAddress, pools.length - 1, data);
    }

    /// @inheritdoc IPoolRegistry
    function approvePool(address poolAddress) external override managerOnly {
        uint256 poolIndex = poolsIndexOfPlusOne[poolAddress];
        require(poolIndex > 0, "PR: Pool not found");

        PoolData storage poolData = pools[poolIndex];

        require(
            poolData.poolAddress == poolAddress,
            "PR: poolAddress mismatch"
        );

        // Effect
        poolData.isSaddleApproved = true;

        // Interaction
        require(
            hasRole(
                SADDLE_APPROVED_POOL_OWNER_ROLE,
                ISwap(poolAddress).owner()
            ),
            "Pool is not owned by saddle"
        );

        emit UpdatePool(poolAddress, poolIndex, poolData);
    }

    /// @inheritdoc IPoolRegistry
    function updatePool(PoolData memory poolData)
        external
        override
        managerOnly
    {
        uint256 poolIndex = poolsIndexOfPlusOne[poolData.poolAddress];
        require(poolIndex > 0, "PR: Pool not found");
        poolIndex -= 1;

        pools[poolIndex] = poolData;

        emit UpdatePool(poolData.poolAddress, poolIndex, poolData);
    }

    /// @inheritdoc IPoolRegistry
    function removePool(address poolAddress) external override managerOnly {
        uint256 poolIndex = poolsIndexOfPlusOne[poolAddress];
        require(poolIndex > 0, "PR: Pool not found");
        poolIndex -= 1;

        pools[poolIndex].isRemoved = true;

        emit RemovePool(poolAddress, poolIndex);
    }

    /// @inheritdoc IPoolRegistry
    function getPoolDataAtIndex(uint256 index)
        external
        view
        override
        returns (PoolData memory)
    {
        require(index < pools.length, "PR: Index out of bounds");
        return pools[index];
    }

    /// @inheritdoc IPoolRegistry
    function getPoolData(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (PoolData memory)
    {
        return pools[poolsIndexOfPlusOne[poolAddress] - 1];
    }

    modifier hasMatchingPool(address poolAddress) {
        require(
            poolsIndexOfPlusOne[poolAddress] > 0,
            "PR: No matching pool found"
        );
        _;
    }

    modifier managerOnly() {
        require(
            hasRole(SADDLE_MANAGER_ROLE, msg.sender),
            "PR: Caller is not saddle manager"
        );
        _;
    }

    /// @inheritdoc IPoolRegistry
    function getVirtualPrice(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (uint256)
    {
        return ISwap(poolAddress).getVirtualPrice();
    }

    /// @inheritdoc IPoolRegistry
    function getA(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (uint256)
    {
        return ISwap(poolAddress).getA();
    }

    /// @inheritdoc IPoolRegistry
    function getPaused(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (bool)
    {
        return ISwap(poolAddress).paused();
    }

    /// @inheritdoc IPoolRegistry
    function getSwapFee(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (uint256 swapFee)
    {
        (, , , , swapFee, , ) = _getSwapStorage(poolAddress);
    }

    /// @inheritdoc IPoolRegistry
    function getAdminFee(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (uint256 adminFee)
    {
        (, , , , , adminFee, ) = _getSwapStorage(poolAddress);
    }

    /// @inheritdoc IPoolRegistry
    function getSwapStorage(address poolAddress)
        external
        view
        override
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
        try ISwap(poolAddress).swapStorage() returns (
            uint256 _initialA,
            uint256 _futureA,
            uint256 _initialATime,
            uint256 _futureATime,
            uint256 _swapFee,
            uint256 _adminFee,
            address _lpToken
        ) {
            return (
                _initialA,
                _futureA,
                _initialATime,
                _futureATime,
                _swapFee,
                _adminFee,
                _lpToken
            );
        } catch {
            try ISwapGuarded(poolAddress).swapStorage() returns (
                uint256 _initialA,
                uint256 _futureA,
                uint256 _initialATime,
                uint256 _futureATime,
                uint256 _swapFee,
                uint256 _adminFee,
                uint256,
                address _lpToken
            ) {
                return (
                    _initialA,
                    _futureA,
                    _initialATime,
                    _futureATime,
                    _swapFee,
                    _adminFee,
                    _lpToken
                );
            } catch {
                revert("PR: No swap storage found");
            }
        }
    }

    /// @inheritdoc IPoolRegistry
    function getTokens(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (address[] memory)
    {
        uint256 poolIndex = poolsIndexOfPlusOne[poolAddress];

        if (poolIndex > 0) {
            return pools[poolIndex - 1].tokens;
        }
        revert("PR: No matching pool found");
    }

    /// @inheritdoc IPoolRegistry
    function getUnderlyingTokens(address poolAddress)
        external
        view
        override
        returns (address[] memory)
    {
        uint256 poolIndex = poolsIndexOfPlusOne[poolAddress];

        if (poolIndex > 0) {
            return pools[poolIndex - 1].underlyingTokens;
        }
        revert("PR: No matching pool found");
    }

    /// @inheritdoc IPoolRegistry
    function getPoolsLength() external view override returns (uint256) {
        return pools.length;
    }

    /// @inheritdoc IPoolRegistry
    function getEligiblePools(address from, address to)
        external
        view
        override
        returns (address[] memory eligiblePools)
    {
        require(
            from != address(0) && from != to,
            "PR: from and to cannot be the zero address"
        );
        return eligiblePairsMap[uint160(from) ^ uint160(to)];
    }

    /// @inheritdoc IPoolRegistry
    function getBalances(address poolAddress)
        external
        view
        override
        hasMatchingPool(poolAddress)
        returns (address[] memory tokens, uint256[] memory balances)
    {
        tokens = pools[poolsIndexOfPlusOne[poolAddress] - 1].tokens;
        balances = new uint256[](tokens.length);
        for (uint8 i = 0; i < tokens.length; i++) {
            balances[i] = ISwap(poolAddress).getTokenBalance(i);
        }
    }
}
