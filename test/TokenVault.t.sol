// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {MultiownableBase} from "./MultiownableBase.sol";
import {ITokenVault, IERC20Basic} from "./Interfaces.sol";

contract TokenVaultTest is MultiownableBase {
    ITokenVault internal vault;
    IERC20Basic internal token;
    IERC20Basic internal otherToken;

    address internal investor = makeAddr("investor");
    address internal founder = makeAddr("founder");

    uint256 internal constant TOTAL = 1000;
    uint256 internal constant VESTING = 30 days;

    function setUp() public {
        token = IERC20Basic(deployCode(_artifact("UpgradeableTokenMock"), abi.encode(1_000_000)));
        otherToken = IERC20Basic(deployCode(_artifact("UpgradeableTokenMock"), abi.encode(1_000_000)));
        vault = ITokenVault(deployCode(_artifact("TokenVault"), abi.encode(address(token), TOTAL, VESTING)));
        _installOwners(vault);
    }

    function _loadAndLock() internal {
        _approve(address(vault), abi.encodeCall(vault.setAllocation, (investor, 600)));
        _approve(address(vault), abi.encodeCall(vault.setAllocation, (founder, 400)));
        token.transfer(address(vault), TOTAL);
        _approve(address(vault), abi.encodeCall(vault.lock, ()));
    }

    function test_OneVoteDoesNotAllocate() public {
        vm.prank(alice);
        bool executed = vault.setAllocation(investor, 600);
        assertFalse(executed);
        assertEq(vault.allocations(investor), 0);
    }

    function test_TwoVotesAllocate() public {
        vm.prank(alice);
        vault.setAllocation(investor, 600);
        vm.prank(bob);
        bool executed = vault.setAllocation(investor, 600);
        assertTrue(executed);
        assertEq(vault.allocations(investor), 600);
    }

    function test_FullVestingFlow() public {
        _loadAndLock();
        assertGt(vault.lockedAt(), 0);

        vm.prank(alice);
        vault.unlock();
        vm.prank(bob);
        vm.expectRevert("Lock up must be over");
        vault.unlock();

        vm.warp(block.timestamp + VESTING);
        vm.prank(alice);
        vm.expectRevert("Owner already voted");
        vault.unlock();
        vm.prank(bob);
        vault.unlock();
        assertGt(vault.unlockedAt(), 0);

        vm.prank(investor);
        vault.claim();
        assertEq(token.balanceOf(investor), 600);

        _approve(address(vault), abi.encodeCall(vault.transferFor, (founder)));
        assertEq(token.balanceOf(founder), 400);
    }

    function test_OneVoteDoesNotLock() public {
        _approve(address(vault), abi.encodeCall(vault.setAllocation, (investor, TOTAL)));
        token.transfer(address(vault), TOTAL);
        vm.prank(alice);
        vault.lock();
        assertEq(vault.lockedAt(), 0);
    }

    function test_OwnersCannotReclaimAllocatedTokens() public {
        _loadAndLock();
        vm.prank(alice);
        vault.reclaimToken(address(token), alice);
        vm.prank(bob);
        vm.expectRevert("Only tokens above unclaimed allocations can be reclaimed");
        vault.reclaimToken(address(token), alice);
    }

    function test_OwnersCanReclaimExcessVaultToken() public {
        _loadAndLock();
        token.transfer(address(vault), 25);
        _approve(address(vault), abi.encodeCall(vault.reclaimToken, (address(token), carol)));
        assertEq(token.balanceOf(carol), 25);
        assertEq(token.balanceOf(address(vault)), TOTAL);
    }

    function test_ReservedAmountShrinksAfterClaims() public {
        _loadAndLock();
        vm.warp(block.timestamp + VESTING);
        _approve(address(vault), abi.encodeCall(vault.unlock, ()));
        vm.prank(investor);
        vault.claim();

        token.transfer(address(vault), 10);
        _approve(address(vault), abi.encodeCall(vault.reclaimToken, (address(token), carol)));
        assertEq(token.balanceOf(carol), 10);
        assertEq(token.balanceOf(address(vault)), 400);
    }

    function test_OwnersCanReclaimOtherTokens() public {
        otherToken.transfer(address(vault), 77);
        _approve(address(vault), abi.encodeCall(vault.reclaimToken, (address(otherToken), carol)));
        assertEq(otherToken.balanceOf(carol), 77);
    }
}
