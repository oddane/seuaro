# Seuaro Protocol v0.4.1 — Design Docs

**Prepared:** 2026-11-18
**Status:** Research architecture / proposed implementation plan. **Not built, audited or tested, not secure by assertion, and not ready for mainnet.**

## Mission
Build a high-assurance independent Layer 1 for accessible payments, developer-friendly parallel applications and settlement of decentralized compute, **using only proven techniques**. Compete on independently measured outcomes, not unverified claims.

## What's new in v0.4
- **Proven-only rule:** every component carries a maturity level (P0–P3) in [PROVEN-TECHNIQUES.md](architecture/PROVEN-TECHNIQUES.md). Mainnet value paths use P3 only.
- **Bounded blast radius:** a turnstile and outflow cap on every value pool, so a bug in a proven component can only drain a capped amount.
- **Fail per transaction, not per network:** execution errors abort one transaction instead of halting the chain.
- **Smaller launch surface:** privacy, bridges and native PQ accounts are off until they reach the required level. The protocol runs exactly Sui mainnet's feature set ([ADR-0008](architecture/ADR-0008-protocol-feature-set.md)); Seuaro packages avoid features below P2, such as address balances and randomness.
- **Lessons from 2026 incidents** (Sui halts, Zcash Orchard flaw, zkVM and TEE breaks) are built in as regression tests and design rules.
- Fixes from the v0.3 review: separate performance environment (L0P), Phase 1 now gates LEDGER-04 and API-01, one severity rule everywhere, threat model extended (ordering, committee hand-off, censorship, AI-accelerated attackers), open ADR list. See [CHANGELOG.md](CHANGELOG.md).

## Chosen starting architecture (subject to Phase 0)
- **Core:** pinned upstream Sui release (Mysticeti + Move), lagging upstream by ≥ 8 weeks except security patches; distinct genesis, network identity, validator set and upgrade process; zero local consensus changes.
- **Payments:** owned-object transfers, multisig, sponsored gas, zkLogin and passkey onboarding, audited Move escrow.
- **AI compute:** off-chain marketplace, deterministic tasks; escrow plus optimistic challenge; replay verification first, capped zkVM proofs second; TEE attestation is metadata, never a payout trigger.
- **Privacy:** none on mainnet at launch; any future shielded pool must be formally verified and turnstiled.
- **Post-quantum:** crypto-agile accounts; ML-DSA-65 and SLH-DSA vaults on testnet; no "quantum-safe chain" claims.
- **Bridges:** none at launch; later, light-client (IBC-style) designs only.

## Foundational security assumptions
- BFT safety/liveness depends on the protocol's adversary threshold (< 1/3 stake) and eventual synchrony.
- All validator-executed state transitions are deterministic.
- Settlement requires a verifiable quorum certificate; a block proposal or RPC acknowledgement is not finality.
- A long partition may halt liveness. Safety takes precedence over processing writes.
- "Proven" lowers risk; it does not remove it. No benchmark or proof shows that all vulnerabilities have been found.

## Contents
1. [Proven-techniques policy and register](architecture/PROVEN-TECHNIQUES.md) *(new)*
2. [Architecture / ADR-0001](architecture/ADR-0001-core-choice.md)
3. [Security invariants](security/INVARIANTS.md)
4. [Threat model](security/THREAT-MODEL.md)
5. [Benchmark methodology](benchmarks/MEASUREMENT-PROTOCOL.md)
6. [Launch gates](operations/LAUNCH-GATES.md)
7. [Build sequence](delivery/IMPLEMENTATION.md)
8. [Sources](SOURCES.md)
9. [Changelog](CHANGELOG.md) *(new)*
10. [ADR-0008: protocol feature set](architecture/ADR-0008-protocol-feature-set.md)
11. [Fork-delta register](architecture/FORK-DELTA.md)

## Immediate first milestone
A four-validator **local devnet only**, running an upstream tagged Sui release with unmodified consensus and Move execution, Sui mainnet's protocol feature set (ADR-0008), an independent genesis, test transactions, a reproducible build, the 2026 incident regressions and deterministic CI. No public token, mainnet or customer deposits.
