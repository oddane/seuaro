# Proven-Techniques Policy and Register

**Status:** Normative for v0.4. Every component in the Seuaro design must appear in this register with a maturity level. A component without an entry is not allowed in any environment beyond a developer laptop.

## 1. Why this policy exists
The v0.4 goal is a *more capable* chain built only from techniques with a real production track record. 2026 showed that "proven" does not mean "flawless":
- Sui's Mysticeti consensus (in production since Aug 2024) stalled for ~6 hours in Jan 2026 due to a commit-logic divergence under garbage-collection conditions; the v1.72 upgrade in May 2026 caused three halts (gas-charging underflow with the new address-balances feature, then an epoch-transition / randomness-state issue). In every case the chain **halted safely**: no forks, no lost funds.
- Zcash's Orchard circuit (Halo 2), live since May 2022 and heavily reviewed, had a critical soundness flaw (CVE-2026-54496) found on 2026-05-29. The long-standing **turnstile** bound on pool outflows limited the possible damage to total supply.
- zkVMs (RISC Zero, SP1) had repeated soundness advisories in 2025–2026.
- TEE.fail (Oct 2025) extracted attestation keys from current Intel SGX/TDX and AMD SEV-SNP servers with < $1,000 of equipment.

Therefore the policy has two parts. First, use only techniques that have survived real adversaries. Second, assume even those will fail, and design every value path so that a failure is **bounded, detectable and recoverable**.

## 2. Maturity levels
| Level | Name | Admission criteria (all required) |
|---|---|---|
| **P3** | Proven | ≥ 2 years continuous mainnet production securing ≥ US$1B (or equivalent critical use); ≥ 2 independent audits; public incident history with root-cause postmortems; open source; written specification or peer-reviewed design. |
| **P2** | Established | ≥ 1 year mainnet production; ≥ 1 independent audit; public advisories process. |
| **P1** | Standardized | Published standard (e.g., NIST FIPS) or peer-reviewed construction, but no long blockchain production record. |
| **P0** | Research / new | Anything else, including anything newly written by the Seuaro team. |

**Usage rules**
| Environment | Allowed levels |
|---|---|
| Mainnet consensus, execution, value accounting, finality | **P3 only** |
| Mainnet optional application features | P3; P2 only behind a feature flag **and** a value cap **and** a turnstile/rate limit |
| Public testnet | P3, P2, P1 |
| Devnet / research | Any, clearly labelled |

**Downgrade rule:** A critical soundness or safety incident resets a component to **P2** until (a) the fix has run 6 months in production without a related incident, and (b) an independent post-fix review is published. Seuaro's own modifications of a P3 component are **P0** until they meet the criteria on their own.

## 3. Register (reviewed 2026-11-18)
### 3.1 Consensus and finality
| Technique | Use in Seuaro | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| Mysticeti DAG-BFT (pinned upstream Sui release) | Ordering | **P3** (just past 2 yrs) | Sui mainnet since 2024-08-06; ~400 ms consensus latency reported in production | Jan 2026 divergence → pin a patched tag, replay that incident in regression tests, zero local changes |
| Quorum-certified checkpoints (BLS aggregate signatures) | Finality proofs for clients | **P3** | Sui since 2023 | Light clients must also verify committee hand-offs (see CONS-05) |
| CometBFT / Tendermint | Fallback option only (ADR-0001 alt. E) | **P3** | Cosmos chains since 2019 | Slower finality and no object-parallel execution |
| Solana Alpenglow (Votor) | Not used | P1 | Activated on mainnet 2026-10-21; ~150 ms is a *target* | Revisit in Oct 2028 |

### 3.2 Execution and state
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| Move VM + bytecode verifier | Smart contracts | **P3** | Sui mainnet since May 2023 | Logic bugs in contracts → Move Prover + audits |
| Owned-object transfers | Default payment path | **P3** | Sui since 2023 | Equivocation locks an object until epoch end → wallet guidance |
| Shared objects via consensus | Escrow, marketplaces | **P3** | Sui since 2023 | Hot-object contention → fee policy + benchmarks W3 |
| Protocol-version feature flags | Gate all new behavior | **P3** | Sui protocol config since 2023 | Mis-gating → activation tests at every version |
| Address balances (Sui v1.72) | Live in protocol (ADR-0008); **not used by Seuaro packages** | P1 | Shipped May 2026; caused halts | Re-evaluate once it reaches P2 |
| On-chain threshold randomness (DKG) | Live in protocol (ADR-0008); **not used by Seuaro packages** | P2 (downgraded) | Linked to the third May 2026 halt | Payments do not need it; enable only after GOV-02 tests pass |

