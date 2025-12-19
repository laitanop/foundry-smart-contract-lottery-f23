// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { DeployRaffle } from "../../script/DeployRaffle.s.sol";
import { Raffle } from "../../src/Raffle.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { Vm } from "forge-std/Vm.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public playerAddress = makeAddr("player");
    uint256 public startingPlayerBalance = 10 ether;
    uint256 entranceFee;
    uint256 automationUpdateInterval;
    address vrfCoordinatorV25;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.raffleEntranceFee;
        automationUpdateInterval = config.automationUpdateInterval;
        vrfCoordinatorV25 = config.vrfCoordinatorV25;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(playerAddress, startingPlayerBalance);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYoudontPayEnough() public {
        // Arrange
        vm.prank(playerAddress);
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }
    function testRaffleRecordsPlayerWhenTheyEnter() public {
        // Arrange
        vm.prank(playerAddress);
        // Act
        raffle.enterRaffle{ value: entranceFee }();
        // Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == playerAddress);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(playerAddress);

        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
    }
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
    }
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act / Assert

        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);
        _;
    }
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        // Arrange
        vm.prank(playerAddress);
        raffle.enterRaffle{ value: entranceFee }();
        vm.warp(block.timestamp + automationUpdateInterval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep() public raffleEntered skipFork {
        // Arrange
        // Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // vm.mockCall could be used here...
        VRFCoordinatorV2_5Mock(vrfCoordinatorV25).fulfillRandomWords(0, address(raffle));

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinatorV25).fulfillRandomWords(1, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        address expectedWinner = address(1);

        // Arrange
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0)

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{ value: entranceFee }();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console2.logBytes32(entries[1].topics[1]);
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs

        VRFCoordinatorV2_5Mock(vrfCoordinatorV25).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == startingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
