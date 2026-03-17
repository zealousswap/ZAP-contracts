# ZAP Testnet Skill — Full Auction Lifecycle

Complete agent skill for the IGRA Galleon ZAP testnet Continuous Clearing Auction (CCA): bid → track → exit → claim.

---

## Network & Transaction Config

| Parameter | Value |
|---|---|
| Network | IGRA Galleon Testnet |
| RPC URL | `https://galleon-testnet.igralabs.com:8545` |
| Chain ID | `38836` |
| Native Currency | iKAS (18 decimals) |
| Block Explorer | `https://explorer.galleon-testnet.igralabs.com` |

**All transactions must be legacy** — EIP-1559 is not supported.
Use `--legacy --gas-price 2000000000001` (minimum enforced by node: exactly 2 000 000 000 000 wei; +1 avoids rounding rejection).

---

## Infrastructure Contract Addresses (fixed per network)

| Contract | Address |
|---|---|
| Query (lens) | `0x9Af01502944cC437f760350A0c52f308dA22D916` |
| AuctionStateLens | `0x2E0a4657Add59A6384388795efA7C0744FBCE273` |

---

## Step 0 — Gather Inputs & Fetch Auction Parameters

### Required Inputs (ask the user)

Before doing anything, ask for:

| Input | Description |
|---|---|
| `AUCTION_ADDRESS` | Address of the CCA auction contract |
| `TOKEN_NAME` | Human-readable name of the token being auctioned (e.g. `IGRA`) |
| `TOKEN_ADDRESS` | Contract address of the token being auctioned |
| `TOKEN_DECIMALS` | Decimals of the auctioned token (commonly `18`) |

### Fetch Auction Parameters On-Chain

Call `getAuctionParams` on the Query contract — one `eth_call`, no state change, returns all static auction config:

```bash
cast call \
  --rpc-url https://galleon-testnet.igralabs.com:8545 \
  0x9Af01502944cC437f760350A0c52f308dA22D916 \
  "getAuctionParams(address)((uint64,uint64,uint64,address,address,uint256,uint256,uint128,uint256))" \
  $AUCTION_ADDRESS
```

The returned tuple maps to:

| Field | Variable | Notes |
|---|---|---|
| `startBlock` | `$START_BLOCK` | Bidding opens at this block |
| `endBlock` | `$END_BLOCK` | Bidding closes at this block |
| `claimBlock` | `$CLAIM_BLOCK` | Tokens claimable from this block |
| `currency` | `$CURRENCY_ADDRESS` | `address(0)` = native iKAS; otherwise ERC20 |
| `token` | — | Should match `TOKEN_ADDRESS` provided above |
| `tickSpacing` | `$TICK_SPACING_Q96` | Q96 — price must be a multiple of this |
| `floorPrice` | `$FLOOR_PRICE_Q96` | Q96 — minimum allowed bid price |
| `totalSupply` | `$TOTAL_SUPPLY` | Total tokens being auctioned (raw, TOKEN_DECIMALS) |
| `maxBidPrice` | `$MAX_BID_PRICE_Q96` | Q96 — maximum allowed bid price |

**Currency check:** If `$CURRENCY_ADDRESS == 0x0000000000000000000000000000000000000000`, the currency is native iKAS — bid amounts are sent as `msg.value`, no ERC20 approval needed. Otherwise treat it as an ERC20 (requires approval).

Store all fetched values as named variables — you will reference them in every subsequent step instead of using hardcoded numbers.

### Auction Phases (derived from fetched values)

| Phase | Condition | Allowed Actions |
|---|---|---|
| Active | `currentBlock >= $START_BLOCK` and `< $END_BLOCK` | Submit bids |
| Ended | `currentBlock >= $END_BLOCK` and `< $CLAIM_BLOCK` | Exit bids |
| Claim | `currentBlock >= $CLAIM_BLOCK` | Exit bids, claim tokens |

