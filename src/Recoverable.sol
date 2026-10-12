pragma solidity 0.4.23;

import "../zeppelin/contracts/token/ERC20/ERC20Basic.sol";
import "../zeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./Multiownable.sol";


/**
 * @title Recoverable ensures ether and ERC20 tokens can be claimed by the
 * owners of the contract.
 * @author Zachary Kilgore @ Xelora Technologies LLC
 * @dev Prevents accidental loss of tokens and ether erroneously sent to
 * this contract. Recovery requires the Multiownable threshold of owners.
 */
contract Recoverable is Multiownable {
  using SafeERC20 for ERC20Basic;

  /**
   * @dev Transfer all ether held by the contract to a recipient.
   * @param _to Address that receives the ether
   */
  function reclaimEther(address _to) external onlyManyOwners {
    require(_to != address(0), "Recipient must not be blank");
    _to.transfer(address(this).balance);
  }

  /**
   * @dev Transfer all of an ERC20 token held by the contract to a recipient.
   * @param _token The ERC20 token to reclaim
   * @param _to Address that receives the tokens
   */
  function reclaimToken(ERC20Basic _token, address _to) public onlyManyOwners {
    require(_to != address(0), "Recipient must not be blank");
    _token.safeTransfer(_to, _token.balanceOf(this));
  }

}
