pragma solidity 0.4.23;


/**
 * @title Multiownable requires a threshold of distinct owners to approve
 * a call before the guarded function body executes.
 * @dev Modeled on BitClave's Multiownable. An operation is identified by the
 * hash of the full calldata and the owners generation, so every owner must
 * submit identical arguments. Guarded functions must not call each other:
 * the inner call would start a new vote and silently skip its body.
 */
contract Multiownable {

  /** Current owners. */
  address[] public owners;

  /** Position of an owner in `owners`, plus one. Zero means not an owner. */
  mapping(address => uint256) public ownerIndex;

  /** Number of distinct owner votes needed to execute an operation. */
  uint256 public threshold;

  /** Incremented on every owner change to invalidate pending votes. */
  uint256 public ownersGeneration;

  /** Bitmask of the owners who voted for an operation. */
  mapping(bytes32 => uint256) public votesMask;

  /** Number of votes an operation has received. */
  mapping(bytes32 => uint256) public votesCount;


  event OperationUpvoted(bytes32 indexed operation, address indexed owner, uint256 votes, uint256 threshold);

  event OperationPerformed(bytes32 indexed operation, address indexed performer);

  event OperationCancelled(bytes32 indexed operation, address indexed owner);

  event OwnersChanged(address[] owners, uint256 threshold);


  /** Ensure the caller is one of the owners. */
  modifier onlyAnyOwner() {
    require(ownerIndex[msg.sender] != 0, "Caller must be an owner");
    _;
  }

  /** Record the caller's vote and execute once the threshold is reached. */
  modifier onlyManyOwners() {
    if (_vote()) {
      _;
    }
  }


  /**
   * @dev The deployer is the sole owner with a threshold of one until
   * `changeOwners` installs the real owner set.
   */
  constructor() public {
    owners.push(msg.sender);
    ownerIndex[msg.sender] = 1;
    threshold = 1;
  }

  /**
   * @return The number of owners
   */
  function ownersCount() public view returns(uint256) {
    return owners.length;
  }

  /**
   * @notice Replace the owner set and threshold.
   * @param _newOwners The new owners, between 1 and 256 unique addresses
   * @param _threshold The number of owner votes needed per operation
   */
  function changeOwners(address[] _newOwners, uint256 _threshold) public onlyManyOwners {
    require(_newOwners.length > 0 && _newOwners.length <= 256, "Owner count must be between 1 and 256");
    require(_threshold > 0 && _threshold <= _newOwners.length, "Threshold must be between 1 and owner count");

    for (uint256 i = 0; i < owners.length; i++) {
      delete ownerIndex[owners[i]];
    }
    for (uint256 j = 0; j < _newOwners.length; j++) {
      require(_newOwners[j] != address(0), "Owner must not be blank");
      require(ownerIndex[_newOwners[j]] == 0, "Owner must not be duplicated");
      ownerIndex[_newOwners[j]] = j + 1;
    }

    owners = _newOwners;
    threshold = _threshold;
    ownersGeneration++;

    emit OwnersChanged(_newOwners, _threshold);
  }

  /**
   * @notice Withdraw the caller's vote from a pending operation.
   * @param _operation The operation hash from `OperationUpvoted`
   */
  function cancel(bytes32 _operation) external onlyAnyOwner {
    uint256 bit = 2 ** (ownerIndex[msg.sender] - 1);
    require(votesMask[_operation] & bit != 0, "Caller has not voted for this operation");

    votesMask[_operation] &= ~bit;
    votesCount[_operation]--;

    emit OperationCancelled(_operation, msg.sender);
  }

  /**
   * @dev Record a vote for the current calldata.
   * @return true if the threshold is reached and the body should execute
   */
  function _vote() internal returns(bool) {
    uint256 index = ownerIndex[msg.sender];
    require(index != 0, "Caller must be an owner");

    bytes32 operation = keccak256(abi.encodePacked(msg.data, ownersGeneration));
    uint256 bit = 2 ** (index - 1);
    require(votesMask[operation] & bit == 0, "Owner already voted");

    votesMask[operation] |= bit;
    uint256 votes = votesCount[operation] + 1;
    votesCount[operation] = votes;

    emit OperationUpvoted(operation, msg.sender, votes, threshold);

    if (votes < threshold) {
      return false;
    }

    delete votesMask[operation];
    delete votesCount[operation];

    emit OperationPerformed(operation, msg.sender);

    return true;
  }

}