---

## How the Auction Works

This is a **continuous time-weighted accumulation** auction, not a simple highest-bidder-wins:

- Each block where `your maxPrice > current clearingPrice` → you are **active** and accumulate a proportional share of tokens released that block.
- When the clearing price rises above your max → you are **outbid**, stop accumulating, but **keep all tokens already earned**.
- If clearing price drops back below your max → you become active again.
- At exit: you get a refund for unspent currency, and `tokensFilled` is settled.
- **You always pay the time-weighted average price, never your stated max price.**
- If `isGraduated = false` at auction end → all bids receive a full refund; no tokens distributed.

---

## Q96 Price Format

All prices are **Q96 fixed-point integers**: `price_Q96 = price_human * 2^96`

```
Q96 = 2^96 = 79_228_162_514_264_337_593_543_950_336

Human → Q96:  price_Q96   = price_human * Q96 / 10^(TOKEN_DECIMALS - CURRENCY_DECIMALS)
Q96 → Human:  price_human = price_Q96 / Q96 * 10^(TOKEN_DECIMALS - CURRENCY_DECIMALS)

// If TOKEN_DECIMALS == CURRENCY_DECIMALS (e.g. both 18), the 10^ factor cancels to 1.

Token amount raw:    raw = human * 10^TOKEN_DECIMALS
Currency amount raw: raw = human * 10^CURRENCY_DECIMALS   // 18 for native iKAS
```

To convert `$FLOOR_PRICE_Q96` → human readable:

```bash
cast --to-dec $FLOOR_PRICE_Q96  # then divide by 2^96 in your environment
# Python: int("$FLOOR_PRICE_Q96", 16) / (2**96)
```

**Tick alignment** — `maxPrice` must be a multiple of `$TICK_SPACING_Q96`:

```
maxPrice_Q96 = maxPrice_Q96 - (maxPrice_Q96 % $TICK_SPACING_Q96)   // round DOWN
```

---

## Step 1 — Submit a Bid

### Pre-checks

1. Confirm `currentBlock >= $START_BLOCK` and `currentBlock < $END_BLOCK`
2. `$FLOOR_PRICE_Q96` and `$TICK_SPACING_Q96` already fetched in Step 0 — no additional calls needed
3. Convert your desired human price to Q96 and align to tick (see Q96 section)
4. `maxPrice_Q96 >= $FLOOR_PRICE_Q96` and `<= $MAX_BID_PRICE_Q96`
5. If `$CURRENCY_ADDRESS == address(0)`: native iKAS balance ≥ bid amount + gas fees (same balance)
   If ERC20: token balance ≥ bid amount AND `approve(AUCTION_ADDRESS, amount)` on the currency token first

### Function

```solidity
function submitBid(
    uint256 maxPrice,       // Q96 — tick-aligned max price you'll pay per token
    uint128 amount,         // raw currency wei — must equal msg.value if native, otherwise 0
    address owner,          // receives tokens and refunds
    bytes calldata hookData // pass 0x (empty)
) external payable returns (uint256 bidId);
```

Selector: `0x140fe8ee`

```bash
# Native currency (iKAS): send amount as --value
cast send --legacy --gas-price 2000000000001 --gas-limit 500000 \
  --value <amountWei> \
  $AUCTION_ADDRESS \
  "submitBid(uint256,uint128,address,bytes)" \
  <maxPriceQ96> <amountWei> <ownerAddress> "0x"

# ERC20 currency: --value 0, approval must be done first
cast send --legacy --gas-price 2000000000001 --gas-limit 500000 \
  $AUCTION_ADDRESS \
  "submitBid(uint256,uint128,address,bytes)" \
  <maxPriceQ96> <amountWei> <ownerAddress> "0x"
```

- Gas: `~300 000–500 000`; use `eth_estimateGas × 1.5` when unsure
- **Save the returned `bidId`** — required for all subsequent steps

