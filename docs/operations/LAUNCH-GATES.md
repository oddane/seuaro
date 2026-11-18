# Independent Mainnet Launch Gates

A gate is a **blocker**. Do not reinterpret a missed gate as marketing guidance.

## G0 — Design approval
- [ ] External reviewers approve the threat model, trust assumptions, fork strategy and alternatives assessment.
- [ ] ADR-0002 to ADR-0007 written and approved (asset, fees, validators, upgrades, settlement semantics, compute tiers).
- [ ] Every component in the release appears in PROVEN-TECHNIQUES.md at the level its usage requires. Value paths are P3 only.
- [ ] License/IP/legal review of all borrowed and newly written code.

## G1 — Correctness
- [ ] Every invariant in INVARIANTS.md is mapped to specific Rust/Move code and a test owner.
- [ ] Independent review of consensus proofs and implementation-model correspondence, including the Mysticeti round-jumping/liveness caveat.
- [ ] No conflicting certificate in model checking or deterministic simulation inside the threat boundaries.
- [ ] Differential execution, gas accounting, serialization and protocol-versioning tests pass.
- [ ] All mandatory exploit regressions reproduce the original failure on unpatched code and pass on the release.

## G2 — Security engineering
- [ ] Secure CI with reproducible artifacts, pinned dependencies, signed releases, SBOM and secret scanning.
- [ ] Two independent assessment teams review consensus-critical code and value paths. At least one review includes AI-assisted adversarial analysis. Scopes and remediation are published.
- [ ] **No unresolved critical or high-severity vulnerabilities in the release scope.**
- [ ] Fuzzing corpus includes historical upstream outage root causes.
- [ ] Upgrade rights and emergency powers are documented and held in hardware-backed multisig with timelocks.
- [ ] Every value pool has a turnstile and outflow cap enforced on-chain (LEDGER-05), with a live monitor and alerting.

## G3 — Operations resilience
- [ ] Multi-region chaos tests: process kill, disk full, slow peers, one-region partition, validator churn, poisoned snapshots, failed upgrades, restarts during epoch change.
- [ ] Zero network halts during W4 and W7 test runs. Injected execution faults end as transaction aborts (EXEC-04).
- [ ] 30-day minimum public testnet soak after the last consensus-, gas- or accounting-affecting change, extended as findings require.
- [ ] Restore the whole network from trusted checkpoints within measured recovery-time objectives.
- [ ] Clients verify finality and committee hand-offs; stale or malicious RPC/indexers cannot falsely confirm payment.
- [ ] Tested incident response: paging, release halt, coordination, postmortem publication within 7 days.
- [ ] Emergency-patch drill: a hotfix passes deterministic simulation of its triggering incident before deployment.

## G4 — Economics, decentralization and compliance
- [ ] Multiple independent organizations run validators; effective control concentration and hardware cost are published.
- [ ] Public genesis, token allocation, emissions, delegation rules, fee model, anti-Sybil and spam analysis.
- [ ] Jurisdiction-specific counsel reviews token distribution, payments, money transmission, sanctions and privacy; no unsupported legal claims.
- [ ] Budget for auditors, monitoring, bounties and upstream patch adoption.

## G5 — External validation
- [ ] An independent team reproduces benchmark claims with frozen source, public test cases and documented hardware.
- [ ] Public bug bounty and coordinated vulnerability disclosure process.
- [ ] Community risk disclosures cover bridge, privacy, compute, oracle and governance trust models, plus each component's register level.
- [ ] Signed releases and emergency migration/recovery runbooks published.

## Feature-enablement gates (after mainnet)
| Feature | May enable on mainnet when |
|---|---|
| Address balances | Upstream feature reaches P2; W4/W7 pass with it enabled |
| On-chain randomness | GOV-02 regressions pass; a product needs it |
| Native ML-DSA-65 accounts | Reaches P2 (≥ 1 yr production on another major chain) + PQ-01 + W1 cost acceptable |
| Shielded pool | Circuit back at P3 + formal circuit verification + PRIV-01 + LEDGER-05 cap |
| Light-client bridge | Mainnet stable ≥ 6 months + bridge-specific audit + turnstile and rate limits |

## Automatic no-go conditions
Any unresolved safety violation; inability to recover certified state; unresolved value creation/drain bug; undocumented admin bypass; unreviewed consensus-critical diff; a P0/P1 component in a mainnet value path; a value pool without a turnstile; inability to deploy security updates; single-person undisclosed control over user funds; misleading finality, quantum or privacy claims.

**No launch certificate can guarantee no future flaws.** The report must list residual risks and test evidence.
