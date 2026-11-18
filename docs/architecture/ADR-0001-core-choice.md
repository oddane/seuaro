# ADR-0001: Core Protocol Strategy

**Decision:** Conditional adoption of a minimal Sui-derived independent network built **only from P3 (proven) components** as defined in [PROVEN-TECHNIQUES.md](PROVEN-TECHNIQUES.md). Freeze this decision only after a 2–4 week technical and legal feasibility spike.
**Alternatives:** (A) original PoW BlockDAG inspired by Kaspa; (B) Sui/Mysticeti-derived BFT PoS + Move; (C) Aptos-derived BFT PoS + Move; (D) purpose-built applications on an existing L1; (E) CometBFT + Cosmos SDK chain.

## Why option B is provisional
- Mysticeti, Move and checkpoint certification all meet the P3 bar (Sui mainnet since 2023; Mysticeti since Aug 2024).
- Every 2026 Sui incident (Jan consensus divergence; three May upgrade halts) ended in a **safe halt**: no fork, no lost funds. That is the failure mode we want. The causes were narrow and are reproducible as regression tests.
- Move enforces asset typing and supports formal specification; it does not prevent business-logic mistakes.
- Hard tradeoff: **not PoW**, and requires honest disclosure of validator/stake trust assumptions.
- Formal-method caveat: research shows liveness sensitivity of Mysticeti to round-jumping and proves a modified variant. Proofs of models are not proofs of an installed binary.
- Option E is the most mature BFT stack, but it has slower finality and no object-parallel execution. It is retained as the fallback if Phase 0 shows the Sui fork cannot be maintained.

## Protocol layers
**Layer 0 — Host runtime:** Linux validator environment, OS hardening, reproducible builds, time sync, network isolation, HSM-backed keys, telemetry.
**Layer 1 — BFT ordering:** pinned upstream Mysticeti; **zero** local changes to leader election, pacemaker, commit rule or garbage collection.
**Layer 2 — Deterministic execution:** Move VM, owned + shared objects, upstream gas schedule, checked arithmetic, checkpoint certification. Protocol feature set identical to Sui mainnet at the pinned version ([ADR-0008](ADR-0008-protocol-feature-set.md)); Seuaro packages do not depend on address balances or randomness until they reach P2.
**Layer 3 — Application packages (Move):** payments, merchant escrow, multisig accounts, fee sponsorship, zkLogin onboarding; each separately audited and Move-Prover-checked; each has a turnstile and outflow cap.
**Layer 4 — Compute marketplace:** deterministic job spec, escrow, result commitment, optimistic challenge window, replay verification (Tier R); capped zkVM proofs (Tier Z); TEE data as metadata only.
**Layer 5 — Interfaces:** SDK, gRPC, indexer, explorer, wallets, light-client checkpoint and committee verification, merchant checkout APIs.
**Layer 6 — Deferred extensions:** shielded pool, native ML-DSA accounts, IBC-style light-client bridge. Each enters mainnet only when its register entry reaches the required level.

## Core transaction lifecycle
1. Wallet builds a **domain-separated** transaction including chain id, protocol version, expiry, object refs, gas budget and authentication.
2. Node validates encoding, resource budgets, signature, ownership and balance before admission.
3. Validators order transactions under the pinned consensus rules.
4. Deterministic execution applies state transitions; any execution error aborts **that transaction only**, identically on all validators (EXEC-04).
5. A quorum certificate over effects/checkpoint proves finality; clients never treat RPC acceptance as settlement.
6. Indexed data is for search only and never substitutes for cryptographic proofs.

## Economics and decentralization
- Reuse the upstream gas, storage-fund and reference-gas-price mechanisms unchanged until simulations justify a change (each change is P0 by definition).
- Do not fix fee levels, inflation, validator minimums or supply before economic simulation and legal assessment.
- Publish insider allocations and emissions; apply stake concentration caps.
- A founder-controlled 4–7 validator network is a **permissioned prototype**, not a decentralized mainnet.

## Required non-goals for v1
- New cryptographic primitives, consensus algorithms or P0 components in the value path.
- Claims of "zero flaws", instant universal finality, unlimited TPS, full privacy or a quantum-proof stack.
- Trustless correctness proofs for arbitrary non-deterministic AI outputs.
- Any bridge other than a light-client design, and no bridge at all before mainnet stability.
- AI-driven self-modifying consensus.

## Open ADRs required by gate G0
| ADR | Topic | Status |
|---|---|---|
| ADR-0002 | Native asset, supply, emissions | Open |
| ADR-0003 | Gas/fee economics and spam pricing | Open |
| ADR-0004 | Validator admission and stake caps | Open |
| ADR-0005 | Upgrade authorization, timelocks, emergency halt | Open |
| ADR-0006 | Payment settlement semantics and merchant finality UX | Open |
| ADR-0007 | Compute verification tiers and caps | Open |
| ADR-0008 | Protocol feature set (Sui mainnet's, via chain override) | **Accepted** |

## Dissent / go-no-go
Reject this fork if divergence from upstream delays security patches, if validator costs make decentralization unrealistic, or if the product can be delivered more safely as Move packages on an existing network. A standout application can matter more than owning consensus.
