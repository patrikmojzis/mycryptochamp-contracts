/* 
		© Copyright 2018 - Patrik Mojzis
		
		https://mycryptochamp.io/
		hello@mycryptochamp.io
*/

pragma solidity 0.4.24;

import "../Interfaces/ControllerInterface.sol";
import "../safemath.sol";

contract MyCryptoChampCore {

    using SafeMath for uint;

    struct Champ {
        uint id; //same as position in Champ[]
        uint attackPower;
        uint defencePower;
        uint cooldownTime; //how long does it take to be ready attack again
        uint readyTime; //if is smaller than block.timestamp champ is ready to fight
        uint winCount;
        uint lossCount;
        uint position; //subtract 1 and you get position in leaderboard[]
        uint price; //selling price
        uint withdrawCooldown; //if you one of the 800 best champs and withdrawCooldown is less as block.timestamp then you get ETH reward
        uint eq_sword; 
        uint eq_shield; 
        uint eq_helmet; 
        bool forSale; //is champ for sale?
    }
    
    struct AddressInfo {
        uint withdrawal;
        uint champsCount;
        uint itemsCount;
        string name;
    }

    //Item struct
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
    
    Champ[] public champs;
    Item[] public items;
    mapping (uint => uint) public leaderboard;
    mapping (address => bool) private trusted;
    mapping (address => AddressInfo) public addressInfo;
    mapping (bool => mapping(address => mapping (address => bool))) public tokenOperatorApprovals;
    mapping (bool => mapping(uint => address)) public tokenApprovals;
    mapping (bool => mapping(uint => address)) public tokenToOwner;
    mapping (uint => string) public champToName;
    mapping (bool => uint) public tokensForSaleCount;
    uint public pendingWithdrawal = 0;
    address private contractOwner;
    Controller internal controller;


    constructor () public 
    {
        trusted[msg.sender] = true;
        contractOwner = msg.sender;
        ///items.push(Item(0, 0, 0, 0, 0, 0, 0, 0, false, false)); //item -> nothing instead pushing to array in constructor we will create item by newItem f
    }
    

    /*============== MODIFIERS ==============*/
    modifier onlyTrusted(){
        require(trusted[msg.sender]);
        _;
    }

    /// @notice Checks if amount was sent
    modifier isPaid(uint _price)
    {
        require(msg.value >= _price);
        _;
    }

    /// @notice Checks if sender is owner of item
    modifier onlyNotOwnerOfItem(uint _itemId) {
        require(_itemId != 0);
        require(msg.sender != tokenToOwner[false][_itemId]);
        _;
    }

    ///@notice Checks if item is for sale
    modifier isItemForSale(uint _id){
        require(items[_id].forSale);
        _;
    }
    /// @dev Checks if msg.sender is NOT owner of champ
    modifier onlyNotOwnerOfChamp(uint _champId) 
    {
        require(msg.sender != tokenToOwner[true][_champId]);
        _;
    }

    ///@notice Require champ to be sale
    modifier isChampForSale(uint _id)
    {
        require(champs[_id].forSale);
        _;
    }


    /*============== CONTROL COTRACT ==============*/
    function loadController(address _address) external onlyTrusted {
        controller = Controller(_address);
    }

    
    function setTrusted(address _address, bool _trusted) external onlyTrusted {
        trusted[_address] = _trusted;
    }
    
    function transferOwnership(address newOwner) public onlyTrusted {
        require(newOwner != address(0));
        contractOwner = newOwner;
    }
    

    /*============== PRIVATE FUNCTIONS ==============*/
    function _addWithdrawal(address _address, uint _amount) private 
    {
        addressInfo[_address].withdrawal += _amount;
        pendingWithdrawal += _amount;
    }

    /// @notice Distribute input funds between contract owner and players
    function _distributeNewSaleInput(address _affiliateAddress) private 
    {
        //contract owner
        _addWithdrawal(contractOwner, ((msg.value / 100) * 60)); // 60%

        //affiliate
        //checks if _affiliateAddress is set & if affiliate address is not buying player
        if(_affiliateAddress != address(0) && _affiliateAddress != msg.sender){
            _addWithdrawal(_affiliateAddress, ((msg.value / 100) * 25)); //provision is 25%
            
        }
    }

    
    /*============== ONLY TRUSTED ==============*/
    function addWithdrawal(address _address, uint _amount) public onlyTrusted 
    {
        _addWithdrawal(_address, _amount);
    }

    function clearTokenApproval(address _from, uint _tokenId, bool _isTokenChamp) public onlyTrusted
    {
        require(tokenToOwner[_isTokenChamp][_tokenId] == _from);
        if (tokenApprovals[_isTokenChamp][_tokenId] != address(0)) {
            tokenApprovals[_isTokenChamp][_tokenId] = address(0);
        }
    }

    function emergencyWithdraw() external onlyTrusted
    {
        contractOwner.transfer(address(this).balance);
    }

    function setChampsName(uint _champId, string _name) public onlyTrusted 
    {
        champToName[_champId] = _name;
    }

    function setLeaderboard(uint _x, uint _value) public onlyTrusted
    {
        leaderboard[_x] = _value;
    }

    function setTokenApproval(uint _id, address _to, bool _isTokenChamp) public onlyTrusted
    {
        tokenApprovals[_isTokenChamp][_id] = _to;
    }

    function setTokenOperatorApprovals(address _from, address _to, bool _approved, bool _isTokenChamp) public onlyTrusted
    {
        tokenOperatorApprovals[_isTokenChamp][_from][_to] = _approved;
    }

    function setTokenToOwner(uint _id, address _owner, bool _isTokenChamp) public onlyTrusted
    {
        tokenToOwner[_isTokenChamp][_id] = _owner;
    }

    function setTokensForSaleCount(uint _value, bool _isTokenChamp) public onlyTrusted 
    {
        tokensForSaleCount[_isTokenChamp] = _value;
    }

    function transferToken(address _from, address _to, uint _id, bool _isTokenChamp) public onlyTrusted
    {
        controller.transferToken(_from, _to, _id, _isTokenChamp);
    }

    function updateAddressInfo(address _address, uint _withdrawal, bool _updatePendingWithdrawal, uint _champsCount, bool _updateChampsCount, uint _itemsCount, bool _updateItemsCount, string _name, bool _updateName) public onlyTrusted {
        AddressInfo storage ai = addressInfo[_address];
        if(_updatePendingWithdrawal){ ai.withdrawal = _withdrawal; }
        if(_updateChampsCount){ ai.champsCount = _champsCount; }
        if(_updateItemsCount){ ai.itemsCount = _itemsCount; }
        if(_updateName){ ai.name = _name; }
    }

    function newChamp(
        uint _attackPower,
        uint _defencePower,
        uint _cooldownTime,
        uint _winCount,
        uint _lossCount,
        uint _position,
        uint _price,
        uint _eq_sword, 
        uint _eq_shield, 
        uint _eq_helmet, 
        bool _forSale,
        address _owner
    ) public onlyTrusted returns (uint){

        Champ memory champ = Champ({
            id: 0,
            attackPower: 0, //CompilerError: Stack too deep, try removing local variables.
            defencePower: _defencePower,
            cooldownTime: _cooldownTime,
            readyTime: 0,
            winCount: _winCount,
            lossCount: _lossCount,
            position: _position,
            price: _price,
            withdrawCooldown: 0,
            eq_sword: _eq_sword,
            eq_shield: _eq_shield,
            eq_helmet: _eq_helmet,
            forSale: _forSale
        });
        champ.attackPower = _attackPower;

        uint id = champs.push(champ) - 1; 
        champs[id].id = id; //set id in Champ struct  
        leaderboard[_position] = id; //sets place in leaderboard  

        addressInfo[_owner].champsCount++;
        tokenToOwner[true][id] = _owner;

        if(_forSale){
            tokensForSaleCount[true]++;
        }

        return id;
    }

    function newItem(
        uint8 _itemType,
        uint8 _itemRarity,
        uint _attackPower,
        uint _defencePower,
        uint _cooldownReduction,
        uint _price,
        uint _onChampId,
        bool _onChamp,
        bool _forSale,
        address _owner
    ) public onlyTrusted returns (uint)
    { 
        //create that struct
        Item memory item = Item({
            id: 0,
            itemType: _itemType,
            itemRarity: _itemRarity, 
            attackPower: _attackPower,
            defencePower: _defencePower,
            cooldownReduction: _cooldownReduction,
            price: _price,
            onChampId: _onChampId,
            onChamp: _onChamp, 
            forSale: _forSale

        });

        uint id = items.push(item) - 1;
        items[id].id = id; //set id in Item struct  

        addressInfo[_owner].itemsCount++;
        tokenToOwner[false][id] = _owner;

        if(_forSale){
            tokensForSaleCount[false]++;
        }

        return id;
    }

    function updateChamp(
        uint _champId, 
        uint _attackPower,
        uint _defencePower,
        uint _cooldownTime,
        uint _readyTime,
        uint _winCount,
        uint _lossCount,
        uint _position,
        uint _price,
        uint _withdrawCooldown,
        uint _eq_sword, 
        uint _eq_shield, 
        uint _eq_helmet, 
        bool _forSale
    ) public onlyTrusted {
        Champ storage champ = champs[_champId];
        if(champ.attackPower != _attackPower){champ.attackPower = _attackPower;}
        if(champ.defencePower != _defencePower){champ.defencePower = _defencePower;}
        if(champ.cooldownTime != _cooldownTime){champ.cooldownTime = _cooldownTime;}
        if(champ.readyTime != _readyTime){champ.readyTime = _readyTime;}
        if(champ.winCount != _winCount){champ.winCount = _winCount;}
        if(champ.lossCount != _lossCount){champ.lossCount = _lossCount;}
        if(champ.position != _position){
            champ.position = _position;
            leaderboard[_position] = _champId;
        }
        if(champ.price != _price){champ.price = _price;}
        if(champ.withdrawCooldown != _withdrawCooldown){champ.withdrawCooldown = _withdrawCooldown;}
        if(champ.eq_sword != _eq_sword){champ.eq_sword = _eq_sword;}
        if(champ.eq_shield != _eq_shield){champ.eq_shield = _eq_shield;}
        if(champ.eq_helmet != _eq_helmet){champ.eq_helmet = _eq_helmet;}
        if(champ.forSale != _forSale){ 
            champ.forSale = _forSale; 
            if(_forSale){
                tokensForSaleCount[true]++;
            }else{
                tokensForSaleCount[true]--;
            }
        }
    }

    function updateItem(
        uint _id,
        uint8 _itemType,
        uint8 _itemRarity,
        uint _attackPower,
        uint _defencePower,
        uint _cooldownReduction,
        uint _price,
        uint _onChampId,
        bool _onChamp,
        bool _forSale
    ) public onlyTrusted
    {
        Item storage item = items[_id];
        if(item.itemType != _itemType){item.itemType = _itemType;}
        if(item.itemRarity != _itemRarity){item.itemRarity = _itemRarity;}
        if(item.attackPower != _attackPower){item.attackPower = _attackPower;}
        if(item.defencePower != _defencePower){item.defencePower = _defencePower;}
        if(item.cooldownReduction != _cooldownReduction){item.cooldownReduction = _cooldownReduction;}
        if(item.price != _price){item.price = _price;}
        if(item.onChampId != _onChampId){item.onChampId = _onChampId;}
        if(item.onChamp != _onChamp){item.onChamp = _onChamp;}
        if(item.forSale != _forSale){
            item.forSale = _forSale;
            if(_forSale){
                tokensForSaleCount[false]++;
            }else{
                tokensForSaleCount[false]--;
            }
        }
    }


    /*============== CALLABLE BY PLAYER ==============*/
    function buyItem(uint _id, address _affiliateAddress) external payable 
    onlyNotOwnerOfItem(_id) 
    isItemForSale(_id)
    isPaid(items[_id].price) 
    {
        if(tokenToOwner[false][_id] == address(this)){
            _distributeNewSaleInput(_affiliateAddress);
        }else{
            _addWithdrawal(tokenToOwner[false][_id], msg.value);
        }
        controller.transferToken(tokenToOwner[false][_id], msg.sender, _id, false);
    }

    function buyChamp(uint _id, address _affiliateAddress) external payable
    onlyNotOwnerOfChamp(_id) 
    isChampForSale(_id) 
    isPaid(champs[_id].price) 
    {
        if(tokenToOwner[true][_id] == address(this)){
            _distributeNewSaleInput(_affiliateAddress);
        }else{
            _addWithdrawal(tokenToOwner[true][_id], msg.value);
        }
        controller.transferToken(tokenToOwner[true][_id], msg.sender, _id, true);
    }

    /// @notice Change players's name
    function changePlayersName(string _name) external {
        addressInfo[msg.sender].name = _name;
    }

    /// @dev Send all pending funds of caller's address
    function withdrawToAddress(address _address) external 
    {
        address playerAddress = _address;
        if(playerAddress == address(0)){ playerAddress = msg.sender; }
        uint share = addressInfo[playerAddress].withdrawal; //gets pending funds
        require(share > 0); //is it more than 0?

        //first sets players withdrawal pending to 0 and subtract amount from playerWithdrawals then transfer funds to avoid reentrancy
        addressInfo[playerAddress].withdrawal = 0; //set player's withdrawal pendings to 0 
        pendingWithdrawal = pendingWithdrawal.sub(share); //subtract share from total pendings 
        
        playerAddress.transfer(share); //transfer
    }


    /*============== VIEW FUNCTIONS ==============*/
    function getChampsByOwner(address _owner) external view returns(uint256[]) {
        uint256[] memory result = new uint256[](addressInfo[_owner].champsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < champs.length; i++) {
            if (tokenToOwner[true][i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    function getTokensForSale(bool _isTokenChamp) view external returns(uint256[]){
        uint256[] memory result = new uint256[](tokensForSaleCount[_isTokenChamp]);
        if(tokensForSaleCount[_isTokenChamp] > 0){
            uint256 counter = 0;
            if(_isTokenChamp){
                for (uint256 i = 0; i < champs.length; i++) {
                    if (champs[i].forSale == true) {
                        result[counter]=i;
                        counter++;
                    }
                }
            }else{
                for (uint256 n = 0; n < items.length; n++) {
                    if (items[n].forSale == true) {
                        result[counter]=n;
                        counter++;
                    }
                }
            }
        }
        return result;
    }

    /// @notice Gets champ's attack power, defence power and cooldown reduction with items on
    function getChampStats(uint256 _champId) public view returns(uint256,uint256,uint256){
        Champ storage champ = champs[_champId];
        Item storage sword = items[champ.eq_sword];
        Item storage shield = items[champ.eq_shield];
        Item storage helmet = items[champ.eq_helmet];

        uint totalAttackPower = champ.attackPower + sword.attackPower + shield.attackPower + helmet.attackPower; //Gets champs AP
        uint totalDefencePower = champ.defencePower + sword.defencePower + shield.defencePower + helmet.defencePower; //Gets champs  DP
        uint totalCooldownReduction = sword.cooldownReduction + shield.cooldownReduction + helmet.cooldownReduction; //Gets  CR

        return (totalAttackPower, totalDefencePower, totalCooldownReduction);
    }

    function getItemsByOwner(address _owner) external view returns(uint256[]) {
        uint256[] memory result = new uint256[](addressInfo[_owner].itemsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < items.length; i++) {
            if (tokenToOwner[false][i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }

    /// @notice Gets total champs count
    function getTokenCount(bool _isTokenChamp) external view returns(uint)
    {
        if(_isTokenChamp){
            return champs.length - addressInfo[address(0)].champsCount;
        }else{
            return items.length - 1 - addressInfo[address(0)].itemsCount;
        }
    }
    
    function getTokenURIs(uint _tokenId, bool _isTokenChamp) public view returns(string)
    {
        return controller.getTokenURIs(_tokenId,_isTokenChamp);
    }

    function onlyApprovedOrOwnerOfToken(uint _id, address _msgsender, bool _isTokenChamp) external view returns(bool)
    {
        if(!_isTokenChamp){
            require(_id != 0);
        }
        address owner = tokenToOwner[_isTokenChamp][_id];
        return(_msgsender == owner || _msgsender == tokenApprovals[_isTokenChamp][_id] || tokenOperatorApprovals[_isTokenChamp][owner][_msgsender]);
    }


    /*============== DELEGATE ==============*/
    function attack(uint _champId, uint _targetId) external{
        controller.attack(_champId, _targetId, msg.sender);
    }

    function cancelTokenSale(uint _id, bool _isTokenChamp) public{
        controller.cancelTokenSale(_id, msg.sender, _isTokenChamp);
    }

    function changeChampsName(uint _champId, string _name) external{
        controller.changeChampsName(_champId, _name, msg.sender);
    }

    function forgeItems(uint _parentItemID, uint _childItemID) external{
        controller.forgeItems(_parentItemID, _childItemID, msg.sender);
    }

    function giveToken(address _to, uint _champId, bool _isTokenChamp) external{
        controller.giveToken(_to, _champId, msg.sender, _isTokenChamp);
    }

    function setTokenForSale(uint _id, uint _price, bool _isTokenChamp) external{
        controller.setTokenForSale(_id, _price, msg.sender, _isTokenChamp);
    }

    function putOn(uint _champId, uint _itemId) external{
        controller.putOn(_champId, _itemId, msg.sender);
    }

    function takeOffItem(uint _champId, uint8 _type) public{
        controller.takeOffItem(_champId, _type, msg.sender);
    }

    function withdrawChamp(uint _id) external{
        controller.withdrawChamp(_id, msg.sender); 
    }

    function getChampReward(uint _position) public view returns(uint){
        return controller.getChampReward(_position);
    }
}