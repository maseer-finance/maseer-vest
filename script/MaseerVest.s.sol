// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {MaseerVest} from "../src/MaseerVest.sol";

contract MaseerVestScript is Script {

    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant BOSS = 0x517F95f34685f553E56cAea726880410C1EEA569;

    MaseerVest public vest;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        vest = new MaseerVest(BOSS, USDT);
        vest.file("cap", 10_000e6); // Set cap to 10,000 USDT per second max
        vest.rely(BOSS); // Allow BOSS to manage the vesting contract
        vest.deny(msg.sender); // Deny the deployer from managing the vesting contract

        vm.stopBroadcast();

        console.log("MaseerVest deployed at:", address(vest));
    }
}
