# Seuaro

An independent Layer 1 for payments and verifiable compute, built **only from proven techniques**: a pinned, unmodified Sui release (Mysticeti consensus + Move), its own genesis and validator set, and a policy that every component must have a real production track record. Design docs are in [`docs/`](docs/README.md).

> **Status: testnet software.** Runs as a local devnet or a multi-container testnet. Not audited, no token, no mainnet, no real value. Do not use with real funds.

## What's in the repo
| Path | What it does |
|---|---|
| `UPSTREAM.lock` | Exact upstream tag and commit, toolchain and max protocol version |
| `scripts/fetch-upstream.sh` | Fetches the pinned commit and refuses to continue if the tag moved or the tree was modified |
| `scripts/build.sh` | Builds `sui` and `sui-node` with `--locked`, then builds `seuaro-verify` without changing any upstream dependency |
| `scripts/devnet-genesis.sh` | New genesis: own chain id, 4 validators, 30 s epochs |
| `scripts/devnet-up.sh` / `devnet-down.sh` | Start and stop the devnet; a full node writes every checkpoint to `devnet/checkpoints/` |
| `tools/seuaro-verify` | Light client that trusts only `genesis.blob`. It verifies every checkpoint certificate, chain linkage and committee hand-off, then reports a transaction FINAL |
| `tests/phase1.sh` | Acceptance tests for API-01, CONS-01, CONS-05, AUTH-01, LEDGER-04, plus tamper tests |
| `packages/seuaro_payments` | Move contracts: `turnstile` (LEDGER-05 capped pool accounting), `vault` (shared pool behind a turnstile), `escrow` (PAY-01 merchant escrow with buyer-protection window, disputes and arbiter timeout), with unit tests |
| `tests/payments-devnet.sh` | Publishes the contracts on the devnet and runs refund, dispute and unauthorized-release flows, each verified FINAL |
| `packages/seuaro_compute` | Move contracts for the compute marketplace: job escrow, provider bonds, optimistic challenge window, replay verification by a verifier quorum, timeouts (COMP-01/02) |
| `docker/` | Node image, entrypoint, compose file: 4 validators, public full node, faucet, Prometheus, Grafana, explorer |
| `scripts/net-up.sh` / `net-down.sh` | Runs Sui's multi-party genesis ceremony (each validator makes its own keys) and starts the container testnet |
| `explorer/` | Minimal block explorer (checkpoints, transactions, addresses, objects) |
| `tests/phase2-faults.sh` | Fault injection: validator crash, loss of quorum, network partition, restarts across epochs |
| `.github/workflows/ci.yml` | Runs all of the above on every push |

## Run it locally
Requirements: Linux or macOS, ~16 GB RAM, ~60 GB free disk, [rustup](https://rustup.rs), `clang`, `cmake`, `pkg-config`, `libssl-dev`, `libpq-dev`, `zstd`, `python3`. The first build takes 30–90 minutes.

```bash
scripts/build.sh            # fetch + build pinned upstream and the verifier
bin/sui move test --path packages/seuaro_payments   # contract unit tests
scripts/devnet-genesis.sh   # create a fresh chain (deletes devnet/)
scripts/devnet-up.sh        # start 4 validators + full node
tests/phase1.sh             # run the Phase 1 acceptance tests
tests/payments-devnet.sh    # publish and exercise the payment contracts
scripts/devnet-down.sh
```

Check a transaction yourself:
```bash
bin/seuaro-verify --genesis devnet/config/genesis.blob --checkpoints devnet/checkpoints tx --digest <DIGEST>
```

## Container testnet
Requires Docker with Compose v2, plus the binaries from `scripts/build.sh`.
```bash
scripts/net-up.sh            # build image, run genesis ceremony, start everything
tests/phase2-faults.sh       # fault-injection tests
scripts/net-down.sh          # stop (add --wipe to delete state and keys)
```
| Service | Address |
|---|---|
| RPC (full node) | http://127.0.0.1:9000 |
| Faucet | http://127.0.0.1:5003 |
| Explorer | http://127.0.0.1:8080 |
| Grafana | http://127.0.0.1:3000 |
| Prometheus | http://127.0.0.1:9090 |

All ports bind to localhost only. Test accounts (`faucet`, `buyer`, `merchant`, `arbiter`) and their keys live in the `users` volume; use them with `docker compose -f docker/compose.yaml run --rm client exec sui client --client.config /users/buyer/client.yaml …`.

## Rules for contributors
- Zero changes to upstream source. Every delta goes in [`docs/architecture/FORK-DELTA.md`](docs/architecture/FORK-DELTA.md) with two reviewers.
- Never commit anything under `devnet/`: it holds private keys.
- AI-generated patches are untrusted submissions and need tests and expert review.
- The protocol runs Sui mainnet's feature set; see [ADR-0008](docs/architecture/ADR-0008-protocol-feature-set.md).

## License
Apache-2.0, matching upstream Sui.
