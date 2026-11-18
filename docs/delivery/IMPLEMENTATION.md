# Engineering Delivery Plan

## Phase 0 — Architecture spike (2–4 weeks)
**Output:** fork-vs-existing-chain decision (options B, D, E compared); threat model; pinned upstream tag that has run ≥ 8 weeks on Sui mainnet without a related incident; first full pass of the proven-techniques register; regression matrix; license review; workload spec; approved budget.
**Gate:** show value that requires a new chain rather than Move packages on an existing one. Record upstream-maintenance cost and security risks.

## Phase 1 — Minimal independent devnet (4–8 weeks after spike)
**Output:** separate genesis/chain id; 4-validator cluster (L0) and 4-machine baseline (L0P); native test token; signed transactions (Ed25519, multisig); a Move contract; finality-receipt verification in a minimal client; scripted startup; state-root comparison. Protocol feature set identical to Sui mainnet (ADR-0008).
**Gate:** CONS-01, CONS-02, LEDGER-01, LEDGER-02, LEDGER-04, AUTH-01, EXEC-01, STORE-01, API-01; reproducible build; Jan/May 2026 Sui regressions reproduce on the unpatched tag and pass on the pinned one.

## Phase 2 — Hardened network (additional 2–4 months)
**Output:** 15+ geo-distributed validators; protected public RPC; wallet/SDK with checkpoint and committee verification; explorer; multi-region load generation; snapshot restore; deterministic simulation suite in CI; TLA+ models for commit and reconfiguration; independent core audit; zero local consensus changes.
**Gate:** Phase 2 invariants (see INVARIANTS.md phase mapping); W1–W5 and W7; zero halts in W4/W7; rollback-safe upgrades.

## Phase 3 — Product differentiation with proven parts (additional 3–6 months)
**Output:**
- Payments: owned-object transfers, merchant escrow with refunds and arbitration, sponsored gas with per-sponsor budgets, zkLogin and passkey onboarding with multisig recovery.
- Compute: job escrow with optimistic challenge window, replay verification (Tier R), capped zkVM proofs (Tier Z), TEE data as metadata only, provider reputation with Sybil controls.
- Turnstile and outflow caps on every pool, with live monitoring.
- Testnet-only, behind flags: ML-DSA-65 accounts, SLH-DSA vault contract, shielded-pool prototype.
**Gate:** Phase 3 invariants; economic and contract audits; realistic merchant workflow with measured costs; compute fraud tests including forged zkVM proofs and forged attestations.

## Phase 4 — Security-led release candidate (duration set by evidence)
**Output:** formal proofs where tractable; independent performance reproduction; operator diversity; public bounty; incident and emergency-patch drills; 30+ day clean soak after the last consensus-, gas- or accounting-affecting change; residual-risk disclosure listing every component's register level.
**Gate:** every item in LAUNCH-GATES.md passes; otherwise do not ship to real value.

## Recommended first hires / functions
- Senior distributed-systems / BFT consensus lead.
- Rust core engineer (networking and storage).
- Move smart-contract and formal-methods engineer (Move Prover, TLA+).
- SRE/security engineer for CI, keys, validator ops and disaster recovery.
- Independent cryptography and adversarial audit partners, including AI-assisted review.
- Payments/developer-tooling engineer once the first devnet works.

## First 12 issues to create
1. Pin an upstream Sui release; record dependencies, license and security advisories.
2. Fill in the proven-techniques register for every dependency in the pinned tree.
3. Write threat assumptions and the consensus safety/finality model.
4. Build the 4-validator network with separate genesis and chain id, running Sui mainnet's feature set (ADR-0008).
5. Add deterministic validator start/restart scripts.
6. Implement checkpoint and committee hand-off verification in a minimal client.
7. Write property tests for supply, fees, cancellation (including multiple reasons) and concurrent spending.
8. Reproduce the Jan/May 2026 Sui incidents in deterministic simulation as regression tests.
9. Add network fault injection (partition, delay, reorder, crash, restart during epoch change).
10. Define the public, reproducible W1–W7 benchmark harness.
11. Design the turnstile/outflow-cap Move module shared by all value pools.
12. Publish the code-delta register, security-review process and disclosure policy.

## Development rules
- Never modify consensus while adding an application feature.
- Two reviewers for consensus, signatures, serialization, gas, snapshots, checkpoints and upgrade code.
- One consensus-, gas- or accounting-affecting change per release (GOV-03).
- Any component not in the register is P0 and stays out of mainnet.
- Treat AI-generated patches as untrusted submissions subject to tests and expert review.
- Never place real private keys or production seeds into LLM prompts, tickets, logs or fixtures.
- Watch upstream security advisories; triage within 24 h.
