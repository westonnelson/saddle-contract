// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMasterRegistry.sol";

/**
 * @title MasterRegistry
 * @notice This contract holds list of other registries or contracts and its historical versions.
 */
contract MasterRegistry is Ownable, IMasterRegistry {
    using SafeMath for uint256;

    mapping(bytes32 => address[]) private registryMap;
    mapping(address => ReverseRegistryData) private reverseRegistry;

    /**
     * @notice Add a new registry entry to the master list.
     * @param name address of the added pool
     * @param registryAddress address of the registry
     * @param version version of the registry
     */
    event AddRegistry(
        bytes32 indexed name,
        address registryAddress,
        uint256 version
    );

    /// @inheritdoc IMasterRegistry
    function addRegistry(bytes32 registryName, address registryAddress)
        external
        override
        onlyOwner
    {
        require(registryName != 0, "name cannot be empty");
        require(registryAddress != address(0), "address cannot be empty");

        address[] storage registry = registryMap[registryName];
        uint256 version = registry.length;
        registry.push(registryAddress);
        require(
            reverseRegistry[registryAddress].name == 0,
            "duplicate registry address"
        );
        reverseRegistry[registryAddress] = ReverseRegistryData(
            registryName,
            version
        );

        emit AddRegistry(registryName, registryAddress, version);
    }

    /// @inheritdoc IMasterRegistry
    function resolveNameToLatestAddress(bytes32 name)
        external
        view
        override
        returns (address)
    {
        address[] storage registry = registryMap[name];
        uint256 length = registry.length;
        require(length > 0, "no match found for name");
        return registry[length - 1];
    }

    /// @inheritdoc IMasterRegistry
    function resolveNameAndVersionToAddress(bytes32 name, uint256 version)
        external
        view
        override
        returns (address)
    {
        address[] storage registry = registryMap[name];
        require(
            version < registry.length,
            "no match found for name and version"
        );
        return registry[version];
    }

    /// @inheritdoc IMasterRegistry
    function resolveNameToAllAddresses(bytes32 name)
        external
        view
        override
        returns (address[] memory)
    {
        address[] storage registry = registryMap[name];
        require(registry.length > 0, "no match found for name");
        return registry;
    }

    /// @inheritdoc IMasterRegistry
    function resolveAddressToRegistryData(address registryAddress)
        external
        view
        override
        returns (
            bytes32 name,
            uint256 version,
            bool isLatest
        )
    {
        ReverseRegistryData memory data = reverseRegistry[registryAddress];
        require(data.name != 0, "no match found for address");
        name = data.name;
        version = data.version;
        isLatest = version == registryMap[name].length.sub(1);
    }
}
