pragma solidity 0.4.23;

import "./safemath.sol";
import "./pausable.sol";


/// @title A contract for creating new champs and making withdrawals
/// @author Patrik Mojzis
contract ChampFactory is Pausable{

    event NewChamp(uint256 champID, address owner);

    using SafeMath for uint; //SafeMath for overflow prevention

    /*
     * Variables
     */
    struct Champ {
        uint256 id; //same as position in Champ[]
        uint256 attackPower;
        uint256 defencePower;
        uint256 cooldownTime; //how long does it take to be ready attack again
        uint256 readyTime; //if is smaller than block.timestamp champ is ready to fight
        uint256 winCount;
        uint256 lossCount;
        uint256 position; //position in leaderboard. subtract 1 and you got position in leaderboard[]
        uint256 price; //selling price
        uint256 withdrawCooldown; //if you one of the 800 best champs and withdrawCooldown is less as block.timestamp then you get ETH reward
        uint256 eq_sword; 
        uint256 eq_shield; 
        uint256 eq_helmet; 
        bool forSale; //is champ for sale?
    }
    
    struct AddressInfo {
        uint256 withdrawal;
        uint256 champsCount;
        uint256 itemsCount;
        string name;
    }

    //Item struct
    struct Item {
        uint8 itemType; // 1 - Sword | 2 - Shield | 3 - Helmet
        uint8 itemRarity; // 1 - Common | 2 - Uncommon | 3 - Rare | 4 - Epic | 5 - Legendery | 6 - Forged
        uint256 attackPower;
        uint256 defencePower;
        uint256 cooldownReduction;
        uint256 price;
        uint256 onChampId; //can not be used to decide if item is on champ, because champ's id can be 0, 'bool onChamp' solves it.
        bool onChamp; 
        bool forSale; //is item for sale?
    }
    
    mapping (address => AddressInfo) public addressInfo;
    mapping (uint256 => address) public champToOwner;
    mapping (uint256 => address) public itemToOwner;
    mapping (uint256 => string) public champToName;
    
    Champ[] public champs;
    Item[] public items;
    uint256[] public leaderboard;
    
    uint256 internal createChampFee = 5 finney;
    uint256 internal lootboxFee = 5 finney;
    uint256 internal pendingWithdrawal = 0;
    uint256 private randNonce = 0; //being used in generating random numbers
    uint256 public champsForSaleCount;
    uint256 public itemsForSaleCount;
    

    /*
     * Modifiers
     */
    /// @dev Checks if msg.sender is owner of champ
    modifier onlyOwnerOfChamp(uint256 _champId) {
        require(msg.sender == champToOwner[_champId]);
        _;
    }
    

    /// @dev Checks if msg.sender is NOT owner of champ
    modifier onlyNotOwnerOfChamp(uint256 _champId) {
        require(msg.sender != champToOwner[_champId]);
        _;
    }
    

    /// @notice Checks if amount was sent
    modifier isPaid(uint256 _price){
        require(msg.value >= _price);
        _;
    }


    /// @notice People are allowed to withdraw only if min. balance (0.01 gwei) is reached
    modifier contractMinBalanceReached(){
        require( (address(this).balance).sub(pendingWithdrawal) > 1000000 );
        _;
    }


    /// @notice Checks if withdraw cooldown passed 
    modifier isChampWithdrawReady(uint256 _id){
        require(champs[_id].withdrawCooldown < block.timestamp);
        _;
    }


    /// @notice Distribute input funds between contract owner and players
    modifier distributeInput(address _affiliateAddress){

        //contract owner
        uint256 contractOwnerWithdrawal = (msg.value / 100) * 50; // 50%
        addressInfo[contractOwner].withdrawal += contractOwnerWithdrawal;
        pendingWithdrawal += contractOwnerWithdrawal;

        //affiliate
        //checks if _affiliateAddress is set & if affiliate address is not buying player
        if(_affiliateAddress != address(0) && _affiliateAddress != msg.sender){
            uint256 affiliateBonus = (msg.value / 100) * 25; //provision is 25%
            addressInfo[_affiliateAddress].withdrawal += affiliateBonus;
            pendingWithdrawal += affiliateBonus;
        }

        _;
    }



    /*
     * View
     */
    /// @notice Gets champs by address
    /// @param _owner Owner address
    function getChampsByOwner(address _owner) external view returns(uint256[]) {
        uint256[] memory result = new uint256[](addressInfo[_owner].champsCount);
        uint256 counter = 0;
        for (uint256 i = 0; i < champs.length; i++) {
            if (champToOwner[i] == _owner) {
                result[counter] = i;
                counter++;
            }
        }
        return result;
    }


    /// @notice Gets total champs count
    function getChampsCount() external view returns(uint256){
        return champs.length;
    }
    

    /// @notice Gets champ's reward in wei
    function getChampReward(uint256 _position) public view returns(uint256) {
        if(_position <= 800){
            //percentageMultipier = 10,000
            //maxReward = 2000 = .2% * percentageMultipier
            //subtractPerPosition = 2 = .0002% * percentageMultipier
            //2000 - (2 * (_position - 1))
            uint256 rewardPercentage = uint256(2000).sub(2 * (_position - 1));

            //available funds are all funds - already pending
            uint256 availableWithdrawal = address(this).balance.sub(pendingWithdrawal);

            //calculate reward for champ's position
            //1000000 = percentageMultipier * 100
            return availableWithdrawal / 1000000 * rewardPercentage;
        }else{
            return uint256(0);
        }
    }


    /*
     * Internal
     */
    /// @notice Generates random modulus
    /// @param _modulus Max random modulus
    function randMod(uint256 _modulus) internal returns(uint256) {
        randNonce++;
        return uint256(keccak256(randNonce, blockhash(block.number - 1))) % _modulus;
    }
    


    /*
     * External
     */
    /// @notice Creates new champ
    /// @param _affiliateAddress Affiliate address (optional)
    function createChamp(address _affiliateAddress) external payable 
    whenNotPaused
    isPaid(createChampFee) 
    distributeInput(_affiliateAddress) 
    {

        /* 
        Champ memory champ = Champ({
             id: 0,
             attackPower: 2 + randMod(4),
             defencePower: 1 + randMod(4),
             cooldownTime: uint256(1 days) - uint256(randMod(9) * 1 hours),
             readyTime: 0,
             winCount: 0,
             lossCount: 0,
             position: leaderboard.length + 1, //Last place in leaderboard is new champ's position. Used in new champ struct bellow. +1 to avoid zero position.
             price: 0,
             withdrawCooldown: uint256(block.timestamp), 
             eq_sword: 0,
             eq_shield: 0, 
             eq_helmet: 0, 
             forSale: false 
        });   
        */

        // This line bellow is about 30k gas cheaper than lines above. They are the same. Lines above are just more readable.
        uint256 id = champs.push(Champ(0, 2 + randMod(4), 1 + randMod(4), uint256(1 days)  - uint256(randMod(9) * 1 hours), 0, 0, 0, leaderboard.length + 1, 0, uint256(block.timestamp), 0,0,0, false)) - 1;     
        
        
        champs[id].id = id; //sets id in Champ struct  
        leaderboard.push(id); //push champ on the last place in leaderboard  
        champToOwner[id] = msg.sender; //sets owner of this champ - msg.sender
        addressInfo[msg.sender].champsCount++;

        emit NewChamp(id, msg.sender);

    }


    /// @notice Change "CreateChampFee". If ETH price will grow up it can expensive to create new champ.
    /// @param _fee New "CreateChampFee"
    /// @dev Only owner of contract can change "CreateChampFee"
    function setCreateChampFee(uint256 _fee) external onlyOwner {
        createChampFee = _fee;
    }
    

    /// @notice Change champ's name
    function changeChampsName(uint _champId, string _name) external 
    onlyOwnerOfChamp(_champId){
        champToName[_champId] = _name;
    }


    /// @notice Change players's name
    function changePlayersName(string _name) external {
        addressInfo[msg.sender].name = _name;
    }


    /// @notice Withdraw champ's reward
    /// @param _id Champ id
    /// @dev Move champ reward to pending withdrawal to his wallet. 
    function withdrawChamp(uint _id) external 
    onlyOwnerOfChamp(_id) 
    contractMinBalanceReached  
    isChampWithdrawReady(_id) 
    whenNotPaused {
        Champ storage champ = champs[_id];
        require(champ.position <= 800);

        champ.withdrawCooldown = block.timestamp + 1 days; //one withdrawal 1 per day

        uint256 withdrawal = getChampReward(champ.position);
        addressInfo[msg.sender].withdrawal += withdrawal;
        pendingWithdrawal += withdrawal;
    }
    

    /// @dev Send all pending funds of caller's address
    function withdrawToAddress(address _address) external 
    whenNotPaused {
        address playerAddress = _address;
        if(playerAddress == address(0)){ playerAddress = msg.sender; }
        uint256 share = addressInfo[playerAddress].withdrawal; //gets pending funds
        require(share > 0); //is it more than 0?

        //first sets players withdrawal pending to 0 and subtract amount from playerWithdrawals then transfer funds to avoid reentrancy
        addressInfo[playerAddress].withdrawal = 0; //set player's withdrawal pendings to 0 
        pendingWithdrawal = pendingWithdrawal.sub(share); //subtract share from total pendings 
        
        playerAddress.transfer(share); //transfer
    }
    
}