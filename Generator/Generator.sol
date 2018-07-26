pragma solidity 0.4.24;

import "../inherit.sol";

contract Generator is Inherit{

	uint private randNonce = 1;
	
	struct Champ {
        uint id; //same as position in Champ[]
        uint attackPower;
        uint defencePower;
        uint cooldownTime; //how long does it take to be ready attack again
        uint readyTime; //if is smaller than block.timestamp champ is ready to fight
        uint winCount;
        uint lossCount;
        uint position; //position in leaderboard. subtract 1 and you got position in leaderboard[]
        uint price; //selling price
        uint withdrawCooldown; //if you one of the 800 best champs and withdrawCooldown is less as block.timestamp then you get ETH reward
        uint eq_sword; 
        uint eq_shield; 
        uint eq_helmet; 
        bool forSale; //is champ for sale?
    }

    struct Item {
        uint id;
        uint8 itemType; // 1 - Sword | 2 - Shield | 3 - Helmet
        uint8 itemRarity; // 1 - Common | 2 - Uncommon | 3 - Rare | 4 - Epic | 5 - Legendery | 6 - Forged
        uint attackPower;
        uint defencePower;
        uint cooldownReduction;
        uint price;
        uint onChampId; //can not be used to decide if item is on champ, because champ's id can be 0, 'bool onChamp' solves it.
        bool onChamp; 
        bool forSale; //is item for sale?
    }

	function createNewItem() external 
    onlyOwner 
    {
        uint pointToCooldownReduction;
        uint itemsCount = core.getTokenCount(false);
        uint randNum = randMod(1001); //pseudorandom number
        uint pointsToShare; //total points given

        //sets up item
        Item memory item = Item({
            id: 0, //does not matter right now
            itemType: uint8(uint(itemsCount%3 + 1)), //generates item type - max num is 2 -> 0 + 1 SWORD | 1 + 1 SHIELD | 2 + 1 HELMET;
            itemRarity: uint8(0),
            attackPower: 0,
            defencePower: 0,
            cooldownReduction: 0,
            price: 0,
            onChampId: 0,
            onChamp: false,
            forSale: true
        });
        
        // Gets Rarity of item
        // 45% common
        // 27% uncommon
        // 19% rare
        // 7%  epic
        // 2%  legendary
        if(450 > randNum){
            pointsToShare = 25 + randNum%9; //25 basic + random number max to 8
            item.itemRarity = uint8(1);
            item.price = 5 finney + itemsCount * 7 szabo;
        }else if(720 > randNum){
            pointsToShare = 42 + randNum%17; //42 basic + random number max to 16
            item.itemRarity = uint8(2);
            item.price = 10 finney + itemsCount * 8 szabo;
        }else if(910 > randNum){
            pointsToShare = 71 + randNum%25; //71 basic + random number max to 24
            item.itemRarity = uint8(3);
            item.price = 50 finney + itemsCount * 10 szabo;
        }else if(980 > randNum){
            pointsToShare = 119 + randNum%33; //119 basic + random number max to 32
            item.itemRarity = uint8(4);
            item.price = 100 finney + itemsCount * 11 szabo;
        }else{
            pointsToShare = 235 + randNum%41; //235 basic + random number max to 40
            item.itemRarity = uint8(5);
            item.price = 250 finney + itemsCount * 12 szabo;
        }
        

        //Gets type of item
        if(item.itemType == uint8(1)){ //ITEM IS SWORDS
            item.attackPower = pointsToShare / 10 * 7; //70% attackPower
            pointsToShare -= item.attackPower; //points left;
                
            item.defencePower = pointsToShare / 10 * (randNum%6); //up to 15% defencePower
            pointsToShare -= item.defencePower; //points left;
                
            item.cooldownReduction = pointsToShare * uint(1 minutes); //rest of points is cooldown reduction
            item.itemType = uint8(1);
        }
        
        if(item.itemType == uint8(2)){ //ITEM IS SHIELD
            item.defencePower = pointsToShare / 10 * 7; //70% defencePower
            pointsToShare -= item.defencePower; //points left;
                
            item.attackPower = pointsToShare / 10 * (randNum%6); //up to 15% attackPowerPower
            pointsToShare -= item.attackPower; //points left;
                
            item.cooldownReduction = pointsToShare * uint(1 minutes); //rest of points is cooldown reduction
            item.itemType = uint8(2);
        }
        
        if(item.itemType == uint8(3)){ //ITEM IS HELMET
            pointToCooldownReduction = pointsToShare / 10 * 7; //70% cooldown reduction
            item.cooldownReduction = pointToCooldownReduction * uint(1 minutes); //points to time
            pointsToShare -= pointToCooldownReduction; //points left;
                
            item.attackPower = pointsToShare / 10 * (randNum%6); //up to 15% attackPower
            pointsToShare -= item.attackPower; //points left;
                
            item.defencePower = pointsToShare; //rest of points is defencePower
            item.itemType = uint8(3);
        }

        core.newItem(item.itemType, item.itemRarity, item.attackPower, item.defencePower, item.cooldownReduction, item.price, item.onChampId, item.onChamp, item.forSale, coreAddress);
        
        /*
        //Sets owner
        (,,uint addressItemsCount,) = core.addressInfo(coreAddress); //Gets core address items count
        core.updateAddressInfo(coreAddress,0,false,0,false,addressItemsCount + 1,true,"",false); //Updates core address info
        core.setTokenToOwner(id, coreAddress,false); //Sets token to owner

        //Update sale stats
        uint newItemsForSaleCount = core.itemsForSaleCount() + 1; //Gets Items for sale count and add this one
        core.setTokensForSaleCount(newItemsForSaleCount, false); //Updates at the core
        */
    }


    /// @notice Creates a new champ
    function createNewChamp() external 
    onlyOwner 
    {
        uint champsCount = core.getTokenCount(true); //used in a generating new champ
        uint price = 5 finney + (champsCount%9) * 100 szabo;
        core.newChamp(2 + champsCount%4, 1 + champsCount%4, uint(1 days)  - uint((champsCount%9) * 1 hours), 0, 0, champsCount + 1, price, 0,0,0, true, coreAddress); 
        
        /*
        //Sets owner
        (,uint addressChampsCount,,) = core.addressInfo(coreAddress); //Gets core address champs count
        core.updateAddressInfo(coreAddress,0,false,addressChampsCount + 1,true,0,false,"",false); //Updates core address info
        core.setTokenToOwner(id, coreAddress,true); //Sets token to owner

        //Update sale stats
        uint champsForSaleCount = core.champsForSaleCount() + 1;
        core.setTokensForSaleCount(champsForSaleCount, true);
        */
    }


    /// @notice Generates pseudo random modulus
    function randMod(uint _modulus) internal returns(uint) {
        randNonce++;
        return uint(block.number + randNonce) % _modulus;
    }
}