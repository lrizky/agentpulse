# AgentPulse

A daily check-in dApp built exclusively for **Binance Agent ID** holders, live on BNB Smart Chain.

Only wallets holding a SPACE ID Agent ID (a `.ai` name) can check in: the `AgentCheckIn` contract verifies ownership on-chain against the Agent ID registry (`0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`) on every call. Each wallet checks in once per day (UTC), builds a streak, and appears on the public leaderboard — an on-chain **proof-of-active-agent** registry that other projects can read for allowlists and ecosystem campaigns.

- **Live dApp:** https://muse.ai/s/agentpulse-xxd6xgoxrgxthlxx/IIXvuMF6PTnQXiMpyGp8fFc7qHpy82mnesqxxRYoWZU
- **Contract (BSC):** `0x0a873C07f4E6e573ED6bd20E636c5633Eb98eC1A`
- **Verification:** BscScan and Sourcify show the source verified with an **exact match** (solc v0.8.38, optimizer 200 runs).

The contract holds no funds, has no owner, and requests no token approvals. The only state it writes is each participant's own check-in statistics.

Built for the **Binance Agent ID Hackathon** (submission period 18 Nov – 9 Dec 2026).

## Contract

`AgentCheckIn.sol` — Solidity ^0.8.20, MIT license.

Key functions:

- `checkIn()` — record today's check-in (Agent ID holders only, once per UTC day)
- `hasAgentId(address)` — whether a wallet holds an Agent ID
- `statsOf(address)` — total check-ins, current streak, best streak, last/first check-in day
- `checkedInToday(address)` — whether a wallet has already checked in today
- `totalAgents()` / `totalCheckInsAll()` — global counters

Events: `CheckedIn(address indexed agent, uint256 day, uint256 streak, uint256 totalCheckIns)`.
