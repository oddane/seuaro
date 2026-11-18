# Seuaro Architecture

This document explains how Seuaro is put together and how value moves through it. Design rationale lives in the [ADRs](architecture/); security properties in [INVARIANTS.md](security/INVARIANTS.md).

- [1. Layers](#1-layers)
- [2. Build and supply chain](#2-build-and-supply-chain)
- [3. Transaction lifecycle](#3-transaction-lifecycle)
- [4. Finality verification](#4-finality-verification)
- [5. Genesis ceremony](#5-genesis-ceremony)
- [6. Contracts](#6-contracts)
- [7. Deployment topology](#7-deployment-topology)
- [8. Failure behavior](#8-failure-behavior)

## 1. Layers

```mermaid
flowchart TB
  L6["L6 · Deferred extensions<br/>shielded pool · ML-DSA accounts · light-client bridge"]:::later
  L5["L5 · Interfaces<br/>CLI · RPC · explorer · seuaro-verify · wallets"]
  L4["L4 · Compute marketplace<br/>seuaro_compute: jobs, bonds, commit-reveal quorum"]
  L3["L3 · Payment packages<br/>seuaro_payments: turnstile, vault, escrow, invoice"]
  L2["L2 · Deterministic execution<br/>Move VM · objects · gas · checkpoints"]
  L1["L1 · BFT ordering<br/>Mysticeti DAG-BFT (pinned, unmodified logic)"]
  L0["L0 · Host runtime<br/>Linux · containers · HSM-backed keys · telemetry"]
  L6 --- L5 --- L4 --- L3 --- L2 --- L1 --- L0
  classDef later fill:#334155,color:#cbd5e1,stroke:#64748b,stroke-dasharray: 4 3
```

| Layer | Maturity (register) | Seuaro-specific code |
|---|---|---|
| L0 | P3 practices | `docker/`, `scripts/` |
| L1 | P3 | none (pinned upstream) |
| L2 | P3 | patch 0001: coin display metadata only |
| L3 | new (P0) Move code on P3 primitives | `packages/seuaro_payments` |
| L4 | new (P0) Move code on P3 patterns | `packages/seuaro_compute` |
| L5 | P3 + new verifier | `tools/seuaro-verify`, `explorer/` |
| L6 | P1–P2; testnet only | not built |

## 2. Build and supply chain

```mermaid
flowchart LR
  A[UPSTREAM.lock<br/>tag + commit] --> B[fetch-upstream.sh<br/>verify tag, toolchain, protocol version]
  B --> C[reset to pristine]
  C --> D[apply patches/000N]
  D --> E[regenerate system packages<br/>upstream build-system-packages]
  E --> F{only expected<br/>files changed?}
  F -- no --> X[fail build]
  F -- yes --> G[cargo build --locked]
  G --> H[seuaro-verify<br/>same lockfile, no version changes]
  H --> I[install as seuaro, seuaro-node,<br/>seuaro-faucet, seuaro-verify]
  I --> J[LICENSE · NOTICE ·<br/>THIRD-PARTY-LICENSES.md]
  J --> K[container image]
```

Guarantees: the upstream tag cannot silently move; nothing but the numbered patches changes upstream; dependency versions come from upstream's lockfile; every binary ships with its license notices.

## 3. Transaction lifecycle

```mermaid
sequenceDiagram
  autonumber
  participant U as Wallet
  participant S as Sponsor (gas station)
  participant F as Full node
  participant V as Validators
  participant L as seuaro-verify
  U->>S: payment intent (no SEU needed)
  S-->>U: transaction with sponsor as gas owner
  U->>F: transaction signed by payer and sponsor
  F->>V: submit
  V->>V: validate, order (Mysticeti), execute (Move)
  V-->>F: effects in a checkpoint signed by 2f+1 stake
  F-->>U: "executed" (not yet trusted)
  F->>L: checkpoint files
  L->>L: verify certificate, linkage, contents
  L-->>U: FINAL
```

## 4. Finality verification

`seuaro-verify` trusts only `genesis.blob`.

```mermaid
flowchart TD
  G[genesis.blob] --> C0[committee for epoch 0<br/>genesis checkpoint digest]
  C0 --> L{for each checkpoint, in order}
  L --> S1[signature from 2f+1 stake<br/>of the current committee?]
  S1 -->|no| R[reject]
  S1 --> S2[contents match certified digest?]
  S2 -->|no| R
  S2 --> S3[previous digest links to last verified?]
  S3 -->|no| R
  S3 --> S4{end of epoch?}
  S4 -->|yes| H[adopt next committee<br/>from this certified checkpoint]
  S4 -->|no| L
  H --> L
```

Built-in self-test: altered summary, swapped contents, withheld checkpoint, wrong committee and forged hand-off must all be rejected.

## 5. Genesis ceremony

Each validator generates and keeps its own keys. The shared ceremony folder only receives public information and signatures, following upstream's multi-party process.

```mermaid
sequenceDiagram
  participant C as Coordinator
  participant V1 as Validator 1..n
  participant D as Shared ceremony folder
  C->>D: init (parameters: epoch length, stake subsidy schedule)
  loop each validator
    V1->>V1: generate protocol, network, worker, account keys (never leave volume)
    V1->>D: add-validator (public keys + proof of possession)
  end
  C->>D: token distribution (ADR-0002 allocation)
  C->>D: build unsigned genesis checkpoint
  loop each validator
    V1->>D: verify-and-sign
  end
  C->>D: finalize → genesis.blob
```

## 6. Contracts

### Escrow (PAY-01)
```mermaid
stateDiagram-v2
  [*] --> Locked: buyer creates
  Locked --> Released: buyer release (any time)
  Locked --> Refunded: merchant refund (any time)
  Locked --> Disputed: buyer dispute (now ≤ deadline)
  Locked --> Claimed: merchant claim (now > deadline)
  Disputed --> Resolved: arbiter split
  Disputed --> Reclaimed: buyer, after arbiter timeout
  Disputed --> Released: buyer release
  Disputed --> Refunded: merchant refund
  Released --> [*]
  Refunded --> [*]
  Claimed --> [*]
  Resolved --> [*]
  Reclaimed --> [*]
```

### Compute job (COMP-01 – COMP-04)
```mermaid
stateDiagram-v2
  [*] --> Open: client posts reward
  Open --> Assigned: provider locks bond
  Open --> Cancelled: no provider in time
  Assigned --> Submitted: result hash
  Assigned --> ProviderTimeout: no result in time
  Submitted --> PaidOptimistic: no challenge in window
  Submitted --> Disputed: verifier challenges
  Disputed --> Resolved: quorum of revealed votes agree
  Disputed --> DisputeTimeout: no quorum in time
  Resolved --> PaidByQuorum: matches provider
  Resolved --> Rejected: differs → client gets reward + bond
  Cancelled --> [*]
  ProviderTimeout --> [*]
  PaidOptimistic --> [*]
  DisputeTimeout --> [*]
  PaidByQuorum --> [*]
  Rejected --> [*]
```

Votes use commit-reveal: verifiers commit `blake2b(result ‖ salt ‖ address)` before anyone reveals, so votes can't be copied.

### Turnstile and vault (LEDGER-05)
Every pool records inflow and outflow. A withdrawal aborts if total outflow would exceed total inflow or if this epoch's outflow would exceed the cap. Cap cuts apply now; cap raises apply next epoch.

## 7. Deployment topology

```mermaid
flowchart LR
  subgraph host["Docker host (ports bound to 127.0.0.1)"]
    subgraph net["network: seuaro"]
      v1[(v1)] --- v2[(v2)] --- v3[(v3)] --- v4[(v4)] --- v1
      fn[fullnode :9000] --- v1
      fn --- v2
      fa[faucet :5003] --> fn
      ex[explorer :8080] --> fn
      pr[prometheus :9090] -.scrape.-> v1 & v2 & v3 & v4 & fn
      gr[grafana :3000] --> pr
    end
  end
```

Each validator has its own key volume and database volume. The full node writes every executed checkpoint to a volume that the verifier reads.

## 8. Failure behavior

| Situation | Behavior | Tested by |
|---|---|---|
| 1 of 4 validators down | Chain keeps finalizing | `phase2-faults.sh` F1 |
| 2 of 4 validators down | Chain halts at a fixed checkpoint; no fork | F2 |
| Validators return | Chain resumes; all earlier certificates still verify | F2 |
| One validator partitioned | Chain live; validator catches up after reconnecting | F3 |
| Restarts across epoch changes | Chain live; validator in sync | F4 |
| Tampered or foreign checkpoints | Rejected by the light client | `seuaro-verify self-test`, AUTH-01 |