### 3.3 Accounts and authentication
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| Ed25519, secp256k1, secp256r1 | User signatures | **P3** | Decades of use | Quantum exposure → PQ plan (3.4) |
| Native k-of-n multisig | Treasury, merchants, governance | **P3** | Sui since 2023 | Key ops discipline → HSM + runbooks |
| Sponsored transactions | Gas-free checkout | **P3** | Sui since 2023 | Sponsor drain → per-sponsor budgets |
| zkLogin (OIDC + Groth16) | Consumer onboarding | **P3** | Sui mainnet since 2023 | Depends on OIDC provider liveness → pair with multisig recovery |
| Passkey (WebAuthn / secp256r1) | Consumer signing | **P2** | Live on Sui mainnet | Device loss → multisig recovery; not sole custody for high value |

### 3.4 Post-quantum
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| ML-DSA-65 (FIPS 204) native accounts | Testnet → opt-in mainnet later | **P1** | Standard since 2024; Sui targets mainnet Q1 2027 | Large signatures; implementation bugs → hold until P2 |
| SLH-DSA-SHA2-128s (FIPS 205) inside Move vaults | Optional cold vaults | **P1** (most conservative maths: hash-based only) | Standard since 2024 | Very large signatures; low throughput is acceptable for vaults |
| Crypto-agile signature-scheme flag | Migration path | **P3** | Sui multi-scheme auth since 2023 | Policy only; never claim "quantum-safe chain" |

### 3.5 Privacy (deferred; testnet only)
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| Zcash Orchard circuit (Halo 2) | Candidate shielded pool | **P2** (downgraded after CVE-2026-54496) | Live since 2022; fixed in NU6.2 June 2026; formal circuit verification published July 2026 | Re-entry to P3 no earlier than mid-2027 |
| Turnstile pool accounting | Required for **every** pool | **P3** | Zcash; bounded the 2026 Orchard flaw | Mandatory invariant LEDGER-05 |

### 3.6 Compute verification
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| Escrow + deterministic re-execution by independent verifiers | Tier R (replay) | **P3** pattern | Standard optimistic dispute model (e.g., Arbitrum fraud proofs) | Collusion → verifier selection by stake + randomness off-chain, slashing |
| Optimistic challenge window | Default payout path | **P3** | Optimistic rollups since 2021 | Window too short → minimum window set by job value |
| zkVM proofs (RISC Zero, SP1) | Tier Z, **capped** | **P2** | Multiple soundness advisories 2025–2026 | Cap value per job; require replay or a second, independent zkVM above the cap |
| TEE attestation (SGX/TDX/SEV-SNP, GPU CC) | Metadata only | **Not a security anchor** | TEE.fail 2025 | Never releases escrow on its own |

### 3.7 Interoperability (deferred until after mainnet)
| Technique | Use | Level | Evidence | Residual risk → control |
|---|---|---|---|---|
| IBC-style light-client bridge | Only permitted bridge design | **P3** | Clean record in Cosmos production | Light-client bugs → rate limits + turnstile |
| Multisig / guardian bridges | **Rejected** | n/a | Largest category of historic losses (Ronin, Wormhole, Nomad and others) | n/a |

### 3.8 Engineering methods
| Method | Level | Use |
|---|---|---|
| Deterministic simulation testing (Sui `msim`, FoundationDB-style) | **P3** | All consensus/restart/epoch tests |
| TLA+ model checking | **P3** | Consensus, reconfiguration, upgrade activation |
| Move Prover | **P3** | Payment and escrow packages |
| Differential execution and fuzzing | **P3** | EXEC-01, CONS-02, serialization |
| Reproducible builds, SBOM, signed releases (SLSA-style) | **P3** | Every release |
| Canary rollout gated by protocol version | **P3** | Every upgrade |
| AI-assisted adversarial audit | **P2** (found the Orchard flaw) | An *addition* to human audits, never a replacement |

## 4. Design consequences ("advanced" through proven means)
1. **Bounded blast radius:** every value pool (escrow, sponsorship, compute, any future privacy pool or bridge) has a turnstile and a per-epoch outflow limit. A soundness bug can then drain at most the cap, not the chain.
2. **Fail per transaction, not per network:** an execution error must abort the transaction deterministically on every validator rather than crash nodes (EXEC-04). This is the direction Sui itself stated after May 2026.
3. **Small launch surface:** owned-object payments, multisig, sponsorship, zkLogin and audited escrow packages only. No privacy, bridges or native PQ on day one. The protocol runs exactly Sui mainnet's feature set (ADR-0008); Seuaro packages avoid address balances and randomness.
4. **One risky change per release:** no release combines a consensus-adjacent change with a gas or accounting change. The May 2026 incident chain started with exactly that kind of interaction.
5. **Upstream lag:** follow upstream Sui releases after they have run **≥ 8 weeks on Sui mainnet** without a related incident, except security patches (triaged within 24 h).
