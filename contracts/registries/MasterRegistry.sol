// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title MasterRegistry
 * @notice This contract holds list of other registries or contracts and its historical versions.
 */
contract MasterRegistry is Ownable {
    using SafeMath for uint256;

    struct ReverseRegistryData {
        string name;
        uint256 version;
    }

    mapping(string => address[]) public registryMap;
    mapping(address => ReverseRegistryData) public reverseRegistry;

    event AddRegistry(
        string indexed name,
        address registryAddress,
        uint256 version
    );

    /**
     * @notice Add a new registry entry to the master list.
     * @param registryName name for the registry
     * @param registryAddress address of the new registry
     */
    function addRegistry(string calldata registryName, address registryAddress)
        external
        onlyOwner
    {
        require(bytes(registryName).length > 0, "name cannot be empty");
        require(registryAddress != address(0), "address cannot be empty");

        address[] storage registry = registryMap[registryName];
        uint256 version = registry.length;
        registry.push(registryAddress);
        reverseRegistry[registryAddress] = ReverseRegistryData(
            registryName,
            version
        );

        emit AddRegistry(registryName, registryAddress, version);
    }

    /**
     * @notice Resolves a name to the latest registry address. Reverts if no match is found.
     * @param name name for the registry
     * @return address address of the latest registry with the matching name
     */
    function resolveNameToLatestAddress(string calldata name)
        external
        view
        returns (address)
    {
        address[] storage registry = registryMap[name];
        uint256 length = registry.length;
        require(length > 0, "No match found for name");
        return registry[length - 1];
    }

    /**
     * @notice Resolves an address to registry entry data.
     * @param registryAddress address of a registry you want to resolve
     * @return name name of the resolved registry
     * @return version version of the resolved registry
     * @return isLatest boolean flag of whether the given address is the latest version of the given registries with
     * matching name
     */
    function resolveAddressToRegistryData(address registryAddress)
        external
        view
        returns (
            string memory name,
            uint256 version,
            bool isLatest
        )
    {
        ReverseRegistryData memory data = reverseRegistry[registryAddress];
        require(bytes(data.name).length > 0, "No match found for address");
        name = data.name;
        version = data.version;
        isLatest = version == registryMap[name].length.sub(1);
    }
}
