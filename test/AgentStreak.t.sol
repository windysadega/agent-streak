// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AgentStreakCheckIn} from "../src/AgentStreakCheckIn.sol";
import {AgentStreakBadge} from "../src/AgentStreakBadge.sol";
import {AgentGate} from "../src/AgentGate.sol";
import {MockAgentID} from "./MockAgentID.sol";

interface Vm {
    function warp(uint256) external;
    function prank(address) external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function expectRevert() external;
}

contract AgentStreakTest {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 internal constant DAY0 = 20000 * 86400; // realistic UTC day boundary

    MockAgentID internal mock;
    AgentStreakCheckIn internal checkIn;
    AgentStreakBadge internal badge;

    address internal alice = address(0xA11CE); // Agent ID holder
    address internal bob = address(0xB0B); // no Agent ID
    address internal owner = address(0x0DE1);

    function setUp() public {
        vm.warp(DAY0 + 3600);
        mock = new MockAgentID();
        mock.setHolder(alice, "alice");
        checkIn = new AgentStreakCheckIn(address(mock));
        badge = new AgentStreakBadge(address(mock), address(checkIn), owner, "https://example.invalid/meta/");
    }

    // ---------- gate ----------

    function test_nonHolderCannotCheckIn() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.NoAgentId.selector, bob));
        checkIn.checkIn();
    }

    function test_nonHolderCannotMint() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(AgentGate.NoAgentId.selector, bob));
        badge.mint(1);
    }

    function test_isAgentAndHandle() public view {
        require(checkIn.isAgent(alice), "alice is agent");
        require(!checkIn.isAgent(bob), "bob is not agent");
        require(keccak256(bytes(checkIn.handleOf(alice))) == keccak256(bytes("alice")), "handle");
    }

    // ---------- check-in mechanics ----------

    function test_firstCheckIn() public {
        vm.prank(alice);
        checkIn.checkIn();
        (uint64 lastDay, uint32 streak, uint32 best, uint64 total, uint64 points) = checkIn.statsOf(alice);
        require(lastDay == 20000, "day");
        require(streak == 1 && best == 1, "streak 1");
        require(total == 1, "total 1");
        require(points == 10, "points 10");
        require(checkIn.totalUsers() == 1, "users 1");
        require(checkIn.totalCheckInsAll() == 1, "all 1");
        require(checkIn.hasCheckedInToday(alice), "today flag");
    }

    function test_doubleCheckInSameDayReverts() public {
        vm.prank(alice);
        checkIn.checkIn();
        vm.prank(alice);
        vm.expectRevert();
        checkIn.checkIn();
    }

    function test_streakIncrementsNextDay() public {
        vm.prank(alice);
        checkIn.checkIn();
        vm.warp(DAY0 + 86400 + 10);
        vm.prank(alice);
        checkIn.checkIn();
        (, uint32 streak, uint32 best, uint64 total, uint64 points) = checkIn.statsOf(alice);
        require(streak == 2 && best == 2, "streak 2");
        require(total == 2 && points == 20, "points 20");
    }

    function test_streakResetsAfterGap() public {
        vm.prank(alice);
        checkIn.checkIn();
        vm.warp(DAY0 + 86400);
        vm.prank(alice);
        checkIn.checkIn(); // streak 2
        vm.warp(DAY0 + 3 * 86400); // skip a day
        vm.prank(alice);
        checkIn.checkIn();
        (, uint32 streak, uint32 best, uint64 total,) = checkIn.statsOf(alice);
        require(streak == 1, "streak reset to 1");
        require(best == 2, "best stays 2");
        require(total == 3, "total 3");
    }

    function _checkInDays(uint256 fromDay, uint256 count) internal {
        for (uint256 i = 0; i < count; i++) {
            vm.warp(DAY0 + (fromDay + i) * 86400 + 60);
            vm.prank(alice);
            checkIn.checkIn();
        }
    }

    // ---------- badge tiers ----------

    function test_tier1MintAfterFirstCheckIn() public {
        vm.prank(alice);
        checkIn.checkIn();
        require(badge.eligible(alice, 1), "eligible t1");
        vm.prank(alice);
        uint256 id = badge.mint(1);
        require(id == 1, "token 1");
        require(badge.ownerOf(1) == alice, "owner alice");
        require(badge.tierOf(1) == 1, "tier 1");
        require(badge.hasTier(alice, 1), "has tier");
        require(badge.balanceOf(alice) == 1, "bal 1");
    }

    function test_tier1MintBeforeCheckInReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        badge.mint(1);
    }

    function test_doubleMintSameTierReverts() public {
        vm.prank(alice);
        checkIn.checkIn();
        vm.prank(alice);
        badge.mint(1);
        vm.prank(alice);
        vm.expectRevert();
        badge.mint(1);
    }

    function test_invalidTierReverts() public {
        vm.prank(alice);
        vm.expectRevert();
        badge.mint(4);
    }

    function test_tier2AtSevenDayStreak() public {
        _checkInDays(0, 6); // streak 6
        require(!badge.eligible(alice, 2), "not yet eligible t2");
        vm.prank(alice);
        vm.expectRevert();
        badge.mint(2);
        _checkInDays(6, 1); // streak 7
        (, , uint32 best, , uint64 points) = checkIn.statsOf(alice);
        require(best == 7, "best 7");
        require(points == 75, "points: 6*10 + 15 (streak>=7 bonus)");
        require(badge.eligible(alice, 2), "eligible t2");
        vm.prank(alice);
        badge.mint(2);
        require(badge.hasTier(alice, 2), "has t2");
    }

    function test_tier3AtTwentyOneDayStreak() public {
        _checkInDays(0, 21);
        (, , uint32 best, uint64 total,) = checkIn.statsOf(alice);
        require(best == 21 && total == 21, "21 streak");
        require(badge.eligible(alice, 3), "eligible t3");
        vm.prank(alice);
        badge.mint(3);
        require(badge.hasTier(alice, 3), "has t3");
    }

    // ---------- soulbound + owner powers ----------

    function test_transfersRevert() public {
        vm.prank(alice);
        checkIn.checkIn();
        vm.prank(alice);
        badge.mint(1);
        vm.prank(alice);
        vm.expectRevert(AgentStreakBadge.Soulbound.selector);
        badge.transferFrom(alice, bob, 1);
        vm.prank(alice);
        vm.expectRevert(AgentStreakBadge.Soulbound.selector);
        badge.approve(bob, 1);
    }

    function test_onlyOwnerSetsBaseURI() public {
        vm.prank(bob);
        vm.expectRevert(AgentStreakBadge.NotOwner.selector);
        badge.setBaseURI("https://evil.invalid/");
        vm.prank(owner);
        badge.setBaseURI("https://badges.example/meta/");
        require(keccak256(bytes(badge.baseURI())) == keccak256(bytes("https://badges.example/meta/")), "uri set");
        vm.prank(alice);
        checkIn.checkIn();
        vm.prank(alice);
        badge.mint(1);
        require(
            keccak256(bytes(badge.tokenURI(1))) == keccak256(bytes("https://badges.example/meta/1.json")),
            "tokenURI tier file"
        );
    }
}
