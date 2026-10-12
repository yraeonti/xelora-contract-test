// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IMultiownable} from "./Interfaces.sol";

abstract contract MultiownableBase is Test {
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");
    address internal mallory = makeAddr("mallory");

    function _artifact(string memory name) internal pure returns (string memory) {
        return string.concat("out-legacy/", name, ".sol/", name, ".json");
    }

    function _installOwners(IMultiownable target) internal {
        address[] memory owners = new address[](3);
        (owners[0], owners[1], owners[2]) = (alice, bob, carol);
        target.changeOwners(owners, 2);
    }

    function _operation(IMultiownable target, bytes memory data) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(data, target.ownersGeneration()));
    }

    function _approve(address target, bytes memory data) internal {
        vm.prank(alice);
        (bool first,) = target.call(data);
        require(first, "first vote failed");
        vm.prank(bob);
        (bool second, bytes memory reason) = target.call(data);
        if (!second) {
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        }
    }
}
