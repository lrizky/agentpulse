// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal ERC-721 interface, inlined so this file is fully
///         self-contained (no external imports). Only `balanceOf` is needed:
///         the Agent ID registry is an ERC-721 collection in which holding
///         any token means the address owns an Agent ID.
interface IERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentCheckIn — Daily check-in & streaks for Binance Agent ID holders
/// @notice AgentCheckIn is a lightweight on-chain habit builder for the
///         Agentic Wallet ecosystem. Once per day, any wallet that holds a
///         Binance **Agent ID** can call {checkIn} to record attendance and
///         grow a consecutive-day streak. The contract keeps per-agent
///         statistics (totals, current/best streak) and global counters,
///         giving Agent ID a recurring, identity-anchored use case:
///         "show up every day, prove it on-chain, keep the streak alive."
///
/// @dev Agent ID integration
///      ---------------------
///      Agent ID is the on-chain name of a Binance Agentic Wallet, issued as
///      a non-transferable ERC-721 token by the SPACE ID Agent ID registry
///      on BNB Chain:
///
///          Registry: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
///          Standard: ERC-721 (symbol "AI", non-transferable)
///
///      Because each user can claim exactly one Agent ID and it cannot be
///      transferred, `registry.balanceOf(user) > 0` is a reliable,
///      Sybil-resistant identity gate: one Agent ID == one participant.
///      {checkIn} enforces this gate on every call, and {hasAgentId}
///      exposes the same check for frontends and other contracts.
///
///      The contract is deliberately minimal and safe:
///      - no owner / no admin keys, no upgradeability,
///      - no payable functions, it never receives, holds, or moves funds,
///      - no token approvals of any kind are requested from users,
///      - the only state it writes is the caller's own check-in statistics.
contract AgentCheckIn {
    /// @notice The SPACE ID Agent ID registry on BNB Chain (ERC-721).
    /// @dev Holding at least one token from this registry is the sole
    ///      eligibility requirement for checking in.
    address public constant AGENT_ID_REGISTRY = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    /// @dev Typed handle on the registry, used for the `balanceOf` gate.
    IERC721 internal constant _registry = IERC721(AGENT_ID_REGISTRY);

    /// @notice Per-agent check-in statistics.
    /// @param totalCheckIns  Lifetime number of check-ins by this agent.
    /// @param currentStreak  Current run of consecutive days checked in.
    /// @param bestStreak     Longest consecutive-day run ever achieved.
    /// @param lastCheckInDay Unix day (block.timestamp / 86400) of the most
    ///                       recent check-in; 0 means "never checked in".
    /// @param firstCheckInDay Unix day of the agent's first ever check-in.
    struct Stats {
        uint256 totalCheckIns;
        uint256 currentStreak;
        uint256 bestStreak;
        uint256 lastCheckInDay;
        uint256 firstCheckInDay;
    }

    /// @dev Check-in statistics per agent address.
    mapping(address => Stats) internal _stats;

    /// @notice Number of unique Agent ID addresses that have ever checked in.
    uint256 public totalAgents;

    /// @notice Total number of check-ins recorded across all agents.
    uint256 public totalCheckInsAll;

    /// @notice Emitted on every successful check-in.
    /// @param agent        The Agent ID holder that checked in.
    /// @param day          The unix day (block.timestamp / 86400) recorded.
    /// @param streak       The agent's current consecutive-day streak
    ///                     after this check-in.
    /// @param totalCheckIns The agent's lifetime check-in count after
    ///                     this check-in.
    event CheckedIn(address indexed agent, uint256 day, uint256 streak, uint256 totalCheckIns);

    /// @notice Record today's check-in for the caller.
    /// @dev Eligibility and rules:
    ///      - The caller MUST hold an Agent ID:
    ///        `AGENT_ID_REGISTRY.balanceOf(msg.sender) > 0`, otherwise the
    ///        call reverts with "Agent ID required".
    ///      - One check-in per unix day: a second call on the same day
    ///        reverts with "Already checked in today".
    ///      - Streak logic: if the previous check-in was yesterday
    ///        (lastCheckInDay == today - 1) the streak increments;
    ///        otherwise (first ever check-in, or a gap of 2+ days) the
    ///        streak restarts at 1. `bestStreak` tracks the all-time max.
    function checkIn() external {
        require(hasAgentId(msg.sender), "Agent ID required");

        uint256 today = _today();
        Stats storage s = _stats[msg.sender];

        require(s.lastCheckInDay != today, "Already checked in today");

        if (s.totalCheckIns == 0) {
            // First ever check-in: register the agent and anchor day one.
            s.firstCheckInDay = today;
            totalAgents += 1;
        }

        if (s.lastCheckInDay == today - 1) {
            // Yesterday -> the streak continues.
            s.currentStreak += 1;
        } else {
            // First check-in ever, or the streak was broken by a gap.
            s.currentStreak = 1;
        }
        if (s.currentStreak > s.bestStreak) {
            s.bestStreak = s.currentStreak;
        }

        s.lastCheckInDay = today;
        s.totalCheckIns += 1;
        totalCheckInsAll += 1;

        emit CheckedIn(msg.sender, today, s.currentStreak, s.totalCheckIns);
    }

    /// @notice Whether an address holds a Binance Agent ID.
    /// @dev This is the exact gate used by {checkIn}: the Agent ID registry
    ///      is a non-transferable ERC-721, so a balance above zero means the
    ///      address owns its (single, unique) Agent ID.
    /// @param user The address to check.
    /// @return True if `user` holds at least one Agent ID token.
    function hasAgentId(address user) public view returns (bool) {
        return _registry.balanceOf(user) > 0;
    }

    /// @notice Full check-in statistics for an agent.
    /// @param user The address to look up.
    /// @return totalCheckIns  Lifetime check-ins.
    /// @return currentStreak  Current consecutive-day streak.
    /// @return bestStreak     Best consecutive-day streak ever.
    /// @return lastCheckInDay Unix day of the last check-in (0 if never).
    /// @return firstCheckInDay Unix day of the first check-in (0 if never).
    function statsOf(address user)
        external
        view
        returns (
            uint256 totalCheckIns,
            uint256 currentStreak,
            uint256 bestStreak,
            uint256 lastCheckInDay,
            uint256 firstCheckInDay
        )
    {
        Stats storage s = _stats[user];
        return (s.totalCheckIns, s.currentStreak, s.bestStreak, s.lastCheckInDay, s.firstCheckInDay);
    }

    /// @notice Whether an agent has already checked in on the current day.
    /// @param user The address to check.
    /// @return True if the agent's last check-in day is today.
    function checkedInToday(address user) external view returns (bool) {
        return _stats[user].totalCheckIns > 0 && _stats[user].lastCheckInDay == _today();
    }

    /// @dev Current unix day number, the contract's unit of "daily".
    function _today() internal view returns (uint256) {
        return block.timestamp / 86400;
    }
}
