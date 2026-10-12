// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {MultiownableBase} from "./MultiownableBase.sol";
import {IXeloraCoin, IUpgradeAgentMock} from "./Interfaces.sol";

contract XeloraCoinTest is MultiownableBase {
    IXeloraCoin internal coin;
    address internal holder = makeAddr("holder");

    uint8 internal constant WAITING_FOR_AGENT = 2;
    uint8 internal constant READY_TO_UPGRADE = 3;
    uint8 internal constant UPGRADING = 4;

    function setUp() public {
        coin = IXeloraCoin(deployCode(_artifact("XeloraCoin")));
        coin.transfer(holder, 1000);
        _installOwners(coin);
    }

    function test_SupplyMintedToDeployer() public view {
        assertEq(coin.totalSupply(), 100000000000 ether);
        assertEq(coin.balanceOf(address(this)), coin.totalSupply() - 1000);
    }

    function test_OneVoteDoesNotPause() public {
        vm.prank(alice);
        coin.pause();
        assertFalse(coin.paused());
    }

    function test_TwoVotesPauseAndUnpause() public {
        _approve(address(coin), abi.encodeCall(coin.pause, ()));
        assertTrue(coin.paused());

        vm.prank(holder);
        vm.expectRevert();
        coin.transfer(alice, 1);

        _approve(address(coin), abi.encodeCall(coin.unpause, ()));
        assertFalse(coin.paused());
    }

    function test_OwnableOwnerHasNoPrivilege() public {
        assertEq(coin.owner(), address(this));
        vm.expectRevert("Caller must be an owner");
        coin.pause();
    }

    function test_TransferOwnershipDisabled() public {
        vm.prank(alice);
        vm.expectRevert("Use changeOwners");
        coin.transferOwnership(alice);
    }

    function test_RenounceOwnershipDisabled() public {
        vm.expectRevert("Use changeOwners");
        coin.renounceOwnership();
    }

    function test_SetUpgradeAgentNeedsThreshold() public {
        address agent = deployCode(_artifact("UpgradeAgentMock"), abi.encode(coin.totalSupply()));

        vm.prank(alice);
        coin.setUpgradeAgent(agent);
        assertEq(coin.getUpgradeState(), WAITING_FOR_AGENT);

        vm.prank(bob);
        coin.setUpgradeAgent(agent);
        assertEq(coin.getUpgradeState(), READY_TO_UPGRADE);

        vm.prank(holder);
        coin.upgrade(400);
        assertEq(coin.getUpgradeState(), UPGRADING);
        assertEq(coin.balanceOf(holder), 600);
        assertEq(IUpgradeAgentMock(agent).newBalances(holder), 400);
    }

    function test_ReclaimTokenSentToCoin() public {
        coin.transfer(address(coin), 50);
        _approve(address(coin), abi.encodeCall(coin.reclaimToken, (address(coin), carol)));
        assertEq(coin.balanceOf(carol), 50);
    }
}
