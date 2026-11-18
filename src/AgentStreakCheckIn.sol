// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AgentGate} from "./AgentGate.sol";

/// @title Agent Streak — daily check-in
/// @notice Daily check-in for Agent ID holders. One check-in per address per
///         UTC day; streaks, totals and points are stored on-chain.
///         Points: 10 per check-in, plus a 5-point bonus on every check-in
///         made while the current streak is 7 days or longer. Points are a
///         non-transferable score only — they are not a token, carry no
///         monetary value and cannot be redeemed for anything of value.
/// @dev Safety by construction: no payable functions, no token transfers,
///      no approvals, no withdraw function, and NO admin/owner powers at
///      all. The contract never holds funds. The only gate is Agent ID
///      ownership, checked against the official Agent ID contract.
contract AgentStreakCheckIn is AgentGate {
    struct Stats {
        uint64 lastDay; // UTC day index (timestamp / 86400) of the last check-in
        uint32 streak; // current consecutive-day streak
        uint32 bestStreak; // longest streak ever reached
        uint64 totalCheckIns; // lifetime check-in count
        uint64 points; // lifetime points (score only, no monetary value)
    }

    mapping(address => Stats) public statsOf;
    uint256 public totalUsers;
    uint256 public totalCheckInsAll;

    event CheckedIn(
        address indexed user, uint64 indexed day, uint32 streak, uint64 totalCheckIns, uint64 points
    );

    error AlreadyCheckedIn(address user, uint64 day);

    constructor(address agentId_) AgentGate(agentId_) {}

    /// @notice Current UTC day index.
    function currentDay() public view returns (uint64) {
        return uint64(block.timestamp / 1 days);
    }

    /// @notice Check in for today. Agent ID holders only, once per UTC day.
    function checkIn() external onlyAgent {
        Stats storage s = statsOf[msg.sender];
        uint64 today = currentDay();
        if (s.totalCheckIns != 0 && s.lastDay == today) {
            revert AlreadyCheckedIn(msg.sender, today);
        }
        if (s.totalCheckIns == 0) {
            totalUsers++;
            s.streak = 1;
        } else if (s.lastDay + 1 == today) {
            s.streak += 1; // consecutive day: streak grows
        } else {
            s.streak = 1; // missed at least one day: streak restarts
        }
        if (s.streak > s.bestStreak) s.bestStreak = s.streak;
        s.lastDay = today;
        s.totalCheckIns += 1;
        totalCheckInsAll += 1;
        s.points += 10 + (s.streak >= 7 ? 5 : 0);
        emit CheckedIn(msg.sender, today, s.streak, s.totalCheckIns, s.points);
    }

    // --- views used by the badge contract and the website ---

    function totalCheckInsOf(address who) external view returns (uint64) {
        return statsOf[who].totalCheckIns;
    }

    function streakOf(address who) external view returns (uint32) {
        return statsOf[who].streak;
    }

    function bestStreakOf(address who) external view returns (uint32) {
        return statsOf[who].bestStreak;
    }

    function pointsOf(address who) external view returns (uint64) {
        return statsOf[who].points;
    }

    function hasCheckedInToday(address who) external view returns (bool) {
        Stats storage s = statsOf[who];
        return s.totalCheckIns != 0 && s.lastDay == currentDay();
    }

    function myStats() external view returns (Stats memory) {
        return statsOf[msg.sender];
    }
}
