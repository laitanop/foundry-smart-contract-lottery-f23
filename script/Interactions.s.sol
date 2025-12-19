// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";

import { DevOpsTools } from "foundry-devops/src/DevOpsTools.sol";
import { VRFCoordinatorV2_5Mock } from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import { LinkToken } from "../test/mocks/LinkToken.sol";
import { CodeConstants } from "./HelperConfig.s.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorV25 = helperConfig.getConfigByChainId(block.chainid).vrfCoordinatorV25;
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        return createSubscription(vrfCoordinatorV25, account);
    }

    function createSubscription(address vrfCoordinatorV25, address account) public returns (uint256, address) {
        console.log("Creating subscription on chainId: ", block.chainid);

        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorV25).createSubscription();
        vm.stopBroadcast();
        console.log("Your subscription Id is: ", subId);
        console.log("Please update the subscriptionId in HelperConfig.s.sol");
        return (subId, vrfCoordinatorV25);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV25 = helperConfig.getConfig().vrfCoordinatorV25;
        address account = helperConfig.getConfig().account;
        addConsumer(mostRecentlyDeployed, vrfCoordinatorV25, subId, account);
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}

contract FundSubscription is CodeConstants, Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address vrfCoordinatorV25 = helperConfig.getConfig().vrfCoordinatorV25;
        address link = helperConfig.getConfig().link;

        if (subId == 0) {
            CreateSubscription createSub = new CreateSubscription();
            (uint256 updatedSubId, address updatedVrfV2) = createSub.run();
            subId = updatedSubId;
            vrfCoordinatorV25 = updatedVrfV2;
            console.log("New SubId Created! ", subId, "VRF Address: ", vrfCoordinatorV25);
        }
        address account = helperConfig.getConfigByChainId(block.chainid).account;
        fundSubscription(vrfCoordinatorV25, subId, link, account);
    }

    function fundSubscription(address vrfCoordinatorV25, uint256 subId, address link, address account) public {
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV25);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinatorV25).fundSubscription(subId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinatorV25, FUND_AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}
