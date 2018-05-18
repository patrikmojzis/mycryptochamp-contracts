pragma solidity 0.4.23;

import "./itemmarket.sol";

/// @title Manages forging
/// @author Patrik Mojzis
contract ItemForge is ItemMarket {

	event Forge(uint256 forgedItemID);

	///@notice Forge items together
	function forgeItems(uint256 _parentItemID, uint256 _childItemID) external 
	onlyOwnerOfItem(_parentItemID) 
	onlyOwnerOfItem(_childItemID) 
	ifItemForSaleThenCancelSale(_parentItemID) 
	ifItemForSaleThenCancelSale(_childItemID) {

		//checks if items are not the same
        require(_parentItemID != _childItemID);
        
		Item storage parentItem = items[_parentItemID];
		Item storage childItem = items[_childItemID];

		//take child item off, because child item will be burned
		if(childItem.onChamp){
			takeOffItem(childItem.onChampId, childItem.itemType);
		}

		//update parent item
		parentItem.attackPower = (parentItem.attackPower > childItem.attackPower) ? parentItem.attackPower : childItem.attackPower;
		parentItem.defencePower = (parentItem.defencePower > childItem.defencePower) ? parentItem.defencePower : childItem.defencePower;
		parentItem.cooldownReduction = (parentItem.cooldownReduction > childItem.cooldownReduction) ? parentItem.cooldownReduction : childItem.cooldownReduction;
		parentItem.itemRarity = uint8(6);

		//burn child item
		transferItem(msg.sender, address(0), _childItemID);

		emit Forge(_parentItemID);
	}

}