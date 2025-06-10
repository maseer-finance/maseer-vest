// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MaseerVest} from "../src/MaseerVest.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IUSDT} from "./interfaces/IUSDT.sol";

contract MaseerVestTest is Test {

    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant DAI  = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    address public org;
    address public guy;

    IUSDT public gem = IUSDT(USDT);

    MaseerVest public vest;

    function setUp() public {
        org = makeAddr("org");
        guy = makeAddr("guy");

        vest = new MaseerVest(org, USDT);
        vest.file("cap", 10000e6); // Set cap to 10000 USDT

        vm.prank(org);
        IUSDT(USDT).approve(address(vest), type(uint256).max);
    }

    function testSanity() public view {
        assertEq(vest.czar(), org, "czar should be org");
        assertEq(address(vest.gem()), USDT, "gem should be USDT");
    }

    function testInit() public {
        //          usr,        tot,             bgn,      clf,    fin,        mgr
        vest.create(guy, 5000 * 1e6, block.timestamp, 100 days, 0 days, address(1));
        (address _usr, uint48 bgn, uint48 clf, uint48 fin, address mgr,, uint128 tot, uint128 rxd) = vest.awards(1);
        assertEq(_usr, guy);
        assertEq(uint256(bgn), block.timestamp);
        assertEq(uint256(clf), block.timestamp);
        assertEq(uint256(fin), block.timestamp + 100 days);
        assertEq(uint256(tot), 5000 * 1e6);
        assertEq(uint256(rxd), 0);
        assertEq(mgr, address(1));
    }

    function testVest() public {
        uint256 total_amt = 300_000 * 1e6; // 300,000 USDT
        uint256 id = vest.create(guy, total_amt, block.timestamp, 100 days, 0 days, address(0));
        deal(USDT, address(org), total_amt, true); // Fund the vesting contract with USDT

        assertEq(gem.balanceOf(guy), 0);

        vm.warp(block.timestamp + 10 days);

        (address usr, uint48 bgn, uint48 clf, uint48 fin, address mgr,, uint128 tot, uint128 rxd) = vest.awards(id);
        assertEq(usr, guy);
        assertEq(uint256(bgn), block.timestamp - 10 days);
        assertEq(uint256(fin), block.timestamp + 90 days);
        assertEq(uint256(tot), total_amt);
        assertEq(uint256(rxd), 0);
        assertEq(gem.balanceOf(guy), 0);

        vest.vest(id);
        (usr, bgn, clf, fin, mgr,, tot, rxd) = vest.awards(id);
        assertEq(usr, guy);
        assertEq(uint256(bgn), block.timestamp - 10 days);
        assertEq(uint256(fin), block.timestamp + 90 days);
        assertEq(uint256(tot), 300000000000);
        assertEq(uint256(rxd), 30000000000);
        assertEq(gem.balanceOf(guy), 30000000000);

        vm.warp(block.timestamp + 70 days);

        vest.vest(id, type(uint256).max);
        (usr, bgn, clf, fin, mgr,, tot, rxd) = vest.awards(id);
        assertEq(usr, guy);
        assertEq(uint256(bgn), block.timestamp - 80 days);
        assertEq(uint256(fin), block.timestamp + 20 days);
        assertEq(uint256(tot), 300000000000);
        assertEq(uint256(rxd), 240000000000);
        assertEq(gem.balanceOf(guy), 240000000000);

        vm.warp(block.timestamp + 40 days);
        vest.vest(id, type(uint256).max);
        (usr, bgn, clf, fin, mgr,, tot, rxd) = vest.awards(id);
        assertEq(usr, guy);
        assertEq(uint256(bgn), block.timestamp - 120 days);
        assertEq(uint256(fin), block.timestamp - 20 days);
        assertEq(uint256(tot), total_amt);
        assertEq(uint256(rxd), total_amt);
        assertEq(gem.balanceOf(guy), total_amt);
    }
}