---

## Step 2 — Discover Bid IDs

Bid IDs are emitted via `BidSubmitted`. Scan logs from `$START_BLOCK` to `$END_BLOCK` in **chunks of 5 000 blocks**.

```
event BidSubmitted(uint256 indexed id, address indexed owner, uint256 price, uint128 amount)

topic0 = keccak256("BidSubmitted(uint256,address,uint256,uint128)")
topic2 = left-pad your wallet address to 32 bytes  // indexed owner
```

Collect every `id` (topic1) — those are your bid IDs.

---

## Step 3 — Track Bid State (Query Contract)

The **Query contract** is the recommended read path. One `eth_call` returns a fresh checkpoint, live token accumulation, currency spent, and pre-computed exit hints.

> **Critical:** Call via **`eth_call`** (simulate), not as a transaction. The function internally calls `checkpoint()` inside a try/revert — no state is written.

```solidity
function queryBids(
    address auction,
    uint256[] calldata bidIds
) external returns (QueryResult memory result);
```

```bash
cast call \
  --rpc-url https://galleon-testnet.igralabs.com:8545 \
  0x9Af01502944cC437f760350A0c52f308dA22D916 \
  "queryBids(address,uint256[])(((uint256,uint256,uint256,uint24,uint64,uint64),uint256,uint256,bool,uint64,uint64,uint64,uint256,(uint256,(uint64,uint24,uint64,uint256,address,uint256,uint256),uint256,uint256,bool,bool,bool,bool,uint64,uint64,uint64)[]))" \
  $AUCTION_ADDRESS \
  "[<bidId1>,<bidId2>]"
```

### Key Fields in the Response

**Top-level (`QueryResult`):**

| Field | Meaning |
|---|---|
| `checkpoint.clearingPrice` | Current clearing price (Q96) |
| `isGraduated` | Funding goal met — tokens will distribute |
| `startBlock / endBlock / claimBlock` | Phase boundaries |

**Per bid (`BidAccumulationInfo`):**

| Field | Meaning |
|---|---|
| `tokensAccumulated` | Live estimated IGRA earned (raw 18 dec); if `isExited`, equals settled `bid.tokensFilled` |
| `currencySpentQ96` | iKAS spent in Q96 → divide by `2^96` for human value |
| `bid.amountQ96` | Original deposit in Q96 |
| `isFullyAboveClearing` | Currently winning — accumulating every block |
| `isOutbid` | Clearing price exceeded your max — stopped accumulating |
| `isMarginal` | Exactly at clearing price — partially filled |
| `isExited` | Exit already settled |
| `lastFullyFilledCheckpointBlock` | Exit hint → pass directly to `exitPartiallyFilledBid` |
| `outbidBlock` | Exit hint → pass directly to `exitPartiallyFilledBid` (0 for marginal) |

**Conversion formulas:**

```
currencySpent_human   = currencySpentQ96 / 2^96              // in currency units (e.g. iKAS)
deposit_human         = bid.amountQ96 / 2^96
refund_estimate_human = (bid.amountQ96 - currencySpentQ96) / 2^96
tokens_human          = tokensAccumulated / 10^TOKEN_DECIMALS
```

---

## Step 4 — Exit Bid (After `$END_BLOCK`)

Exit settles your position: contract calculates final `tokensFilled`, refunds unspent currency, sets `exitedBlock`. **Must exit before claiming.**

### Choose the Right Function

Run `queryBids` after `$END_BLOCK` to get settled values, then:

| Condition | Function |
|---|---|
| `bid.maxPrice > checkpoint.clearingPrice` (fully above) | `exitBid(bidId)` |
| `bid.maxPrice ≤ checkpoint.clearingPrice` (outbid or marginal) | `exitPartiallyFilledBid(bidId, hints.lastFullyFilledCheckpointBlock, hints.outbidBlock)` |

