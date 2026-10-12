// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {MultiownableBase} from "./MultiownableBase.sol";
import {IRecoverable} from "./Interfaces.sol";

contract MultiownableTest is MultiownableBase {
    IRecoverable internal target;
    address payable internal recipient = payable(makeAddr("recipient"));

    function setUp() public {
        target = IRecoverable(deployCode(_artifact("PayableRecoverableMock")));
        vm.deal(address(target), 1 ether);
    }

    function test_DeployerIsSoleOwnerWithThresholdOne() public view {
        assertEq(target.ownersCount(), 1);
        assertEq(target.owners(0), address(this));
        assertEq(target.threshold(), 1);
    }

    function test_ChangeOwnersInstallsOwnerSet() public {
        _installOwners(target);
        assertEq(target.ownersCount(), 3);
        assertEq(target.threshold(), 2);
        assertEq(target.ownerIndex(alice), 1);
        assertEq(target.ownerIndex(carol), 3);
        assertEq(target.ownerIndex(address(this)), 0);
        assertEq(target.ownersGeneration(), 1);
    }

    function test_OneVoteDoesNotExecute() public {
        _installOwners(target);
        vm.prank(alice);
        target.reclaimEther(recipient);
        assertEq(recipient.balance, 0);
        assertEq(address(target).balance, 1 ether);
    }

    function test_ThresholdVotesExecute() public {
        _installOwners(target);
        _approve(address(target), abi.encodeCall(IRecoverable.reclaimEther, (recipient)));
        assertEq(recipient.balance, 1 ether);
    }

    function test_VotesResetAfterExecution() public {
        _installOwners(target);
        bytes memory data = abi.encodeCall(IRecoverable.reclaimEther, (recipient));
        _approve(address(target), data);
        assertEq(target.votesCount(_operation(target, data)), 0);
    }

    function test_DoubleVoteReverts() public {
        _installOwners(target);
        vm.startPrank(alice);
        target.reclaimEther(recipient);
        vm.expectRevert("Owner already voted");
        target.reclaimEther(recipient);
    }

    function test_NonOwnerCannotVote() public {
        _installOwners(target);
        vm.prank(mallory);
        vm.expectRevert("Caller must be an owner");
        target.reclaimEther(mallory);
    }

    function test_FormerDeployerCannotVote() public {
        _installOwners(target);
        vm.expectRevert("Caller must be an owner");
        target.reclaimEther(recipient);
    }

    function test_DifferentArgumentsAreDifferentOperations() public {
        _installOwners(target);
        vm.prank(alice);
        target.reclaimEther(alice);
        vm.prank(bob);
        target.reclaimEther(bob);
        assertEq(alice.balance, 0);
        assertEq(bob.balance, 0);
        assertEq(address(target).balance, 1 ether);
    }

    function test_CancelWithdrawsVote() public {
        _installOwners(target);
        bytes memory data = abi.encodeCall(IRecoverable.reclaimEther, (recipient));
        bytes32 operation = _operation(target, data);

        vm.prank(alice);
        target.reclaimEther(recipient);
        vm.prank(alice);
        target.cancel(operation);
        vm.prank(bob);
        target.reclaimEther(recipient);

        assertEq(recipient.balance, 0);
        assertEq(target.votesCount(operation), 1);
    }

    function test_CancelWithoutVoteReverts() public {
        _installOwners(target);
        vm.prank(alice);
        vm.expectRevert("Caller has not voted for this operation");
        target.cancel(bytes32(0));
    }

    function test_ChangeOwnersInvalidatesPendingVotes() public {
        _installOwners(target);
        vm.prank(alice);
        target.reclaimEther(recipient);

        address[] memory owners = new address[](3);
        (owners[0], owners[1], owners[2]) = (alice, bob, carol);
        _approve(address(target), abi.encodeCall(target.changeOwners, (owners, 2)));

        vm.prank(bob);
        target.reclaimEther(recipient);
        assertEq(recipient.balance, 0);
    }

    function test_ChangeOwnersRejectsBadInput() public {
        address[] memory none = new address[](0);
        vm.expectRevert("Owner count must be between 1 and 256");
        target.changeOwners(none, 1);

        address[] memory duplicated = new address[](2);
        (duplicated[0], duplicated[1]) = (alice, alice);
        vm.expectRevert("Owner must not be duplicated");
        target.changeOwners(duplicated, 1);

        address[] memory blank = new address[](1);
        vm.expectRevert("Owner must not be blank");
        target.changeOwners(blank, 1);

        address[] memory one = new address[](1);
        one[0] = alice;
        vm.expectRevert("Threshold must be between 1 and owner count");
        target.changeOwners(one, 2);
        vm.expectRevert("Threshold must be between 1 and owner count");
        target.changeOwners(one, 0);
    }

    function test_ReclaimEtherRejectsBlankRecipient() public {
        _installOwners(target);
        vm.prank(alice);
        target.reclaimEther(address(0));
        vm.prank(bob);
        vm.expectRevert("Recipient must not be blank");
        target.reclaimEther(address(0));
    }
}
