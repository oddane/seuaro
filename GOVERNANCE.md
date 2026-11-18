# Governance

## Roles
| Role | Responsibilities | Today |
|---|---|---|
| **Maintainers** | Merge rights, releases, security response, roadmap | @oddane |
| **Reviewers** | Required second review for consensus, cryptography, gas, serialization, genesis, upgrades and `patches/` | to be appointed |
| **Contributors** | Issues, pull requests, reviews | everyone |

## How decisions are made
1. **Everyday changes:** pull request, passing CI, one maintainer approval.
2. **Sensitive areas** (see CONTRIBUTING.md): two approvals, one of them from someone who did not write the change.
3. **Design, economics or security properties:** an ADR in `docs/architecture/`, proposed through the ADR issue template, open for comment for at least 7 days before acceptance.
4. **Upstream bumps** (`UPSTREAM.lock`): the release must have run ≥ 8 weeks on the upstream mainnet without a related incident; re-run the license audit and FORK-DELTA review.

## Releases
Testnet releases are tagged `vX.Y.Z-testnet` from `main` after CI is green, with a changelog entry and a published container image. Mainnet releases additionally require every item in LAUNCH-GATES.md.

## Network governance
On-chain protocol upgrades follow upstream's validator-vote mechanism. Treasury, delegation and parameter changes follow ADR-0002/ADR-0004 with multisig and timelocks. This section will expand as independent validators join.
