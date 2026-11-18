# Competitive Benchmark Protocol

## Principles
Benchmark only **verified, finalized, useful user transactions**, not empty blocks or consensus proposals. Compare named protocol versions on independently measured hardware with all-in operating costs. Run at least three repetitions and publish raw traces, configuration, failures and statistics.

## Workloads
| Workload | Details | Primary limiting resource |
|---|---|---|
| W1 transfers | Independent owned-object transfers, 250 B–1 kB; vary signature schemes (Ed25519, secp256r1/passkey, zkLogin, multisig, and ML-DSA-65 on testnet) | Signature checks / network |
| W2 merchant | Transfer + escrow + receipt event; sponsored and non-sponsored | Execution / fees |
| W3 smart contract | Independent object writes and shared-object contention | Conflict scheduling |
| W4 adversarial | 10–50% invalid/cancelled tx (including multiple cancellation reasons), duplicate spends, expensive proofs, spam | Isolation / DoS |
| W5 restore | Snapshot, node restart, new-node catch-up during sustained load | State sync / storage |
| W6 compute | Job escrow, off-chain result, replay and zkVM verification | Verification / external trust |
| W7 upgrade *(new)* | Protocol-version activation and epoch change under sustained W1+W2 load, including validator restarts during the transition | Reconfiguration / restart |

## Environments
| Env | Setup | Purpose |
|---|---|---|
| L0 | 4 validators on one machine or laptop cluster | Correctness and debugging only. **No performance numbers are reported.** |
| L0P *(new)* | 4 validators on 4 identical dedicated machines in one region | First baseline performance numbers. Not representative of a global network. |
| L1 | 15+ validators in ≥ 3 regions, realistic latency and packet loss | Representative testnet performance |
| L2 | 30+ independent operators across regions and cloud/hardware providers | Pre-mainnet performance and decentralization evidence |

All environments publish CPU model, cores, RAM, NVMe, bandwidth, cost per validator, operator distribution and stake distribution. Load-stability runs last ≥ 72 hours; the resilience soak on a later testnet lasts ≥ 30 days.

## Required metrics
- p50 / p95 / p99 **end-to-end certified finality** (client send → verified receipt), not just consensus commit.
- Finalized, successful TPS sustained for 1, 24 and 72 hours, plus tail latency.
- Failure/rejection rate, spam impact, fee distribution, gas consumed vs. charged, user-visible error semantics.
- CPU/RAM/disk IOPS/network per node, storage growth per day, new-node catch-up time, annual infrastructure cost.
- Inclusion delay distribution (LIVE-01), operator concentration, validator churn, checkpoint availability, time to recover after outages.
- **Halt count and total halt minutes** per test period, and whether each fault ended in a transaction abort (desired, EXEC-04) or a node crash.
- Invariant results under defined Byzantine fractions and partitions; documented behavior beyond thresholds.

## Acceptance thresholds (engineering goals, not achieved capabilities)
- **L0P baseline:** 1,000 TPS sustained W1, zero invariant failures, published p95 finality and resource metrics.
- **L1 testnet:** 5,000 TPS sustained W1 as a stretch goal **only if** cost and decentralization remain acceptable. W2, W3 and W7 are reported separately. Zero network halts during W4 and W7.
- **Security:** no unresolved critical or high-severity findings in the release scope (same rule as LAUNCH-GATES G2); independent audit sign-off; all mandatory exploit regressions pass.
- **Faults:** no conflicting certified effects with Byzantine behavior up to the exact protocol bound.
- **Mainnet gate:** independent third-party reproduction; sustainable fees and storage; normal and adversarial W2/W3/W7 succeed (not just W1).

## Competitor comparisons (status as of 2026-11-18)
- **Sui:** Mysticeti in production since Aug 2024 (~400 ms consensus latency reported). Benchmark the current release, and record its 2026 halt history alongside the speed figures.
- **Solana:** Alpenglow (Votor) activated on mainnet 2026-10-21. About 150 ms finality is a **target**; do not treat it as measured p95 finality until independent data exists.
- **Kaspa:** PoW BlockDAG with probabilistic confirmation; do not equate blocks per second with TPS.
- **Ethereum:** evaluate L1 settlement separately from L2 execution, throughput and data availability.

## Data volume example
At 10,000 sustained TPS and 300 bytes per transaction, raw transaction bytes alone are ~259.2 GB/day. That excludes signature size variation (ML-DSA-65 signatures are several kilobytes), consensus metadata, indexes and replication. This limits any claim that global validator operation is cheap.
