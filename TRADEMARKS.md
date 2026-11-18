# Trademarks and Naming

## Other projects' marks
Seuaro uses open-source code from the Sui project under the Apache License 2.0. That license grants rights to the **code only**. Section 6 of the license expressly grants no permission to use the licensor's trade names or trademarks, except as reasonably needed to describe where the code came from.

Public trademark records list "SUI" filings by both Mysten Labs, Inc. and the Sui Foundation in classes covering blockchain and cryptocurrency software. The Sui Foundation also publishes a trademark usage policy and actively reports misuse.

Therefore Seuaro:
- **Never** uses "Sui", "SUI", Sui logos or Sui brand assets as the name, ticker, logo or brand of any Seuaro product, coin, network, wallet, website, social account or marketing material.
- **Only** mentions Sui factually, to credit the origin of code (for example "built on open-source code from the Sui project"), in plain text, without logos.
- **Never** states or implies partnership, endorsement, sponsorship or affiliation with Mysten Labs or the Sui Foundation.
- Ships its own names to users: the **Seuaro** network, the **SEU** coin, and the `seuaro`, `seuaro-node`, `seuaro-faucet` and `seuaro-verify` programs.

### Remaining upstream identifiers (internal, not branding)
Some identifiers are part of the upstream code's programming interfaces and cannot be renamed without rewriting large parts of a proven codebase. They are technical names, not product names, and are listed openly:

| Identifier | Where | Why it stays |
|---|---|---|
| `0x2::sui::SUI` (type path of the native coin) | On-chain type name | Referenced throughout the execution engine; renaming it is a deep, unproven change. Its **display name and symbol are SEU / Seuaro** (patch 0001). |
| `sui::` Move framework module names | Smart-contract imports | Shared developer API |
| `SUI_*` environment variables, `~/.sui/` config directory | Operator tooling | Internal configuration paths |
| Rust crate names (`sui-types`, …) | Source code | Upstream structure |

Counsel should confirm this position before public launch (docs/legal/COUNSEL-CHECKLIST.md).

## Seuaro's own marks
"Seuaro" and "SEU" have **not** yet been cleared or registered. Before public use: run a clearance search and file in the relevant classes and jurisdictions (see the counsel checklist). Until then, treat both as working names.
