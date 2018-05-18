pragma solidity 0.4.23;

import "./safemath.sol";
import "./itemforge.sol";

/// @title Manages attacks in game
/// @author Patrik Mojzis
contract ChampAttack is ItemForge {
    
    event Attack(uint256 winnerChampID, uint256 defeatedChampID, bool didAttackerWin);

    /*
     * Modifiers
     */
     /// @notice Is champ ready to fight again?
    modifier isChampReady(uint256 _champId) {
      require (champs[_champId].readyTime <= block.timestamp);
      _;
    }


    /// @notice Prevents from self-attack
    modifier notSelfAttack(uint256 _champId, uint256 _targetId) {
        require(_champId != _targetId); 
        _;
    }


    /// @notice Checks if champ does exist
    modifier targetExists(uint256 _targetId){
        require(champToOwner[_targetId] != address(0)); 
        _;
    }


    /*
     * View
     */
    /// @notice Gets champ's attack power, defence power and cooldown reduction with items on
    function getChampStats(uint256 _champId) public view returns(uint256,uint256,uint256){
        Champ storage champ = champs[_champId];
        Item storage sword = items[champ.eq_sword];
        Item storage shield = items[champ.eq_shield];
        Item storage helmet = items[champ.eq_helmet];

        //AP
        uint256 totalAttackPower = champ.attackPower + sword.attackPower + shield.attackPower + helmet.attackPower; //Gets champs AP

        //DP
        uint256 totalDefencePower = champ.defencePower + sword.defencePower + shield.defencePower + helmet.defencePower; //Gets champs  DP

        //CR
        uint256 totalCooldownReduction = sword.cooldownReduction + shield.cooldownReduction + helmet.cooldownReduction; //Gets  CR

        return (totalAttackPower, totalDefencePower, totalCooldownReduction);
    }


    /*
     * Pure
     */
    /// @notice Subtracts ability points. Helps to not cross minimal attack ability points -> 2
    /// @param _playerAttackPoints Actual player's attack points
    /// @param _x Amount to subtract 
    function subAttack(uint256 _playerAttackPoints, uint256 _x) internal pure returns (uint256) {
        return (_playerAttackPoints <= _x + 2) ? 2 : _playerAttackPoints - _x;
    }
    

    /// @notice Subtracts ability points. Helps to not cross minimal defence ability points -> 1
    /// @param _playerDefencePoints Actual player's defence points
    /// @param _x Amount to subtract 
    function subDefence(uint256 _playerDefencePoints, uint256 _x) internal pure returns (uint256) {
        return (_playerDefencePoints <= _x) ? 1 : _playerDefencePoints - _x;
    }
    

    /*
     * Private
     */
    /// @dev Is called from from Attack function after the winner is already chosen
    /// @dev Updates abilities, champ's stats and swaps positions
    function _attackCompleted(Champ storage _winnerChamp, Champ storage _defeatedChamp, uint256 _pointsGiven, uint256 _pointsToAttackPower) private {
        /*
         * Updates abilities after fight
         */
        //winner abilities update
        _winnerChamp.attackPower += _pointsToAttackPower; //increase attack power
        _winnerChamp.defencePower += _pointsGiven - _pointsToAttackPower; //max point that was given - already given to AP
                
        //defeated champ's abilities update
        //checks for not cross minimal AP & DP points
        _defeatedChamp.attackPower = subAttack(_defeatedChamp.attackPower, _pointsToAttackPower); //decrease attack power
        _defeatedChamp.defencePower = subDefence(_defeatedChamp.defencePower, _pointsGiven - _pointsToAttackPower); // decrease defence power



        /*
         * Update champs' wins and losses
         */
        _winnerChamp.winCount++;
        _defeatedChamp.lossCount++;
            


        /*
         * Swap positions
         */
        if(_winnerChamp.position > _defeatedChamp.position) { //require loser to has better (lower) postion than attacker
            uint256 winnerPosition = _winnerChamp.position;
            uint256 loserPosition = _defeatedChamp.position;
        
            _defeatedChamp.position = winnerPosition;
            _winnerChamp.position = loserPosition;
        
            //position in champ struct is always one point bigger than in leaderboard array
            leaderboard[winnerPosition - 1] = _defeatedChamp.id;
            leaderboard[loserPosition - 1] = _winnerChamp.id;
        }
    }
    
    
    /// @dev Gets pointsGiven and pointsToAttackPower
    function _getPoints(uint256 _pointsGiven) private returns (uint256 pointsGiven, uint256 pointsToAttackPower){
        return (_pointsGiven, randMod(_pointsGiven+1));
    }



    /*
     * External
     */
    /// @notice Attack function
    /// @param _champId Attacker champ
    /// @param _targetId Target champ
    function attack(uint256 _champId, uint256 _targetId) external 
    onlyOwnerOfChamp(_champId) 
    isChampReady(_champId) 
    notSelfAttack(_champId, _targetId) 
    targetExists(_targetId) {
        Champ storage myChamp = champs[_champId]; 
        Champ storage enemyChamp = champs[_targetId]; 
        uint256 pointsGiven; //total points that will be divided between AP and DP
        uint256 pointsToAttackPower; //part of points that will be added to attack power, the rest of points go to defence power
        uint256 myChampAttackPower;  
        uint256 enemyChampDefencePower; 
        uint256 myChampCooldownReduction;
        
        (myChampAttackPower,,myChampCooldownReduction) = getChampStats(_champId);
        (,enemyChampDefencePower,) = getChampStats(_targetId);


        //if attacker's AP is more than target's DP then attacker wins
        if (myChampAttackPower > enemyChampDefencePower) {
            
            //this should demotivate players from farming on way weaker champs than they are
            //the bigger difference between AP & DP is, the reward is smaller
            if(myChampAttackPower - enemyChampDefencePower < 5){
                
                //big experience - 3 ability points
                (pointsGiven, pointsToAttackPower) = _getPoints(3);
                
                
            }else if(myChampAttackPower - enemyChampDefencePower < 10){
                
                //medium experience - 2 ability points
                (pointsGiven, pointsToAttackPower) = _getPoints(2);
                
            }else{
                
                //small experience - 1 ability point to random ability (attack power or defence power)
                (pointsGiven, pointsToAttackPower) = _getPoints(1);
                
            }
            
            _attackCompleted(myChamp, enemyChamp, pointsGiven, pointsToAttackPower);

            emit Attack(myChamp.id, enemyChamp.id, true);

        } else {
            
            //1 ability point to random ability (attack power or defence power)
            (pointsGiven, pointsToAttackPower) = _getPoints(1);

            _attackCompleted(enemyChamp, myChamp, pointsGiven, pointsToAttackPower);

            emit Attack(enemyChamp.id, myChamp.id, false);
             
        }
        
        //Trigger cooldown for attacker
        myChamp.readyTime = uint256(block.timestamp + myChamp.cooldownTime - myChampCooldownReduction);

    }
    
}