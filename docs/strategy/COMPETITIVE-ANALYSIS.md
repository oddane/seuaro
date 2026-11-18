# Competitive Analysis and Fixes (v0.5, 2026-11-18)

Seuaro competes in two markets: **stablecoin payments** and **settlement of AI compute**. This document records what the leading competitors use, where they have failed in public, and what Seuaro does about each failure. Each fix is marked **Built** (in this repository), **Policy** (written rule with a check) or **Planned** (needs a decision or partner).

## 1. Who we are up against

| Competitor | Stack | Key choices |
|---|---|---|
| **Tron** | DPoS, 27 Super Representatives, TVM | Dominant USDT rail; fees paid via staked "energy" or burned TRX |
| **Solana** | Alpenglow (since Oct 2026), Sealevel | High throughput; large validator set; ~150 ms finality *target* |
| **Sui** (our upstream) | Mysticeti, Move objects | Gasless stablecoin transfers since May 2026 (address balances) |
| **Tempo** (Stripe/Paradigm) | Reth EVM, Simplex BFT | Mainnet Mar 2026; fees in stablecoins; TIP-20 with payment memos; permissioned validators (Stripe, Visa, Zodia) |
| **Arc** (Circle) | EVM, Malachite BFT | Mainnet Sep 2026; USDC as gas; opt-in privacy announced but not shipped; institutional validators |
| **Plasma / Stable** (Tether orbit) | EVM, BFT | Zero-fee USDT funded by a protocol paymaster |
| **Bittensor** | Subtensor, Yuma consensus | Validators score miners; rewards follow consensus |
| **io.net / Akash / Render** | GPU marketplaces | Pay for supplied hardware; trust the provider's output |
| **Gensyn** | Verde / RepOps | Refereed delegation over bitwise-reproducible ML |

## 2. Their flaws and Seuaro's fixes

### Payments

