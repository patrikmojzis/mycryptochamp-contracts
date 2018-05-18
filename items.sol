pragma solidity 0.4.23;

import "./champfactory.sol";

/// @title  Moderates items and creates new ones
/// @author Patrik Mojzis
contract Items is ChampFactory {

    event NewItem(uint256 itemID, address owner);

    constructor () internal {
        //item -> nothing
        items.push(Item(0, 0, 0, 0, 0, 0, 0, false, false));
    }

    /*
     * Modifiers
     */
    /// @notice Checks if sender is owner of item
    modifier onlyOwnerOfItem(uint256 _itemId) {
        require(_itemId != 0);
        require(msg.sender == itemToOwner[_itemId]);
        _;
    }
    

    /// @notice Checks if sender is NOT owner of item
    modifier onlyNotOwnerOfItem(uint256 _itemId) {
        require(msg.sender != itemToOwner[_itemId]);
        _;
    }


    /*
     * View
     */
    ///@notice Check if champ has something on
    ///@param _type Sword, shield or helmet
    function hasChampSomethingOn(uint _champId, uint8 _type) internal view returns(bool){
        Champ storage champ = champs[_champId];
        if(_type == 1){
            return (champ.eq_sword == 0) ? false : true;
        }
        if(_type == 2){
            return (champ.eq_shield == 0) ? false : true;
        }
        if(_type == 3){
            return (champ.eq_helmet == 0) ? false : true;
        }
    }


    /// @notice Gets items by address
    /// @param _owner Owner address
    function getItemsByOwner(address _owner) external view returns(uint256[]) {
        uint256[] memory result = new uint256[](addressInfo[_owner].itemsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (itemToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }


    /*
     * Public
     */
    ///@notice Takes item off champ
    function takeOffItem(uint _champId, uint8 _type) public 
        onlyOwnerOfChamp(_champId) {
            uint256 itemId;
            Champ storage champ = champs[_champId];
            if(_type == 1){
                itemId = champ.eq_sword; //Get item ID
                if (itemId > 0) { //0 = nothing
                    champ.eq_sword = 0; //take off sword
                }
            }
            if(_type == 2){
                itemId = champ.eq_shield; //Get item ID
                if(itemId > 0) {//0 = nothing
                    champ.eq_shield = 0; //take off shield
                }
            }
            if(_type == 3){
                itemId = champ.eq_helmet; //Get item ID
                if(itemId > 0) { //0 = nothing
                    champ.eq_helmet = 0; //take off 
                }
            }
            if(itemId > 0){
                items[itemId].onChamp = false; //item is free to use, is not on champ
            }
    }



    /*
     * External
     */
    ///@notice Puts item on champ
    function putOn(uint256 _champId, uint256 _itemId) external 
        onlyOwnerOfChamp(_champId) 
        onlyOwnerOfItem(_itemId) {
            Champ storage champ = champs[_champId];
            Item storage item = items[_itemId];

            //checks if items is on some other champ
            if(item.onChamp){
                takeOffItem(item.onChampId, item.itemType); //take off from champ
            }

            item.onChamp = true; //item is on champ
            item.onChampId = _champId; //champ's id

            //put on
            if(item.itemType == 1){
                //take off actual sword 
                if(champ.eq_sword > 0){
                    takeOffItem(champ.id, 1);
                }
                champ.eq_sword = _itemId; //put on sword
            }
            if(item.itemType == 2){
                //take off actual shield 
                if(champ.eq_shield > 0){
                    takeOffItem(champ.id, 2);
                }
                champ.eq_shield = _itemId; //put on shield
            }
            if(item.itemType == 3){
                //take off actual helmet 
                if(champ.eq_helmet > 0){
                    takeOffItem(champ.id, 3);
                }
                champ.eq_helmet = _itemId; //put on helmet
            }
    }



    /// @notice Opens loot box and generates new item
    function openLootbox(address _affiliateAddress) external payable 
    whenNotPaused
    isPaid(lootboxFee) 
    distributeInput(_affiliateAddress) {

        uint256 pointToCooldownReduction;
        uint256 randNum = randMod(1001); //random number <= 1000
        uint256 pointsToShare; //total points given
        uint256 itemID;

        //sets up item
        Item memory item = Item({
            itemType: uint8(uint256(randMod(3) + 1)), //generates item type - max num is 2 -> 0 + 1 SWORD | 1 + 1 SHIELD | 2 + 1 HELMET;
            itemRarity: uint8(0),
            attackPower: 0,
            defencePower: 0,
            cooldownReduction: 0,
            price: 0,
            onChampId: 0,
            onChamp: false,
            forSale: false
        });
        
        // Gets Rarity of item
        // 45% common
        // 27% uncommon
        // 19% rare
        // 7%  epic
        // 2%  legendary
        if(450 > randNum){
            pointsToShare = 25 + randMod(9); //25 basic + random number max to 8
            item.itemRarity = uint8(1);
        }else if(720 > randNum){
            pointsToShare = 42 + randMod(17); //42 basic + random number max to 16
            item.itemRarity = uint8(2);
        }else if(910 > randNum){
            pointsToShare = 71 + randMod(25); //71 basic + random number max to 24
            item.itemRarity = uint8(3);
        }else if(980 > randNum){
            pointsToShare = 119 + randMod(33); //119 basic + random number max to 32
            item.itemRarity = uint8(4);
        }else{
            pointsToShare = 235 + randMod(41); //235 basic + random number max to 40
            item.itemRarity = uint8(5);
        }
        

        //Gets type of item
        if(item.itemType == uint8(1)){ //ITEM IS SWORDS
            item.attackPower = pointsToShare / 10 * 7; //70% attackPower
            pointsToShare -= item.attackPower; //points left;
                
            item.defencePower = pointsToShare / 10 * randMod(6); //up to 15% defencePower
            pointsToShare -= item.defencePower; //points left;
                
            item.cooldownReduction = pointsToShare * uint256(1 minutes); //rest of points is cooldown reduction
            item.itemType = uint8(1);
        }
        
        if(item.itemType == uint8(2)){ //ITEM IS SHIELD
            item.defencePower = pointsToShare / 10 * 7; //70% defencePower
            pointsToShare -= item.defencePower; //points left;
                
            item.attackPower = pointsToShare / 10 * randMod(6); //up to 15% attackPowerPower
            pointsToShare -= item.attackPower; //points left;
                
            item.cooldownReduction = pointsToShare * uint256(1 minutes); //rest of points is cooldown reduction
            item.itemType = uint8(2);
        }
        
        if(item.itemType == uint8(3)){ //ITEM IS HELMET
            pointToCooldownReduction = pointsToShare / 10 * 7; //70% cooldown reduction
            item.cooldownReduction = pointToCooldownReduction * uint256(1 minutes); //points to time
            pointsToShare -= pointToCooldownReduction; //points left;
                
            item.attackPower = pointsToShare / 10 * randMod(6); //up to 15% attackPower
            pointsToShare -= item.attackPower; //points left;
                
            item.defencePower = pointsToShare; //rest of points is defencePower
            item.itemType = uint8(3);
        }

        itemID = items.push(item) - 1;
        
        itemToOwner[itemID] = msg.sender; //sets owner of this item - msg.sender
        addressInfo[msg.sender].itemsCount++; //every address has count of items    

        emit NewItem(itemID, msg.sender);    

    }

    /// @notice Change "lootboxFee". 
    /// @param _fee New "lootboxFee"
    /// @dev Only owner of contract can change "lootboxFee"
    function setLootboxFee(uint _fee) external onlyOwner {
        lootboxFee = _fee;
    }
}