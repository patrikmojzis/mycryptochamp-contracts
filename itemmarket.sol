pragma solidity 0.4.23;

import "./items.sol";

/// @title Moderates buying and selling items
/// @author Patrik Mojzis
contract ItemMarket is Items {

    event TransferItem(address from, address to, uint256 itemID);
    

    /*
     * Modifiers
     */
    ///@notice Checks if item is for sale
    modifier itemIsForSale(uint256 _id){
        require(items[_id].forSale);
        _;
    }

    ///@notice Checks if item is NOT for sale
    modifier itemIsNotForSale(uint256 _id){
        require(items[_id].forSale == false);
        _;
    }

    ///@notice If item is for sale then cancel sale
    modifier ifItemForSaleThenCancelSale(uint256 _itemID){
      Item storage item = items[_itemID];
      if(item.forSale){
          _cancelItemSale(item);
      }
      _;
    }


    ///@notice Distribute sale eth input
    modifier distributeSaleInput(address _owner) { 
        uint256 contractOwnerCommision; //1%
        uint256 playerShare; //99%
        
        if(msg.value > 100){
            contractOwnerCommision = (msg.value / 100);
            playerShare = msg.value - contractOwnerCommision;
        }else{
            contractOwnerCommision = 0;
            playerShare = msg.value;
        }

        addressInfo[_owner].withdrawal += playerShare;
        addressInfo[contractOwner].withdrawal += contractOwnerCommision;
        pendingWithdrawal += playerShare + contractOwnerCommision;
        _;
    }



    /*
     * View
     */
    function getItemsForSale() view external returns(uint256[]){
        uint256[] memory result = new uint256[](itemsForSaleCount);
        if(itemsForSaleCount > 0){
            uint256 counter = 0;
            for (uint256 i = 0; i < items.length; i++) {
                if (items[i].forSale == true) {
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
    ///@notice Cancel sale. Should not be called without checking if item is really for sale.
    function _cancelItemSale(Item storage item) private {
      //No need to overwrite item's price
      item.forSale = false;
      itemsForSaleCount--;
    }


    /*
     * Internal
     */
    /// @notice Transfer item
    function transferItem(address _from, address _to, uint256 _itemID) internal 
      ifItemForSaleThenCancelSale(_itemID) {
        Item storage item = items[_itemID];

        //take off      
        if(item.onChamp && _to != champToOwner[item.onChampId]){
          takeOffItem(item.onChampId, item.itemType);
        }

        addressInfo[_to].itemsCount++;
        addressInfo[_from].itemsCount--;
        itemToOwner[_itemID] = _to;

        emit TransferItem(_from, _to, _itemID);
    }



    /*
     * Public
     */
    /// @notice Calls transfer item
    /// @notice Address _from is msg.sender. Cannot be used is market, bc msg.sender is buyer
    function giveItem(address _to, uint256 _itemID) public 
      onlyOwnerOfItem(_itemID) {
        transferItem(msg.sender, _to, _itemID);
    }
    

    /// @notice Calcels item's sale
    function cancelItemSale(uint256 _id) public 
    itemIsForSale(_id) 
    onlyOwnerOfItem(_id){
      Item storage item = items[_id];
       _cancelItemSale(item);
    }


    /*
     * External
     */
    /// @notice Sets item for sale
    function setItemForSale(uint256 _id, uint256 _price) external 
      onlyOwnerOfItem(_id) 
      itemIsNotForSale(_id) {
        Item storage item = items[_id];
        item.forSale = true;
        item.price = _price;
        itemsForSaleCount++;
    }
    
    
    /// @notice Buys item
    function buyItem(uint256 _id) external payable 
      whenNotPaused 
      onlyNotOwnerOfItem(_id) 
      itemIsForSale(_id) 
      isPaid(items[_id].price) 
      distributeSaleInput(itemToOwner[_id]) 
      {
        transferItem(itemToOwner[_id], msg.sender, _id);
    }
    
}