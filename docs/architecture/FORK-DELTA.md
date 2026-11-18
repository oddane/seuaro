# Fork-Delta Register

Every difference between Seuaro and the pinned upstream Sui release. Anything not listed here is a bug. Changing this file needs two reviewers.

**Pinned upstream:** `mainnet-v1.79.1` @ `808640d9b49aecf29d8e6f46033c15eca236efa7` (see `UPSTREAM.lock`).

| # | Kind | Delta | Why | Consensus-affecting? | Reference |
|---|---|---|---|---|---|
| D1 | Source | **None.** The upstream tree is verified pristine before and after every build. | Zero-change policy | — | `scripts/fetch-upstream.sh`, `scripts/build.sh` |
| D2 | Genesis | Separate genesis → distinct chain identifier, committee and accounts | Independent network | Yes (by design) | `scripts/devnet-genesis.sh` |
| D3 | Runtime env | `SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE=mainnet` on every node | Use Sui mainnet's proven feature set | Yes: must be identical on all nodes | ADR-0008 |
| D4 | Node config | `transaction_kv_store_read_config.base_url` must be empty | Never read Sui mainnet data | No | `scripts/devnet_tool.py` |
| D5 | Added tool | `seuaro-verify`, built inside the upstream workspace without changing any dependency version | Client-side finality verification | No (client only) | `tools/seuaro-verify` |
| D7 | Genesis allocation | Test token distribution: 30M staked per validator, faucet 1B, three test users 100M each, rest to the stake subsidy fund | Testnet only; real allocation is ADR-0002 | Yes (genesis state) | `docker/entrypoint.py` |
| D8 | Packaging | Container image (ubuntu:24.04) with unmodified binaries + `sui-faucet` | Container testnet | No | `docker/Dockerfile` |
| D6 | CI build env | `CARGO_PROFILE_RELEASE_DEBUG=0` (debug info off) | Fit the CI runner's disk | No (codegen only) | `.github/workflows/ci.yml` |

**Known inert mainnet constants** (ADR-0008 R3): mainnet gasless stablecoin allowlist; mainnet zkLogin provider list; mainnet name-service object IDs.
