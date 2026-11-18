# Agent Streak — "Check in daily. Earn your stripes."

A daily check-in club that only Agent ID holders can enter, live on BNB Chain.
Check in once a day to build a streak and earn points; at streak milestones,
claim free soulbound badge NFTs that prove your attendance.

- **AgentStreakCheckIn**: `0xed28b68bdd35ecc21953312543b1964ad1073516`
  (https://bscscan.com/address/0xed28b68bdd35ecc21953312543b1964ad1073516)
- **AgentStreakBadge**: `0x40d23c5b47ac9d571cfbd50a5724f8d9e5d57148`
  (https://bscscan.com/address/0x40d23c5b47ac9d571cfbd50a5724f8d9e5d57148)
- Built for the Binance Wallet × BNB Chain **Agent ID Hackathon** (Nov–Dec 2026).

## How Agent ID is used (the core of the product)

Agent ID is not a decoration here — the product does not function without it:

1. **Access gate.** Every state-changing function (`checkIn()`, `mint(tier)`)
   passes through one gate: `balanceOf(caller) > 0` on the official SPACE ID
   Agent ID contract `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`. No Agent ID,
   no check-in, no badge. The check is on `msg.sender` (never `tx.origin`).
2. **Identity.** The product reads your own handle on-chain with
   `handleOf(address)` and greets you by it (e.g. "Welcome back, avelin.ai").
   Only the connected user's own handle is ever displayed — the contracts and
   site never look up other people's wallets by name.
3. **Anti-sybil by design.** An Agent ID is soulbound and one-per-person, so
   one human = one check-in identity = one set of badges. IDs cannot be lent
   or transferred, so the free mint cannot be farmed with borrowed identities.

## Mechanics

- **Check in** once per UTC day. Streak increments on consecutive days and
  resets after a missed day; best streak is kept forever.
- **Points:** 10 per check-in, +5 bonus on check-ins made while your current
  streak is 7 days or longer. Points are a non-transferable score only —
  they are not a token, have no monetary value, and cannot be redeemed.
- **Badges (free mint, soulbound ERC-721):**
  - Tier 1 — after your first check-in
  - Tier 2 — best streak of 7 days
  - Tier 3 — best streak of 21 days
  (21 days is the longest streak reachable inside the hackathon window
  18 Nov – 9 Dec, so every tier is earnable during the campaign.)
  One badge per holder per tier. Badges cannot be transferred or sold —
  every transfer/approval function reverts. They are proofs of attendance,
  not financial assets.

## Owner permissions (full disclosure)

- `AgentStreakCheckIn` has **no owner and no admin functions at all**.
  Nobody can pause it, change it, or touch user stats.
- `AgentStreakBadge` has exactly **one** owner power: `setBaseURI(string)`,
  which points token metadata at its host. There is no admin mint, no fee,
  no pause, no withdraw. The contract never holds funds.
- Neither contract has any payable function, requests any token approval,
  or moves user assets in any way.

## Safety / hackathon red-line compliance

- No QR-code or pairing-code login anywhere; the website uses a standard
  injected-wallet connection only, and every transaction is confirmed by
  the user in their own wallet.
- No promises of returns or earnings anywhere in product copy. Points and
  badges are explicitly non-financial.
- No collection of credentials or personal data; no server-side sessions.
- Contracts are open-source (this repo, MIT) and verified on Sourcify with
  exact match; BscScan verification uses the same source (see below).

## Build, test, deploy

```bash
forge build
forge test        # 15 tests: gate, streak math, tier gating, soulbound, owner powers
```

- Compiler: solc 0.8.26, optimizer 200 runs (see `foundry.toml`).
- The Agent ID contract address is a constructor argument (immutable), which
  lets the test suite run against a mock (`test/MockAgentID.sol`). Production
  deployments pass the official address above.
- Production deployment used CREATE2 through the canonical deterministic
  deployment proxy `0x4e59b44847b379578588920cA78FbF26c0B4956C`, because the
  deployer wallet (Binance Agentic Wallet via `baw contract-call`) signs
  contract calls, not raw creation transactions. Salts:
  - CheckIn: `keccak256("AgentStreakCheckIn.v1")` → `0xed28b6…073516`
  - Badge: `keccak256("AgentStreakBadge.v1")` → `0x40d23c…d57148`
  Constructor arguments are part of the init code, so the addresses are
  fully reproducible from this repo.

## Verification

- Sourcify: both contracts verified, **exact match** (chain 56).
- BscScan: verify with an Etherscan V2 API key —
  `forge verify-contract <address> <Contract> --chain-id 56 --etherscan-api-key <key>`
  with the constructor args in `DEPLOY notes` — or via the BscScan web UI
  using the flattened sources in `flattened/` (solc 0.8.26, optimizer 200).

## For AI agents

See `skill.md`: a ready instruction file so any user's own agent (e.g. via
the Binance Agentic Wallet `baw` CLI) can perform the daily check-in and
badge claims with the usual preview → user-confirm → execute flow.

## License

MIT