```solidity
function exitBid(uint256 bidId) external;

function exitPartiallyFilledBid(
    uint256 bidId,
    uint64  lastFullyFilledCheckpointBlock,  // from queryBids result
    uint64  outbidBlock                       // from queryBids result (0 OK)
) external;
```

```bash
# exitBid
cast send --legacy --gas-price 2000000000001 --gas-limit 200000 \
  $AUCTION_ADDRESS \
  "exitBid(uint256)" <bidId>

# exitPartiallyFilledBid
cast send --legacy --gas-price 2000000000001 --gas-limit 400000 \
  $AUCTION_ADDRESS \
  "exitPartiallyFilledBid(uint256,uint64,uint64)" \
  <bidId> <lastFullyFilledCheckpointBlock> <outbidBlock>
```

Gas: `~200 000` for `exitBid`; `~300 000–500 000` for `exitPartiallyFilledBid`

Confirm with emitted event:

```
event BidExited(uint256 indexed bidId, address indexed owner, uint256 tokensFilled, uint256 currencyRefunded)
```

---

## Step 5 — Claim Tokens (After `$CLAIM_BLOCK`)

### Pre-checks (via `queryBids`)

1. `isExited = true`
2. `currentBlock >= $CLAIM_BLOCK`
3. `bid.tokensFilled > 0` (skip if 0 — nothing to claim, call will revert)
4. `isGraduated = true` (if false, no tokens distributed — only currency refunds via exit)

```solidity
function claimTokens(uint256 bidId) external;

function claimTokensBatch(address owner, uint256[] calldata bidIds) external;  // preferred for multiple bids
```

```bash
# Single
cast send --legacy --gas-price 2000000000001 --gas-limit 120000 \
  $AUCTION_ADDRESS \
  "claimTokens(uint256)" <bidId>

# Batch
cast send --legacy --gas-price 2000000000001 --gas-limit 300000 \
  $AUCTION_ADDRESS \
  "claimTokensBatch(address,uint256[])" \
  <ownerAddress> "[<bidId1>,<bidId2>]"
```

Gas: `~80 000–120 000` per bid. Tokens sent to `bid.owner`.

Confirm with emitted event:

```
event TokensClaimed(uint256 indexed bidId, address indexed owner, uint256 tokensFilled)
```

---

## Full Workflow Summary

```
0. SETUP
   - Ask user for: AUCTION_ADDRESS, TOKEN_NAME, TOKEN_ADDRESS, TOKEN_DECIMALS
   - cast call Query.getAuctionParams(AUCTION_ADDRESS)
   - Store: START_BLOCK, END_BLOCK, CLAIM_BLOCK, FLOOR_PRICE_Q96, TICK_SPACING_Q96,
           MAX_BID_PRICE_Q96, TOTAL_SUPPLY, CURRENCY_ADDRESS
   - Check CURRENCY_ADDRESS: address(0) = native iKAS (no approval); else ERC20

1. SUBMIT (currentBlock in [START_BLOCK, END_BLOCK))
   - Price → Q96, tick-align (% TICK_SPACING_Q96 == 0), check ≥ FLOOR_PRICE_Q96
   - submitBid(maxPrice, amount, owner, 0x)  with value=amount if native
   - Save returned bidId

2. DISCOVER BID IDs (if lost)
   - Scan BidSubmitted events from START_BLOCK to END_BLOCK in 5000-block chunks
   - Filter topic2 = your address → collect topic1 (id)

3. TRACK (any time)
   - eth_call queryBids(AUCTION_ADDRESS, [bidIds])  via Query contract
   - Check tokensAccumulated, currencySpentQ96, isFullyAboveClearing / isOutbid / isMarginal

4. EXIT (currentBlock >= END_BLOCK)
   - eth_call queryBids one final time for settled values + hints
   - maxPrice > clearingPrice  →  exitBid(bidId)
   - maxPrice ≤ clearingPrice  →  exitPartiallyFilledBid(bidId, lastFullyFilledCheckpointBlock, outbidBlock)

5. CLAIM (currentBlock >= CLAIM_BLOCK, isExited=true, tokensFilled>0, isGraduated=true)
   - claimTokens(bidId)  OR  claimTokensBatch(owner, [bidIds])
```

