# ADR-0004: Validator Admission and Concentration Limits

**Status:** Accepted for testnets (2026-11-18). Numbers to be reviewed before mainnet.

## Context
- Corporate payment chains (Tempo, Arc) launched with hand-picked validators. Tron runs on 27 elected producers with a Nakamoto coefficient of about 3–4.
- Validator count alone is misleading. In August 2026 a routing failure at a single hosting network took about 29% of Solana's stake offline, a few points from the 1/3 threshold that stops finality. One ASN held 27% of stake.

## Decision
1. **Open admission.** Validators join through upstream Sui's stake-based process (P3): minimum stake, then `become-candidate` / `join-committee`. No allowlist.
2. **Mandatory infrastructure disclosure.** Each validator's on-chain description carries `operator=…; asn=…; provider=…; region=…`. Undisclosed stake counts as a policy violation.
3. **Concentration limits** (share of total voting power), adapted from the Solana Foundation delegation program's ASN and data-center caps:

| Group | Limit |
|---|---|
| Single validator | 10% |
| Single operator (all its validators) | 15% |
| Single ASN | 25% |
| Single hosting provider | 25% |
| Single region | 33% |

No group may ever reach 1/3, the point where it can halt finality alone.

4. **Enforcement.** `scripts/decentralization-report.py --enforce` runs every epoch on public networks. Violations block foundation delegation to the offending group and are published. Mainnet launch requires zero violations (invariant DEC-01, gate G4).
5. **Self-delegation caps** are applied through delegation policy, not protocol changes, so upstream code stays unmodified.

## Consequences
- The 4-validator container testnet violates these limits by design (one host, one provider); CI prints the report as information only.
- Disclosure can be false. Spot checks (traceroutes, provider attestations) are an operations task, and mis-disclosure leads to removal from delegation.
