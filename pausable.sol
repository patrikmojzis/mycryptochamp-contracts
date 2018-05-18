pragma solidity 0.4.23;

import "./ownable.sol";

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is Ownable {
  bool private paused = false;

  /**
   * @dev Modifier to allow actions only when the contract IS paused
     @dev If is paused msg.value is send back
   */
  modifier whenNotPaused() {
    if(paused == true && msg.value > 0){
      msg.sender.transfer(msg.value);
    }
    require(!paused);
    _;
  }


  /**
   * @dev Called by the owner to pause, triggers stopped state
   */
  function triggerPause() onlyOwner external {
    paused = !paused;
  }

}