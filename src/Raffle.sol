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

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
// @title A sample Raffle
// @author laitanop
// @notice This is a raffle contract
// @dev This is a raffle contract

contract Raffle is VRFConsumerBaseV2Plus {
    //errors
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimePassed();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
// Type declarations
 enum RaffleState { OPEN, CALCULATING }


// state variables 
    uint256 private immutable I_ENTRANCE_FEE;
    address payable[] private sPlayers;
    uint256 private immutable I_INTERVAL;
    uint256 private sLastTimeStamp;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable I_CALLBACK_GAS_LIMIT;
    uint32 private constant NUM_WORDS = 1;
    address private sRecentWinner;
    RaffleState private sRaffleState;

    //event
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 inteval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = inteval;
        I_KEY_HASH = gasLane;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALLBACK_GAS_LIMIT = callbackGasLimit;

        sLastTimeStamp = block.timestamp;
        sRaffleState = RaffleState.OPEN;
    }
    // enter a raffle or buy a lotery ticket

    function enterRaffle() public payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughEthSent();
        }
        if(sRaffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        sPlayers.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // the raffle owner picks a winner randomly
    function pickWinner() external {
        if ((block.timestamp - sLastTimeStamp) < I_INTERVAL) {
            revert Raffle__NotEnoughTimePassed();
        }
        sRaffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: I_CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(req);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];
        sRecentWinner = recentWinner;
        sRaffleState = RaffleState.OPEN
        sPlayers = new address payable[](0);
        sLastTimeStamp = block.timestamp;

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(sRecentWinner);
    }

    //getter function
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }
}
