# Running a Seuaro Testnet

Testnet only: unaudited software, coins have no value (DISCLAIMER.md).

## What you need
| | From a published image | From source |
|---|---|---|
| OS | Linux x86-64, macOS, or Windows with WSL2 (Apple Silicon runs the x86-64 image under emulation, slower) | Linux x86-64 (Ubuntu 24.04 recommended) |
| Docker | Docker Engine or Desktop with Compose v2 | same |
| RAM / disk | 8 GB (16 GB recommended) / 20 GB free | 16 GB / 60 GB free |
| Other | `git`, `python3` | plus Rust (`rustup`), `clang`, `cmake`, `pkg-config`, `libssl-dev`, `libpq-dev`, `zstd` |
| Time to first start | a few minutes | 30–90 minutes (compiling) |

A cloud VM works well: e.g. 4 vCPU / 16 GB / 80 GB disk with Ubuntu 24.04.

## Option A: published image (fastest)
1. In GitHub, open **Actions → ci → Run workflow** on the branch you want. When the `publish` job finishes, it lists the image (for example `ghcr.io/oddane/seuaro-node:testnet`).
2. If the package is private (the default for new packages), either make it public in **Packages → seuaro-node → Package settings**, or run `docker login ghcr.io` with a GitHub token that can read packages.
3. On your machine:
   ```bash
   git clone https://github.com/oddane/seuaro && cd seuaro
   scripts/quickstart.sh --image ghcr.io/oddane/seuaro-node:testnet
   ```

## Option B: build from source
```bash
git clone https://github.com/oddane/seuaro && cd seuaro
scripts/quickstart.sh
```

## What starts
| Service | Address (localhost only) |
|---|---|
| Explorer | http://127.0.0.1:8080 |
| RPC (full node) | http://127.0.0.1:9000 |
| Faucet | http://127.0.0.1:5003 |
| Grafana | http://127.0.0.1:3000 |
| Prometheus | http://127.0.0.1:9090 |

Four validators each generate their own keys during the genesis ceremony and keep them in their own Docker volume. Test accounts (`faucet`, `buyer`, `merchant`, `arbiter`, and the ADR-0002 allocation buckets) live in the `users` volume.

## Everyday commands
```bash
# CLI as the buyer test account
docker compose -f docker/compose.yaml run --rm client exec \
  seuaro client --client.config /users/buyer/client.yaml gas

# Ask the faucet for test SEU
curl -X POST http://127.0.0.1:5003/v2/gas -H 'Content-Type: application/json' \
  -d '{"FixedAmountRequest":{"recipient":"0xYOUR_ADDRESS"}}'

# Verify a transaction is final from genesis (trusts nothing but genesis.blob)
docker compose -f docker/compose.yaml run --rm client exec seuaro-verify \
  --genesis /ceremony/genesis.blob --checkpoints /opt/sui/checkpoints tx --digest DIGEST

tests/phase2-faults.sh          # crash / partition / restart tests
scripts/decentralization-report.py
scripts/net-down.sh             # stop, keep state (restart: scripts/net-up.sh --resume)
scripts/net-down.sh --wipe      # stop and delete all state and keys
```

## Exposing it beyond your machine
Every port binds to `127.0.0.1` on purpose. Before opening anything to the internet, put the RPC behind a reverse proxy with TLS and rate limits, never expose validator ports other than consensus/p2p, and read SECURITY.md and docs/legal/COUNSEL-CHECKLIST.md (running a public faucet or RPC can carry legal obligations).
