pragma solidity 0.4.24;

import "./ownable.sol";
import "./interface.sol";

contract Inherit is Ownable{
  address internal coreAddress;
  MyCryptoChampCore internal core;

  modifier onlyCore(){
  	require(msg.sender == coreAddress);
  	_;
  }

  function loadCoreAddress(address newCoreAddress) public onlyOwner {
    require(newCoreAddress != address(0));
    coreAddress = newCoreAddress;
    core = MyCryptoChampCore(coreAddress);
  }

}
