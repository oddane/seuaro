# Threat Model (v0.4)

## Assets
User funds, state roots, finality certificates, validator voting keys, committee hand-off certificates, transaction authentication, protocol upgrade rights, escrow balances, merchant funds, sponsorship budgets, compute-job deposits, off-chain private data and client wallets.

## Adversaries and capabilities
1. **Byzantine validator coalition:** withholds votes, equivocates, censors, produces invalid/malformed blocks or partitions peers. The BFT assumption is < 1/3 adversarial stake; verify the exact theorem against the pinned implementation.
2. **Network attacker:** latency, loss, reordering, eclipse attacks, route hijacking, floods and transient partitions.
3. **Malicious transaction author:** expensive transactions, edge-case gas combinations (including multiple simultaneous cancellation reasons), duplicate spends, malformed serialized inputs.
4. **Ordering exploiter (new):** front-runs or reorders shared-object transactions (escrow, marketplaces), for example to snipe merchant refunds or compute-job assignments. Owned-object payments are not exposed to this because they need no ordering.
5. **Compromised governance key or provider:** ships a malicious upgrade, drains escrow, overrides validator membership or manipulates oracle inputs.
6. **Supply-chain attacker:** tampers with dependencies, CI runners, release binaries, SDKs or wallet update channels.
7. **Malicious compute provider:** fabricates work, forges attestations (TEE.fail-class key extraction is practical), exploits zkVM soundness bugs, uses stale verification keys.
8. **Economic adversary:** accumulates stake, coordinates censorship, creates congestion, manipulates fees and app pricing.
9. **Light-client deceiver (new):** feeds a client a fake committee or a stale chain via a malicious RPC endpoint.
10. **Insider / operator fault:** wrong genesis, poisoned snapshot, leaked keys, missed backup, premature restart, inconsistent migration, or an emergency fix shipped under time pressure.
11. **AI-accelerated attacker (new):** uses frontier models to find bugs much faster than before. In 2026 such tools helped find the Zcash Orchard flaw and weakened the HAWK signature candidate. Assume the time from disclosure to exploit is now hours.

## Priority failure scenarios
- Two honest validator subsets finalize conflicting checkpoints.
- Nodes diverge at consensus-commit garbage collection, an epoch boundary or a protocol version change.
- A cancelled transaction charges gas incorrectly or causes an underflow that crashes validators. The chain halts instead of rejecting one transaction.
- An emergency fix introduces the next failure (the May 2026 fix-of-a-fix pattern).
- Concurrent writes to the same object give nondeterministic results.
- One malformed or oversized transaction, proof or index update freezes the network.
- A snapshot is accepted despite a wrong genesis/chain id, or light clients trust fake RPC confirmations or a fake committee.
- Validator key theft permits unauthorized certificates or governance action.
- The fee market collapses during spam; ordinary users are censored by high-priority traffic.
- A shared-object escrow is front-run.
- A contract upgrade steals assets or changes merchant payout terms.
- A compute provider is paid on a forged zkVM proof or a forged TEE attestation.
- A shielded-pool circuit is under-constrained and mints value without detection.
- A cross-network bridge is compromised (deferred).

## Controls
- **Proven-only components:** every component holds a register level, and value paths use P3 only ([PROVEN-TECHNIQUES.md](../architecture/PROVEN-TECHNIQUES.md)).
- **Bounded blast radius:** turnstiles and per-epoch outflow caps on every pool (LEDGER-05); feature kill-switches via protocol flags.
- **Fail-per-transaction:** deterministic aborts instead of node crashes (EXEC-04).
- Pinned upstream consensus with zero local changes; binary/model correspondence review.
- Tiered keys: offline governance, validator HSMs, limited hot-wallet rights, multisig + timelocks.
- Reproducible builds, signed releases, locked dependencies, SBOM, advisories, no secrets in CI.
- Transaction resource caps, per-peer budgets, overload control, authenticated peers; public RPC and indexers isolated from validators.
- Payment flows default to owned objects. Shared-object packages use commit-reveal or batch settlement where ordering matters, and document what is left exposed.
- Wallet/SDK verify checkpoints **and** committee hand-offs (CONS-05) and reject unknown genesis/chain id.
- Upgrade discipline: one risky flag per release (GOV-03); canary rollout; emergency patches still pass deterministic simulation of the triggering incident before deployment. **Never** bypass quorum finality to keep processing through a partition.
- Compute payouts follow tiers: replay first, zkVM capped, TEE never alone (COMP-03).
- Human audits plus AI-assisted adversarial review; funded bug bounty; red team; coordinated disclosure; 24 h triage for upstream advisories.

## Residual risks
No system eliminates unknown vulnerabilities, cartel capture, majority-stake attacks, cloud concentration, social engineering, hardware side channels, governance misuse, external integrations or future cryptanalysis. "Proven" components can still fail, as Mysticeti, Orchard and the zkVMs all did in 2025–2026. These are tracked as explicit risks with caps and recovery plans. None is treated as solved.
