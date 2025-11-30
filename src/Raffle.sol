// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions



//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


// @title A sample Raffle
// @author laitanop
// @notice This is a raffle contract
// @dev This is a raffle contract


contract Raffle {
    //errors 
    error Raffle__NotEnoughEthSent();

    uint256 private immutable I_ENTRANCE_FEE;
    address payable[] private sPlayers;

    //event 
    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee) {
        I_ENTRANCE_FEE = entranceFee;
    }
    // enter a raffle or buy a lotery ticket
   
     function enterRaffle() public payable{
       if(msg.value < I_ENTRANCE_FEE){
        revert Raffle__NotEnoughEthSent();
       }
       sPlayers.push(payable(msg.sender));
       emit RaffleEntered(msg.sender);
        
    }
    // the raffle owner picks a winner randomly
    function pickWinner() public {}

    //getter function 
    function getEntranceFee() external view returns (uint256){
        return I_ENTRANCE_FEE;
    }
  
}