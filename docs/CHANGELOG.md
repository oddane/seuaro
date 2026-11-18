# Changelog

## v0.4.1 — 2026-11-18
- Added ADR-0008 (protocol feature set) and FORK-DELTA.md after inspecting the pinned upstream source.
- Pinned upstream: `mainnet-v1.79.1`.
- Phase 1 implementation lives in this repository (`scripts/`, `tools/seuaro-verify`, `tests/phase1.sh`).

## v0.4 — 2026-11-18
### Added
- `architecture/PROVEN-TECHNIQUES.md`: maturity levels P0–P3, usage rules by environment, downgrade rule, and a register covering consensus, execution, accounts, post-quantum, privacy, compute verification, bridges and engineering methods.
- Invariants CONS-05 (committee hand-off), LIVE-01 (inclusion bound), LEDGER-05 (turnstile/outflow caps), EXEC-04 (fail per transaction), GOV-03 (one risky flag per release), COMP-03 (zkVM caps; TEE never pays alone). Phase-to-invariant mapping table.
- Threat-model adversaries: ordering exploiter, light-client deceiver, AI-accelerated attacker. Fix-of-a-fix and forged-proof scenarios.
- Benchmark workload W7 (upgrade/epoch change under load); halt-count metric; L0P performance environment.
- Launch gates: register compliance, turnstile monitoring, zero halts in W4/W7, emergency-patch drill, feature-enablement table.
- ADR-0001: alternative E (CometBFT) as fallback; list of open ADR-0002 to ADR-0007.
- Mandatory regressions for the Zcash Orchard (CVE-2026-54496) and zkVM soundness bug classes; the May 2026 Sui underflow split into its two variants.

### Changed
- Address balances and on-chain randomness kept out of Seuaro packages. *(Amended by ADR-0008: the protocol itself runs Sui mainnet's feature set.)*
- Upstream lag policy: ≥ 8 weeks on Sui mainnet before adoption, except security patches.
- TEE attestation downgraded to metadata only.
- Phase 1 gate now includes LEDGER-04 and API-01.
- Single severity rule ("no unresolved critical or high-severity findings in release scope") in both the benchmark and launch-gate documents.
- First-issues list expanded from 10 to 12.
- SOURCES: Solana link replaced with the official Alpenglow status page; 2026 incident and vulnerability sources added; each entry marked as checked [V] or carried over [C].

### Fixed
- v0.3 set a performance target on L0, which it also described as "correctness only". Performance targets now apply to L0P and above.