---

## Minimal ABIs

### Query Contract

```json
[
  {
    "name": "queryBids", "type": "function", "stateMutability": "nonpayable",
    "inputs": [
      {"name": "auction", "type": "address"},
      {"name": "bidIds", "type": "uint256[]"}
    ],
    "outputs": [{
      "name": "result", "type": "tuple",
      "components": [
        {"name": "checkpoint", "type": "tuple", "components": [
          {"name": "clearingPrice", "type": "uint256"},
          {"name": "currencyRaisedAtClearingPriceQ96_X7", "type": "uint256"},
          {"name": "cumulativeMpsPerPrice", "type": "uint256"},
          {"name": "cumulativeMps", "type": "uint24"},
          {"name": "prev", "type": "uint64"},
          {"name": "next", "type": "uint64"}
        ]},
        {"name": "currencyRaised", "type": "uint256"},
        {"name": "totalCleared", "type": "uint256"},
        {"name": "isGraduated", "type": "bool"},
        {"name": "startBlock", "type": "uint64"},
        {"name": "endBlock", "type": "uint64"},
        {"name": "claimBlock", "type": "uint64"},
        {"name": "sumCurrencyDemandAboveClearingQ96", "type": "uint256"},
        {"name": "bids", "type": "tuple[]", "components": [
          {"name": "bidId", "type": "uint256"},
          {"name": "bid", "type": "tuple", "components": [
            {"name": "startBlock", "type": "uint64"},
            {"name": "startCumulativeMps", "type": "uint24"},
            {"name": "exitedBlock", "type": "uint64"},
            {"name": "maxPrice", "type": "uint256"},
            {"name": "owner", "type": "address"},
            {"name": "amountQ96", "type": "uint256"},
            {"name": "tokensFilled", "type": "uint256"}
          ]},
          {"name": "tokensAccumulated", "type": "uint256"},
          {"name": "currencySpentQ96", "type": "uint256"},
          {"name": "isFullyAboveClearing", "type": "bool"},
          {"name": "isOutbid", "type": "bool"},
          {"name": "isMarginal", "type": "bool"},
          {"name": "isExited", "type": "bool"},
          {"name": "lastFullyFilledCheckpointBlock", "type": "uint64"},
          {"name": "outbidBlock", "type": "uint64"},
          {"name": "marginalCheckpointBlock", "type": "uint64"}
        ]}
      ]
    }]
  },
  {
    "name": "getAuctionParams", "type": "function", "stateMutability": "view",
    "inputs": [{"name": "auction", "type": "address"}],
    "outputs": [{"name": "params", "type": "tuple", "components": [
      {"name": "startBlock", "type": "uint64"},
      {"name": "endBlock", "type": "uint64"},
      {"name": "claimBlock", "type": "uint64"},
      {"name": "currency", "type": "address"},
      {"name": "token", "type": "address"},
      {"name": "tickSpacing", "type": "uint256"},
      {"name": "floorPrice", "type": "uint256"},
      {"name": "totalSupply", "type": "uint128"},
      {"name": "maxBidPrice", "type": "uint256"}
    ]}]
  }
]
```

### ContinuousClearingAuction

