# ADR-0002: Native Asset — Seuaro (SEU)

**Status:** Proposed (2026-11-18). Not legal, tax or investment advice. Distribution, any sale and the token's classification need review by counsel in each target jurisdiction before anything below is offered to anyone (LAUNCH-GATES G4).

## Decision summary
| Item | Value |
|---|---|
| Name / ticker | **Seuaro / SEU** |
| Smallest unit | 1 SEU = 1,000,000,000 base units (9 decimals, as upstream) |
| Total supply | **10,000,000,000 SEU, fixed, all created at genesis, never increased** |
| New issuance | None. Staking rewards come from a pre-funded, decaying Stake Subsidy Fund plus fees |
| Fee burn | None at launch (see ADR-0003) |
| Not a stablecoin | SEU floats. Dollar payments use issuer stablecoins (COMPETITIVE-ANALYSIS P7) |

## Why these numbers
- **10B fixed supply** is the value hard-coded in the pinned Sui release (Rust and Move). Keeping it means **zero code changes**, so the supply logic stays the proven one. It is also the market norm for this class of chain: Sui, Plasma and Arc all start at 10B.
- **No perpetual inflation.** Plasma (5% → 3%) and Arc (2–3%) mint new tokens forever to pay validators. Seuaro follows Sui instead: the security budget is set aside at genesis and runs down as fees take over, so the total can never exceed 10B. That is simpler to explain to payment partners and regulators.
- **No burn at launch.** Burns only offset inflation, and Seuaro has none. Plasma also shows the trap: its zero-fee stablecoin transfers bypass the burn that was meant to offset its emissions.

## Allocation (10,000,000,000 SEU)
| Bucket | Share | SEU | Unlock | Purpose |
|---|---|---|---|---|
| Ecosystem reserve | 40% | 4.0B | Foundation-managed; ≤ 10% of the bucket released per year, published quarterly | Validator delegation program (bootstraps independent validators under ADR-0004), developer grants, merchant onboarding, gas-sponsorship budgets |
| Stake Subsidy Fund | 10% | 1.0B | Protocol-controlled; paid per epoch, decaying (below) | Validator and staker rewards while fees are small |
| Contributors | 20% | 2.0B | 1-year cliff, then monthly over 3 years | Team and early contributors |
| Investors | 15% | 1.5B | 1-year cliff, then monthly over 2 years | Only if a raise happens; unused share returns to the ecosystem reserve |
| Foundation treasury | 10% | 1.0B | Linear over 5 years | Operations, audits, bug bounty, legal |
| Community distribution | 5% | 0.5B | At mainnet, tied to verified usage | Testnet merchants and users, anti-Sybil checked; no public sale at launch |

Insiders (contributors + investors) hold 35%, close to Sui's early-contributor and investor share and below Plasma's 50%. Locked contributor and investor tokens stay in vesting contracts and **do not earn staking rewards** until they unlock (Plasma follows the same rule).

All foundation-held buckets sit in hardware-backed multisig (4-of-7), with a 7-day timelock on any transfer above 1M SEU and a public quarterly report.

## Staking rewards schedule (genesis ceremony parameters; no code change)
| Parameter | Value | Upstream default |
|---|---|---|
| `stake_subsidy_start_epoch` | 0 (mainnet requires ADR-0004 compliance before genesis anyway) | 0 |
| `stake_subsidy_initial_distribution_amount` | 1,000,000 SEU per epoch | 1,000,000 |
| `stake_subsidy_period_length` | 90 epochs (one quarter at 24 h epochs) | 10 |
| `stake_subsidy_decrease_rate` | 10% per period | 10% |
| `epoch_duration_ms` | 24 h (testnets 30 s – 1 h) | 24 h |

Resulting subsidy: about **310M SEU in year 1 (3.1% of supply)**, ~203M in year 2, ~133M in year 3, ~57M in year 5. The 90-epoch period (vs. upstream's 10) gives validators a slow, predictable decline instead of a fast cliff. The geometric total is 900M; the last 100M of the fund stays as a tail reserve. By year 5, fee income has to carry validator economics. Pricing that (ADR-0003) is a launch gate.

## Validators
- Minimum stake to join, commission and reward distribution stay at the upstream values: join at 30M SEU (0.3% of supply); commission 2% by default and set by each validator.
- Penalties stay upstream: misbehaving validators lose rewards through the tallying rule, not principal.
- The ecosystem reserve's delegation program stakes with validators only within ADR-0004 concentration limits.

## Implementation status
- **Testnet genesis** (`docker/entrypoint.py`) now uses these buckets and subsidy parameters, scaled for a 4-validator network.
- **On-chain display name.** Wallets read the coin's name and symbol from metadata compiled into Sui's framework (`sui.move`: "Sui"/"SUI"). Changing it to "Seuaro"/"SEU" is a framework source change plus recompiled system bytecode. It is planned as FORK-DELTA D9 for Phase 2 with two reviewers, upgrade tests and a check that the type path `0x2::sui::SUI` stays unchanged. Until then the explorer and docs show SEU; the CLI still prints SUI.
