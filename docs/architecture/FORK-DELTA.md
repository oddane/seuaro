# Fork-Delta Register

Every difference between Seuaro and the pinned upstream Sui release. Anything not listed here is a bug. Changing this file needs two reviewers.

**Pinned upstream:** `mainnet-v1.79.1` @ `808640d9b49aecf29d8e6f46033c15eca236efa7` (see `UPSTREAM.lock`).

| # | Kind | Delta | Why | Consensus-affecting? | Reference |
|---|---|---|---|---|---|
| D1 | Source | **Branding patches only** (`patches/0001`, `0002`); no consensus, execution, gas or storage logic is changed. The tree is reset to pristine and patched fresh on every build; any other changed file fails the build. | Remove third-party trademarks from the shipped product (TRADEMARKS.md) | 0001: yes (system package bytecode at genesis); 0002: no | `patches/`, `scripts/build.sh` |
| D2 | Genesis | Separate genesis → distinct chain identifier, committee and accounts | Independent network | Yes (by design) | `scripts/devnet-genesis.sh` |
| D3 | Runtime env | `SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE=mainnet` on every node | Use Sui mainnet's proven feature set | Yes: must be identical on all nodes | ADR-0008 |
| D4 | Node config | `transaction_kv_store_read_config.base_url` must be empty | Never read Sui mainnet data | No | `scripts/devnet_tool.py` |
| D5 | Added tool | `seuaro-verify`, built inside the upstream workspace without changing any dependency version | Client-side finality verification | No (client only) | `tools/seuaro-verify` |
| D6 | Build env | `CARGO_PROFILE_RELEASE_DEBUG=0` in CI (debug info off); `CXXFLAGS=-include cstdint` everywhere (RocksDB 8.10 vs GCC 13+) | Fit the CI disk; compile the pinned RocksDB on Ubuntu 24.04 | No (build flags only) | `.github/workflows/ci.yml`, `scripts/build.sh` |
| D7 | Genesis economics | ADR-0002 allocation (40/10/20/15/10/5) and stake-subsidy schedule (1M SEU/epoch, −10% per 90 epochs) via ceremony parameters | SEU economics without code changes | Yes (genesis state) | `docker/entrypoint.py` |
| D9 | Patch 0001 | Native coin display metadata: symbol `SEU`, name `Seuaro`, description. System packages regenerated with upstream's `build-system-packages` tool; build fails unless only the framework package changes. Type path `0x2::sui::SUI` unchanged | Wallets and explorers show SEU; trademark hygiene | Yes (genesis bytecode) | `patches/0001-*.patch` |
| D10 | Patch 0002 + install names | Program names in help/version output: `seuaro`, `seuaro-node`, `seuaro-faucet`; binaries installed under those names | Trademark hygiene | No | `patches/0002-*.patch`, `scripts/build.sh` |
| D11 | Distribution | LICENSE, NOTICE and generated THIRD-PARTY-LICENSES.md ship with every binary and image | Apache-2.0 §4 compliance | No | `scripts/third-party-licenses.py`, `docker/Dockerfile` |
| D8 | Packaging | Container image (ubuntu:24.04) with unmodified binaries + `sui-faucet` | Container testnet | No | `docker/Dockerfile` |

**Known inert mainnet constants** (ADR-0008 R3): mainnet gasless stablecoin allowlist; mainnet zkLogin provider list; mainnet name-service object IDs.
