# ADR-0003: Fees, Gas Pricing and Sponsorship

**Status:** Proposed (2026-11-18).

## Context
- Payment users should never need to hold SEU. Requiring a volatile gas token is what Tempo, Arc, Plasma and Sui's gasless transfers all set out to remove.
- Fees that float with the token's price hurt users: Tron's USDT transfer cost rose about 2.6× as TRX rallied, until governance cut prices.
- "Free" transfers that a project quietly subsidizes (Plasma) end when the subsidy does.
- Inventing a new fee mechanism makes it P0 under PROVEN-TECHNIQUES.md.

## Decision

### 1. Protocol fees: upstream Sui gas model, unchanged
- **Computation fee** = gas units × **reference gas price (RGP)**. Each epoch every validator quotes its minimum acceptable price; the protocol takes the 2/3 percentile by stake. Validators that quote low and honor the price earn boosted rewards; those that don't are penalized.
- **Storage fee** is paid up front into the **storage fund**. Deleting data returns most of it (the non-refundable share stays in the fund), so storage never becomes unfunded.
- **No burn.** Computation fees and storage-fund rewards go to validators and stakers.
- **Price drift control.** Because the RGP is re-quoted every epoch (24 h), validators can follow SEU's market price within a day. Seuaro's validator policy (ADR-0004 delegation criteria) asks validators to re-quote whenever SEU moves ±20%. That is the same discipline Sui operators follow, and it stops Tron-style fee creep without new code.

### 2. Who pays: sponsors, not users
- Payments use Sui **sponsored transactions** (P3): the payer signs the payment, and a sponsor signs and pays the gas.
- **Seuaro Pay gas station** (to build, Phase 3): an off-chain service that sponsors eligible transactions (stablecoin transfers, invoice payments, escrow actions), funded from a turnstile-capped `vault` (LEDGER-05):
  - Merchants and apps fund their own sponsor vaults and pay their customers' gas. They see the cost; it is never hidden.
  - For the first 24 months the ecosystem reserve co-funds a public vault capped at **5M SEU per epoch**, with per-address daily limits (e.g. 50 sponsored transactions) to stop farming.
- **Target user experience:** $0.00 visible fee for stablecoin payments. **Target merchant cost:** under $0.001 per payment at expected RGP and SEU prices, measured on testnet before launch (benchmark W2).

### 3. Spam resistance
- Unsponsored transactions pay the RGP like on Sui. Sponsored ones are rate-limited by the gas station, and the vault cap bounds what any abuse can cost.
- Under load, transactions with higher gas prices get priority (upstream behavior), so attackers pay market rates.

## Consequences
- The fee unit on-chain stays SEU. Dollar-denominated gas at the protocol level (Tempo, Arc) is **not** adopted: it needs a protocol change and a price feed, both P0. Sponsorship gives users the same experience.
- Sponsorship costs show up as a line item for merchants, and as a published budget for the foundation.
- Open items: gas-station service (Rust, Phase 3), merchant pricing tiers, and W2 benchmark numbers that prove the < $0.001 target.