```json
[
  {"name": "submitBid", "type": "function", "stateMutability": "payable",
   "inputs": [{"name": "maxPrice", "type": "uint256"}, {"name": "amount", "type": "uint128"}, {"name": "owner", "type": "address"}, {"name": "hookData", "type": "bytes"}],
   "outputs": [{"name": "bidId", "type": "uint256"}]},
  {"name": "exitBid", "type": "function", "stateMutability": "nonpayable",
   "inputs": [{"name": "bidId", "type": "uint256"}], "outputs": []},
  {"name": "exitPartiallyFilledBid", "type": "function", "stateMutability": "nonpayable",
   "inputs": [{"name": "bidId", "type": "uint256"}, {"name": "lastFullyFilledCheckpointBlock", "type": "uint64"}, {"name": "outbidBlock", "type": "uint64"}], "outputs": []},
  {"name": "claimTokens", "type": "function", "stateMutability": "nonpayable",
   "inputs": [{"name": "bidId", "type": "uint256"}], "outputs": []},
  {"name": "claimTokensBatch", "type": "function", "stateMutability": "nonpayable",
   "inputs": [{"name": "owner", "type": "address"}, {"name": "bidIds", "type": "uint256[]"}], "outputs": []},
  {"name": "bids", "type": "function", "stateMutability": "view",
   "inputs": [{"name": "bidId", "type": "uint256"}],
   "outputs": [{"type": "tuple", "components": [
     {"name": "startBlock", "type": "uint64"}, {"name": "startCumulativeMps", "type": "uint24"},
     {"name": "exitedBlock", "type": "uint64"}, {"name": "maxPrice", "type": "uint256"},
     {"name": "owner", "type": "address"}, {"name": "amountQ96", "type": "uint256"},
     {"name": "tokensFilled", "type": "uint256"}
   ]}]},
  {"name": "clearingPrice", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
  {"name": "floorPrice", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
  {"name": "tickSpacing", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
  {"name": "endBlock", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint64"}]},
  {"name": "claimBlock", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint64"}]},
  {"name": "nextActiveTickPrice", "type": "function", "stateMutability": "view", "inputs": [], "outputs": [{"type": "uint256"}]},
  {"anonymous": false, "name": "BidSubmitted", "type": "event",
   "inputs": [{"indexed": true, "name": "id", "type": "uint256"}, {"indexed": true, "name": "owner", "type": "address"}, {"indexed": false, "name": "price", "type": "uint256"}, {"indexed": false, "name": "amount", "type": "uint128"}]},
  {"anonymous": false, "name": "BidExited", "type": "event",
   "inputs": [{"indexed": true, "name": "bidId", "type": "uint256"}, {"indexed": true, "name": "owner", "type": "address"}, {"indexed": false, "name": "tokensFilled", "type": "uint256"}, {"indexed": false, "name": "currencyRefunded", "type": "uint256"}]},
  {"anonymous": false, "name": "TokensClaimed", "type": "event",
   "inputs": [{"indexed": true, "name": "bidId", "type": "uint256"}, {"indexed": true, "name": "owner", "type": "address"}, {"indexed": false, "name": "tokensFilled", "type": "uint256"}]}
]
```

---

## Error Reference

| Error | Meaning |
|---|---|
| `AuctionNotStarted` | Block < `startBlock` |
| `AuctionIsOver` | Tried to bid after `endBlock` |
| `AuctionIsNotOver` | Tried to exit before `endBlock` |
| `AuctionSoldOut` | All tokens already allocated |
| `BidAlreadyExited` | `exitedBlock > 0` — already exited |
| `CannotExitBid` | Wrong exit function (e.g. `exitBid` on an outbid position) |
| `CannotPartiallyExitBidBeforeEndBlock` | Called `exitPartiallyFilledBid` while auction active |
| `CannotPartiallyExitBidBeforeGraduation` | Auction ended but not yet graduated |
| `ClaimBlockNotReached` | Block < `claimBlock` |
| `NothingToClaim` | `tokensFilled == 0` |
| `CheckpointFailed` | Query contract internal error — underlying checkpoint call reverted |
| Insufficient value | `msg.value` < `amount` on `submitBid` |
| Price not multiple of tickSpacing | Reverts — align price to tick before submitting |
