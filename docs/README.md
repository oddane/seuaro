# Seuaro Documentation

Design documents are versioned with the code. Every decision has an ADR, every security property has an invariant, and every launch requirement has a gate.

## Read in this order
1. **[Architecture](ARCHITECTURE.md)**: layers, build pipeline, transaction lifecycle, verification, genesis, contracts.
2. **[Proven-techniques policy](architecture/PROVEN-TECHNIQUES.md)**: the P0–P3 maturity levels every component is graded on.
3. **[Threat model](security/THREAT-MODEL.md)** and **[invariants](security/INVARIANTS.md)**: what can go wrong and what must always hold.
4. **[Launch gates](operations/LAUNCH-GATES.md)**: the blockers between testnet and mainnet.

## Architecture decision records
| ADR | Decision | Status |
|---|---|---|
| [ADR-0001](architecture/ADR-0001-core-choice.md) | Core: pinned upstream Mysticeti + Move, minimal fork | Conditional |
| [ADR-0002](architecture/ADR-0002-native-asset-seu.md) | Native asset Seuaro (SEU): supply, allocation, staking rewards | Proposed |
| [ADR-0003](architecture/ADR-0003-fees-and-sponsorship.md) | Fees, gas pricing and sponsorship | Proposed |
| [ADR-0004](architecture/ADR-0004-validator-admission.md) | Validator admission and concentration limits | Accepted (testnets) |
| ADR-0005 | Upgrade authorization, timelocks, emergency halt | Open |
| ADR-0006 | Payment settlement semantics and merchant finality UX | Open |
| ADR-0007 | Compute verification tiers and caps | Open |
| [ADR-0008](architecture/ADR-0008-protocol-feature-set.md) | Protocol feature set (upstream mainnet schedule) | Accepted |

Fork changes are listed in **[FORK-DELTA.md](architecture/FORK-DELTA.md)**.

## By topic
| Topic | Documents |
|---|---|
| Security | [Threat model](security/THREAT-MODEL.md) · [Invariants](security/INVARIANTS.md) · [Security policy](../SECURITY.md) |
| Performance | [Benchmark protocol](benchmarks/MEASUREMENT-PROTOCOL.md) |
| Delivery | [Implementation plan](delivery/IMPLEMENTATION.md) · [Roadmap](../ROADMAP.md) · [Changelog](../CHANGELOG.md) |
| Strategy | [Competitive analysis](strategy/COMPETITIVE-ANALYSIS.md) |
| Legal | [License audit](legal/LICENSE-AUDIT.md) · [Counsel checklist](legal/COUNSEL-CHECKLIST.md) · [Trademarks](../TRADEMARKS.md) · [Disclaimer](../DISCLAIMER.md) |
| Research sources | [SOURCES.md](SOURCES.md) · [Design-doc changelog](CHANGELOG.md) |

## Conventions
- Invariants are named `AREA-NN` (for example `LEDGER-05`) and referenced from code, tests and gates.
- ADRs are immutable once accepted; changes come as a new ADR that supersedes the old one.
- Every factual claim about other projects links to a source in [SOURCES.md](SOURCES.md) or the document itself.
