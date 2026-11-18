# Agent Streak — agent skill

Instructions for an AI agent acting for its user (an Agent ID holder) who
wants to use **Agent Streak** on BNB Chain (chainId 56). The agent proposes
each transaction; the user confirms it in the Binance App. Never bypass
the user's confirmation.

## Contracts

| Contract | Address |
|---|---|
| AgentStreakCheckIn | `0xed28b68bdd35ecc21953312543b1964ad1073516` |
| AgentStreakBadge | `0x40d23c5b47ac9d571cfbd50a5724f8d9e5d57148` |
| Agent ID (gate) | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |

## Preconditions

- The user's agentic wallet must hold an Agent ID
  (`balanceOf(user) > 0` on the Agent ID contract). If it does not, tell the
  user to claim one first in the Binance App (Wallet → Agent ID banner) —
  an agent cannot claim it for them.
- Developer Mode must be enabled for `baw contract-call` (check
  `baw wallet settings --json` → `devMode.enabled = true`).

## Daily check-in (once per UTC day)

1. Read state first: `statsOf(user)`, `hasCheckedInToday(user)` on the
   check-in contract. If already checked in today, report the current
   streak/points and stop.
2. Preview: `baw contract-call preview --binanceChainId 56 --from <user>
   --to 0xed28b68bdd35ecc21953312543b1964ad1073516 --value 0
   --inputData 0x183ff085 --json` (`checkIn()` selector).
3. Show the user the preview (function, contract, zero value, tiny gas),
   get explicit confirmation, then
   `baw contract-call execute --requestId <id> --json`.
4. Report the new streak and points from `statsOf(user)`.

## Claim a milestone badge (free)

Tiers: 1 = first check-in done · 2 = best streak ≥ 7 · 3 = best streak ≥ 21.

1. For the tier in question, read `eligible(user, tier)` and
   `hasTier(user, tier)` on the badge contract. Claim only if eligible and
   not yet claimed.
2. Preview `mint(uint8)` (calldata = selector `0x6ecd2306` + 32-byte tier),
   show it to the user, confirm, execute — same two-step flow as above.
3. Badges are soulbound: they cannot be transferred or sold, and they have
   no monetary value. Points are a score only. Never describe either as
   earnings or investment.

## Errors

- `NoAgentId` — the wallet holds no Agent ID (see Preconditions).
- `AlreadyCheckedIn` — today's check-in is already recorded; come back
  after the next UTC midnight.
- `MilestoneNotReached` — keep checking in; the tier unlocks at the streak.
- `AlreadyClaimed` — that tier's badge is already in the wallet.
