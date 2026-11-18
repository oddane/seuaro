# ADR-0008: Protocol Feature Set — run exactly Sui mainnet's

**Status:** Accepted for Phase 1 (2026-11-18). Revisit before Phase 2.
**Supersedes:** the v0.4 statements that address balances and on-chain randomness are "disabled at launch".

## Context
v0.4 required two things: (1) zero local changes to upstream code, and (2) address balances and on-chain randomness turned off. Reading the pinned source (`mainnet-v1.79.1`, `MAX_PROTOCOL_VERSION = 136`) showed that the two cannot both hold:

1. **An independent genesis is treated as an "unknown" chain.** `ChainIdentifier::chain()` returns `Chain::Unknown` for any genesis other than Sui mainnet/testnet. In `sui-protocol-config`, many features are switched on early for non-mainnet chains (address balances from v106/v108; several devnet-only features). With no action, a Sui-derived chain therefore runs the **least-proven** feature set.
2. **Features are compiled in per protocol version.** `NodeConfig.supported_protocol_versions` is `#[serde(skip)]`, so operators cannot cap the version. Boolean feature flags cannot be overridden by environment either. Only numeric parameters can (`SUI_PROTOCOL_CONFIG_OVERRIDE_*`), and upstream warns that this "may break non-local networks".
3. **Upstream offers a supported switch.** `SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE=mainnet` makes an unknown chain use Sui mainnet's feature schedule. Upstream describes it as intended for "bootstrapping regenesis chain configuration". The node refuses it on the real mainnet/testnet.
4. **Disabling a feature now means losing fixes.** Address balances have been on Sui mainnet since protocol v124. The fixes for the May 2026 halts are gated at v126 (gas-underflow early exit) and v127 (`always_advance_dkg_to_resolution`). Pinning an older version would drop those fixes. Turning the features off at v136 would require a source patch.

## Decision
Every Seuaro node runs with `SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE=mainnet`. The protocol behavior is therefore **identical to Sui mainnet at the same protocol version**. *(Amended: the only source changes are the branding patches in FORK-DELTA D1/D9/D10, which change no protocol logic.)*

Rationale under PROVEN-TECHNIQUES.md: the proven artifact is *the configuration Sui mainnet actually runs*, with its fixes. A hand-picked subset (mainnet minus some features) is a combination nobody runs in production, which makes it P0 under our own policy.

Address balances and randomness are therefore **on at the protocol level**. The policy moves to the application layer:
- Seuaro Move packages (payments, escrow, compute) use coin objects and do not depend on address balances or randomness until those reach P2 (≥ 1 year on Sui mainnet without a related incident).
- The incident regressions for both features (INVARIANTS.md, items 2–4) remain mandatory because the code paths are live.

## Risks and controls
| ID | Risk | Control |
|---|---|---|
| R1 | The override has effects beyond protocol config. The node may fall back to Sui mainnet's HTTP key-value store if `transaction_kv_store_read_config.base_url` is set. It also uses mainnet's zkLogin provider list and name-service defaults. | `devnet_tool.py check-config` fails if any node config sets a KV base URL. zkLogin/name-service effects are inert on a separate chain; they are listed for the Phase 2 review. |
| R2 | The override is an environment variable. A node started without it would compute a different protocol config and diverge. | `lib.sh` sets it for every process and `check_protocol_env` refuses to start without it, or with any `SUI_PROTOCOL_CONFIG_OVERRIDE_*` variable. Phase 2 must replace this with a startup check that cannot be skipped (ADR required). |
| R3 | Mainnet-specific constants (for example the gasless allowlist of mainnet stablecoin types) refer to objects that do not exist on Seuaro. | Inert. Tracked in FORK-DELTA.md. |
| R4 | Sui mainnet enables features at future versions on its own schedule. | Seuaro only adopts a new upstream release after ≥ 8 weeks on Sui mainnet (UPSTREAM.lock rule). Each adoption reviews the new version notes. |

## Consequences
- PROVEN-TECHNIQUES.md, ADR-0001, README and IMPLEMENTATION.md are amended to point here.
- FORK-DELTA.md records the override as Seuaro's only behavioral delta from upstream.