| # | Flaw seen in the market | Evidence | Seuaro fix | Status |
|---|---|---|---|---|
| P1 | **Fees float with a volatile token.** On Tron, USDT transfer costs rose from about $1.64 to $4.28 as TRX rallied, until a governance vote cut energy prices. | Tron fee-cut coverage (Aug 2025) | Users never need the native coin: merchants or apps sponsor gas using Sui's **sponsored transactions** (P3). A sponsor budget is a turnstile-capped `vault`, priced in stablecoins by the sponsor. No new fee mechanism is invented. | Built (vault), Planned (gas-station service) |
| P2 | **"Free" transfers paid by a subsidy.** Plasma's zero-fee USDT is funded by the project, not by the fee model, which raises sustainability questions. | Plasma analyses (2025–26) | Whoever sponsors pays. Sponsorship is explicit, budgeted per epoch and visible on-chain, so "free" can't silently run out. | Built (vault caps) |
| P3 | **Gasless built on brand-new accounting.** Sui's gasless stablecoins rely on address balances, the same feature whose gas logic halted Sui mainnet three times in May 2026. Its allowlist is also hard-coded to Sui-mainnet stablecoins. | Sui gasless launch (May 2026); Sui incident review | Seuaro does not rely on address balances (P1 in our register) until they have a clean year. Sponsorship (P3) gives the same user experience today. | Policy (ADR-0008) |
| P4 | **Reconciliation data missing.** Payment teams need invoice IDs on transfers; Tempo added memos at the token-standard level. | Tempo TIP-20 docs | `invoice` module: memo payments, exact-amount single-use invoices, payer receipts, refunds capped at the paid amount and sent only to the payer (PAY-02). Ordinary Move, no protocol change. | **Built** |
| P5 | **Permissioned or tiny validator sets.** Tron has 27 producers, with a Nakamoto coefficient of about 3–4. Tempo and Arc launched with hand-picked corporate validators. | Tron governance analyses; Tempo/Arc launches | Open validator admission (Sui's stake-based joining, P3) plus hard concentration limits per operator, ASN and provider, checked every epoch (ADR-0004, DEC-01). | **Built** (report), Policy |
| P6 | **Chains launched before anyone used them.** Stable traded at a ~$2.5B valuation with $0 of DEX volume on-chain. | Stable coverage (Mar–May 2026) | No token or public launch before real merchant flows run on testnet (LAUNCH-GATES G4). The ADR-0001 dissent stands: if a payments app on an existing chain wins, ship that. | Policy |
| P7 | **No stablecoin, no payments chain.** Every successful rail rides an issuer's stablecoin. | Market structure | Seuaro needs a regulated issuer that issues natively with Sui's regulated-coin framework (issuer-controlled deny lists, used by USDC on Sui). Bridged stablecoins wait for the light-client bridge. | **Planned: biggest open business risk** |

### Reliability and decentralization

| # | Flaw | Evidence | Seuaro fix | Status |
|---|---|---|---|---|
| R1 | **Data-center concentration.** A routing failure at one provider took ~29% of Solana stake offline in Aug 2026, 4.5 points from a finality halt; one ASN held 27%. | Solana incident reports (Aug 2026) | ADR-0004 limits: ≤25% of voting power per ASN or provider and ≤15% per operator. Validators must disclose infrastructure; undisclosed stake counts as a violation. `decentralization-report.py --enforce` runs every epoch. | **Built** |
| R2 | **Upgrades that halt the chain.** Sui's v1.72 rollout caused three halts in 48 hours. | Sui post-mortem (May 2026) | One risky flag per release (GOV-03); ≥ 8 weeks on Sui mainnet before adoption; fault tests in CI. | Built / Policy |
| R3 | **Spam and fee-market failure.** High-throughput chains have suffered congestion collapses. | Industry history | Upstream reference-gas-price and owned-object fast path; W4 adversarial benchmark is a launch gate. | Policy |

### AI compute

| # | Flaw | Evidence | Seuaro fix | Status |
|---|---|---|---|---|
| C1 | **Vote copying.** Bittensor validators copy other validators' public weights instead of evaluating, and still earn rewards. Bittensor added commit-reveal to stop it. | Bittensor docs on weight copying | Our verifiers had the same hole: votes were public as they were cast. Now **commit-reveal**: verifiers commit to blake2b(result ‖ salt ‖ own address) and reveal only after the commit window. Copied commitments cannot be revealed (COMP-04). | **Built** |
| C2 | **Paying for claimed hardware.** io.net was flooded with spoofed GPUs farming rewards. | io.net post-mortem (Apr 2024) | Seuaro never pays for capacity or uptime claims, only for results that pass the challenge window or a verifier quorum. A provider bond is forfeited on a failed job, so fake providers lose money. | Built (design) |
| C3 | **Wrong outputs nobody can detect.** Corrupted renders were reportedly returned on Render with no on-chain way to catch them; the field relies on trusting operators. | Cointelegraph op-ed (Mar 2026) | Replay verification by independent verifiers, with an optimistic window; TEE attestation never pays on its own (COMP-03). | Built |
| C4 | **Replay only works if execution is deterministic.** Gensyn needed bitwise-reproducible operators (RepOps) to make refereed delegation work. | Gensyn Verde paper | The job `spec_hash` must commit to a pinned container image and a deterministic runtime. Non-deterministic jobs (most LLM sampling) are out of scope for Tier R. | Policy (ADR-0007) |
| C5 | **Few validators control the rewards.** Bittensor's top 64 validators control all emissions. | Bittensor analyses (Apr 2026) | Clients choose their own verifier set; the quorum must be a strict majority, and verifiers can't be the client or provider. | Built |

## 3. Where competitors are ahead (honest gaps)

- **Distribution.** Tempo has Stripe and Visa; Arc has USDC and BlackRock. Seuaro has neither. Technology does not fix this (see P6, P7).
- **EVM compatibility.** Tempo, Arc, Plasma and Stable all run Solidity. Seuaro uses Move, which is safer for assets but has a smaller developer pool.
- **Native stablecoin gas.** Tempo and Arc price gas in dollars at the protocol level. Seuaro gets the same user experience through sponsorship, but the network's own fee unit is still the native coin.
- **Privacy.** Arc has announced opt-in confidential transfers but not shipped them; Seuaro defers privacy until a circuit is back at P3. Neither has it in production.

## 4. Recommended next steps, in order

1. **Secure a stablecoin issuer** (P7). Without it, the payments thesis fails regardless of engineering.
2. **Gas-station service** for sponsored transactions funded from a turnstile vault (P1/P2).
3. **ADR-0002/0003**: coin name, supply and fee policy, informed by P1/P2.
4. **Recruit independent validators** that meet ADR-0004 across at least 5 ASNs before any public testnet.
5. **Deterministic job runtime spec** for compute (C4), then a pilot with one real workload.

## Sources
Tron fees: https://www.tradingview.com/news/cryptonews:313497305094b:0-tron-votes-to-slash-network-fees-60-to-defend-stablecoin-dominance/ ·
Tron governance: https://coinclear.pages.dev/layer1/tron ·
Solana Aug 2026 incident: https://infstones.com/blog/industry_infrastructure/solana-outage-exposes-data-center-concentration-risk , https://coingape.com/solana-dodges-finality-halt-as-15-of-validators-go-offline/ ·
Sui gasless: https://www.sui.io/blog/sui-launches-gasless-stablecoin-transfers.md , https://forklog.com/en/sui-introduces-fee-free-stablecoin-transfers/amp/ ·
Tempo: https://everstake.one/resources/blog/what-is-tempo-stripe-and-paradigms-stablecoin-payments-blockchain-explained , https://docs.blockdaemon.com/docs/getting-started-with-tempo.md , https://thedefiant.io/news/blockchains/tempo-onboards-visa-stripe-and-zodia-custody-as-validators ·
Arc: https://www.circle.com/es/pressroom/circle-launches-arc-mainnet-an-economic-operating-system-for-the-internet , https://www.theblock.co/news/ecosystems/2026-09-16-circle-launches-arc-mainnet-with-blackrock-and-visa-among-validators-mints-10-billion-arc-tokens-415250 ·
Plasma: https://blockeden.xyz/blog/2025/11/25/plasma-blockchain/ , https://eco.com/support/en/articles/11802920-what-is-plasma-xpl-the-bitcoin-secured-blockchain-built-for-stablecoin-infrastructure ·
Stable: https://blockeden.xyz/blog/2026/05/07/stable-l1-2-5b-fdv-zero-dex-volume-stablecoin-chain/ ·
Bittensor: https://docs.learnbittensor.org/concepts/weight-copying-in-bittensor , https://yellow.com/research/bittensor-decentralized-ai-market-control-2026 ·
io.net: https://www.theblock.co/post/291315/solana-based-depin-io-net-ceo-claims-network-was-attacked-in-detailed-postmortem ·
Compute verification: https://cointelegraph.com/news/decentralized-compute-has-failed , https://blog.gensyn.ai/verde-verification-system-in-production/
