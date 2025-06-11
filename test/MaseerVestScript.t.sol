// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {MaseerVestScript, MaseerVest} from "../script/MaseerVest.s.sol";

contract MaseerOneScriptTest is Test {

    MaseerVestScript public maseerVestScript;
    MaseerVest public maseerVest;

    function setUp() public {
        maseerVestScript = new MaseerVestScript();
    }

    function testMaseerOneScript() public view {
        assertEq(maseerVestScript.USDT(), 0xdAC17F958D2ee523a2206206994597C13D831ec7, "USDT address mismatch");
        assertEq(maseerVestScript.BOSS(), 0x517F95f34685f553E56cAea726880410C1EEA569, "BOSS address mismatch");
    }

    function testScriptDeployment() public {
        maseerVestScript.run();
        maseerVest = maseerVestScript.vest();

        assertTrue(address(maseerVest) != address(0), "MaseerVest should be deployed");
        assertEq(maseerVest.czar(), maseerVestScript.BOSS(), "Czar should be BOSS");
        assertEq(address(maseerVest.gem()), maseerVestScript.USDT(), "Gem should be USDT");
        assertEq(maseerVest.cap(), 10_000e6, "Cap should be set to 10,000 USDT/sec");
        assertEq(maseerVest.wards(maseerVestScript.BOSS()), 1, "BOSS should have management rights");
    }
}

