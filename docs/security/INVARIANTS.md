# Seuaro Security Invariants — MUST HOLD

An invariant is an assertion to be modeled, tested and, where possible, machine-proved. Passing tests is evidence, not proof that no flaws remain. Each invariant names the P3 method used to verify it (see [PROVEN-TECHNIQUES.md](../architecture/PROVEN-TECHNIQUES.md) §3.8).

| ID | Invariant | Required verification |
|---|---|---|
| CONS-01 | No two conflicting effects can both obtain valid finality certificates for the same chain/epoch under the consensus fault assumptions. | TLA+ model + deterministic simulation + certificate verifier |
| CONS-02 | Same valid ordered transactions + same prior state + same protocol version produce the same state root on all honest nodes. | Differential execution + state-root comparison |
| CONS-03 | At or beyond the adversary threshold, do not promise safety/liveness beyond the modeled protocol guarantee. | Threat model / simulation |
| CONS-04 | A previously certified payment is never unilaterally reverted during restart, snapshot recovery or upgrade. | Recovery/restart/state-sync simulations |
| CONS-05 | *(new)* A light client accepts a new epoch's committee only via a certificate from the previous committee's quorum; it rejects unknown genesis or chain id. | Light-client tests across ≥ 100 simulated epochs + adversarial RPC |
| LIVE-01 | *(new)* Under the modeled synchrony assumption and < 1/3 Byzantine stake, a valid, adequately-priced transaction is included within a published bound. The bound is measured, not promised beyond the model. | Deterministic simulation + testnet inclusion-delay metrics |
| LEDGER-01 | Total native value after a transition equals previous value plus authorized issuance minus authorized burns. Fees are transferred, not created implicitly. | Formal accounting spec + property tests |
| LEDGER-02 | No balance, gas counter, reward or fee variable overflows or underflows. | Checked arithmetic + boundary fuzzing |
| LEDGER-03 | Failed, cancelled and out-of-gas operations preserve all specified state and gas semantics, **including transactions with multiple simultaneous cancellation reasons**. | Error-path fuzzing + deterministic replay |
| LEDGER-04 | At most one accepted spend of the same owned object/version; replayed transactions cannot double-spend. | Property tests + concurrency tests |
| LEDGER-05 | *(new)* **Turnstile:** cumulative outflow from every value pool (escrow, sponsorship, compute, any future shielded pool or bridge) never exceeds cumulative inflow, and per-epoch outflow never exceeds the pool's configured cap. | Move Prover + on-chain monitor + fuzz |
| AUTH-01 | A valid authorization cannot be reused across chains, epochs (when applicable) or incompatible protocol versions. | Chain-id + domain-separation tests |
| AUTH-02 | No unsigned change of owner, upgrade authority or mint/burn capability is permitted. | Formal authorization spec + tests |
| EXEC-01 | Parallel and serial execution of the same admitted ordered workload give identical committed effects. | Differential scheduler test |
| EXEC-02 | Every admitted workload has bounded CPU, memory, I/O and proof-verification cost or is safely rejected. | Resource metering + malicious-input fuzz |
| EXEC-03 | Bytecode/verifier failures cannot crash all validators or leave inconsistent persisted state. | Isolation tests, crash/restart fuzz |
| EXEC-04 | *(new)* Any error during execution or settlement of a transaction aborts that transaction (or its settlement batch) deterministically on all validators. It does not crash the node or halt the network. | Fault-injection on every arithmetic and settlement path; deterministic simulation |
| GOV-01 | Protocol upgrades require specified threshold authorization, timelock/review windows and unambiguous activation rules. | Reconfiguration tests |
| GOV-02 | Restart at an epoch transition, and randomness disabled/unavailable, are deterministic and recoverable. | Chaos tests + historical outage regressions |
| GOV-03 | *(new)* Every behavior change is gated by a protocol-version flag. No release activates more than one consensus-, gas- or accounting-affecting flag at a time. | Release checklist + activation tests |
| STORE-01 | State sync, snapshots, checkpoints, pruning and archival restoration reproduce certified state roots. | Replay comparison + disaster-recovery tests |
| NET-01 | Duplicate, malformed, reordered, withheld and oversized messages cannot cause unbounded amplification or persistent inconsistent state. | Network fuzz/DoS testing |
| API-01 | An RPC response cannot be presented as finalized unless verified against valid signed effects/checkpoints. | SDK tests + adversarial RPC proxy |
| PAY-01 | Merchant escrow release/refund/arbitration cannot exceed deposited value or bypass explicit authorization. | Move Prover + fuzz + independent audit |
| COMP-01 | Compute-provider rewards require the contracted proof/attestation/check conditions; rejected jobs cannot release escrow. | Contract specs + fraudulent-provider tests |
| COMP-02 | Verification claims identify their trust tier (replay, independent quorum, zkVM, TEE metadata); none are marketed as equivalent. | Protocol format review |
| COMP-03 | *(new)* A job whose value exceeds the Tier Z cap cannot be paid on a single zkVM proof; it needs replay or a second independent zkVM. TEE attestation alone never releases escrow. | Contract specs + tests |
| COMP-04 | *(new, v0.5)* A verifier's vote cannot be seen by other verifiers before they commit their own; a copied commitment cannot be revealed. | Commit-reveal contract tests |
| PAY-02 | *(new, v0.5)* An invoice is paid at most once, for exactly its amount, and total refunds never exceed the amount paid and go only to the payer. | Move tests + fuzz |
| DEC-01 | *(new, v0.5)* No validator, operator, ASN or hosting provider exceeds its ADR-0004 share of voting power; no single group can reach 1/3. | `scripts/decentralization-report.py --enforce` each epoch |
| PRIV-01 | Shielded proofs validate conservation, authorization and nullifier uniqueness; no unauthorized mint/double-spend. | Formally verified circuit + external audit + LEDGER-05 |
| PQ-01 | Each supported signature scheme has standard test vectors, domain separation, resource limits and a migration/rollback policy. | Crypto interop + implementation audit |

**Proof coverage:** An independent proof review must map each mathematical abstraction to actual Rust/Move modules and record missed assumptions and hardware/network effects.

**Mandatory exploit regressions (reproduced, then guarded):**
1. Jan 2026 Sui consensus-commit divergence under garbage-collection conditions.
2. May 2026 gas-charging underflow when a transaction is cancelled for insufficient funds.
3. May 2026 variant where another cancellation reason masks the insufficient-funds condition and reaches the same underflow.
4. May 2026 randomness/DKG state not preserved across an epoch-transition restart.
5. Zcash CVE-2026-54496 class (under-constrained circuit): applies to any circuit we adopt.
6. RISC Zero CVE-2025-52484 and SP1 soundness advisories: applies to any zkVM verifier we accept.
7. Any new upstream advisory, within the triage SLA.

## Phase mapping
| Phase gate | Invariants that must pass |
|---|---|
| Phase 1 (devnet) | CONS-01, CONS-02, LEDGER-01, LEDGER-02, LEDGER-04, AUTH-01, EXEC-01, STORE-01, API-01 |
| Phase 2 (hardened testnet) | All Phase 1 + CONS-03/04/05, LIVE-01, LEDGER-03, EXEC-02/03/04, GOV-01/02/03, NET-01 |
| Phase 3 (products) | All Phase 2 + LEDGER-05, AUTH-02, PAY-01/02, COMP-01/02/03/04 |
| Mainnet | All of the above, plus DEC-01 enforced. PRIV-01 and PQ-01 are required only when those features are enabled. |
