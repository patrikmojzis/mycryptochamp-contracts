pragma solidity 0.4.23;

import "./champattack.sol";
import "./safemath.sol";

/// @title Moderates buying and selling champs
/// @author Patrik Mojzis
contract ChampMarket is ChampAttack {

    event TransferChamp(address from, address to, uint256 champID);

    /*
     * Modifiers
     */
    ///@notice Require champ to be sale
    modifier champIsForSale(uint256 _id){
        require(champs[_id].forSale);
        _;
    }
    

    ///@notice Require champ NOT to be for sale
    modifier champIsNotForSale(uint256 _id){
        require(champs[_id].forSale == false);
        _;
    }
    

    ///@notice If champ is for sale then cancel sale
    modifier ifChampForSaleThenCancelSale(uint256 _champID){
      Champ storage champ = champs[_champID];
      if(champ.forSale){
          _cancelChampSale(champ);
      }
      _;
    }
    

    /*
     * View
     */
    ///@notice Gets all champs for sale
    function getChampsForSale() view external returns(uint256[]){
        uint256[] memory result = new uint256[](champsForSaleCount);
        if(champsForSaleCount > 0){
            uint256 counter = 0;
            for (uint256 i = 0; i < champs.length; i++) {
                if (champs[i].forSale == true) {
                    result[counter]=i;
                    counter++;
                }
            }
        }
        return result;
    }
    
    
    /*
     * Private
     */
     ///@dev Cancel sale. Should not be called without checking if champ is really for sale.
     function _cancelChampSale(Champ storage champ) private {
        //cancel champ's sale
        //no need waste gas to overwrite his price.
        champ.forSale = false;
        champsForSaleCount--;
     }
     

    /*
     * Internal
     */
    /// @notice Transfer champ
    function transferChamp(address _from, address _to, uint256 _champId) internal ifChampForSaleThenCancelSale(_champId){
        Champ storage champ = champs[_champId];

        //transfer champ
        addressInfo[_to].champsCount++;
        addressInfo[_from].champsCount--;
        champToOwner[_champId] = _to;

        //transfer items
        if(champ.eq_sword != 0) { transferItem(_from, _to, champ.eq_sword); }
        if(champ.eq_shield != 0) { transferItem(_from, _to, champ.eq_shield); }
        if(champ.eq_helmet != 0) { transferItem(_from, _to, champ.eq_helmet); }

        emit TransferChamp(_from, _to, _champId);
    }



    /*
     * Public
     */
    /// @notice Champ is no more for sale
    function cancelChampSale(uint256 _id) public 
      champIsForSale(_id) 
      onlyOwnerOfChamp(_id) {
        Champ storage champ = champs[_id];
        _cancelChampSale(champ);
    }


    /*
     * External
     */
    /// @notice Gift champ
    /// @dev Address _from is msg.sender
    function giveChamp(address _to, uint256 _champId) external 
      onlyOwnerOfChamp(_champId) {
        transferChamp(msg.sender, _to, _champId);
    }


    /// @notice Sets champ for sale
    function setChampForSale(uint256 _id, uint256 _price) external 
      onlyOwnerOfChamp(_id) 
      champIsNotForSale(_id) {
        Champ storage champ = champs[_id];
        champ.forSale = true;
        champ.price = _price;
        champsForSaleCount++;
    }
    
    
    /// @notice Buys champ
    function buyChamp(uint256 _id) external payable 
      whenNotPaused 
      onlyNotOwnerOfChamp(_id) 
      champIsForSale(_id) 
      isPaid(champs[_id].price) 
      distributeSaleInput(champToOwner[_id]) {
        transferChamp(champToOwner[_id], msg.sender, _id);
    }
    
}