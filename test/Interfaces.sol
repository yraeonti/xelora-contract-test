// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IERC20Basic {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

interface IMultiownable {
    function owners(uint256 index) external view returns (address);
    function ownerIndex(address owner) external view returns (uint256);
    function threshold() external view returns (uint256);
    function ownersGeneration() external view returns (uint256);
    function ownersCount() external view returns (uint256);
    function votesCount(bytes32 operation) external view returns (uint256);
    function changeOwners(address[] calldata newOwners, uint256 threshold) external;
    function cancel(bytes32 operation) external;
}

interface IRecoverable is IMultiownable {
    function reclaimEther(address to) external;
    function reclaimToken(address token, address to) external;
}

interface IXeloraCoin is IRecoverable, IERC20Basic {
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function pause() external;
    function unpause() external;
    function transferOwnership(address newOwner) external;
    function renounceOwnership() external;
    function setUpgradeAgent(address agent) external;
    function getUpgradeState() external view returns (uint8);
    function upgrade(uint256 value) external;
    function totalUpgraded() external view returns (uint256);
}

interface IUpgradeAgentMock {
    function newBalances(address holder) external view returns (uint256);
}

interface ITokenVault is IRecoverable {
    function setAllocation(address beneficiary, uint256 amount) external returns (bool);
    function lock() external;
    function unlock() external;
    function claim() external returns (bool);
    function transferFor(address beneficiary) external returns (bool);
    function allocations(address beneficiary) external view returns (uint256);
    function tokensAllocated() external view returns (uint256);
    function lockedAt() external view returns (uint256);
    function unlockedAt() external view returns (uint256);
}
