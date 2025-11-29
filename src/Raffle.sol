//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


//@title A sample Raffle
// @author laitanop
// @notice This is a raffle contract
// @dev This is a raffle contract


contract Raffle {
    uint256 public immutable I_ENTRANCE_FEE;

    constructor(uint256 entranceFee) {
        I_ENTRANCE_FEE = entranceFee;
    }
    // enter a raffle or buy a lotery ticket
    function enterRaffle() public payable{}
    // the raffle owner picks a winner randomly
    function pickWinner() public {}

    //getter function 
    function getEntranceFee() external view returns (uint256){
        return I_ENTRANCE_FEE;
    }
  
}