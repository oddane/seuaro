# Upstream License Audit

**Upstream:** `MystenLabs/sui` `mainnet-v1.79.1` @ `808640d9` (UPSTREAM.lock). **Date:** 2026-11-18. **Method:** every `LICENSE*`, `LICENCE*`, `COPYING*` and `NOTICE*` file in the tree, plus every `SPDX-License-Identifier` header in Rust, Move, TypeScript and Python sources under `crates/`, `consensus/` and `external-crates/`. Rust dependencies pulled from crates.io and git are covered separately by the generated `THIRD-PARTY-LICENSES.md`.

This is an engineering record, not a legal opinion (see COUNSEL-CHECKLIST.md).

## Findings
| Item | License | Shipped by Seuaro? | Obligation | How Seuaro meets it |
|---|---|---|---|---|
| Upstream source (4,587 files with SPDX headers) | Apache-2.0 | Yes (compiled) | Provide license; keep notices; mark modified files; no trademark use | `LICENSE`, `NOTICE`; headers untouched; changes only in `patches/` and FORK-DELTA.md; TRADEMARKS.md |
| Move language code (670 files with Diem / Facebook copyright lines) | Apache-2.0 | Yes (compiled) | Keep copyright notices | Retained in source; credited in `NOTICE` |
| `LICENSE-docs`, `docs/site/LICENSE` | CC BY 4.0 | No | Attribution if adapted | Only factual references; credit given where adapted |
| `docs/subtree/awesome-sui*` | CC0 1.0 | No | None | — |
| Move editor tooling (`move-analyzer` editors, prettier extension) | Apache-2.0 | No | — | — |
| `external-crates/move/tooling/tree-sitter` | MIT | No | Keep notice if redistributed | Not redistributed |
| Rust crates in the shipped binaries | Various (generated list) | Yes | Per license | `THIRD-PARTY-LICENSES.md` built from the exact dependency graph; strict mode fails on unknown licenses for releases |

## Modified upstream files (Apache-2.0 §4(b))
Every modified upstream file is changed only through a numbered patch in `patches/`, and each patch adds a comment at the change site naming it (`Seuaro patch 000N`). See FORK-DELTA.md D1, D9, D10.

## Re-run
Repeat this audit whenever `UPSTREAM.lock` changes; it is part of the upgrade checklist.
