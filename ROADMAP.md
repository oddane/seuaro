# Roadmap

Seuaro moves to mainnet only when every [launch gate](docs/operations/LAUNCH-GATES.md) passes. Dates depend on evidence, not on the calendar.

## Now: testnet foundation
- [x] Proven-techniques policy, threat model, invariants, launch gates
- [x] Pinned upstream build with branding-only patches and license compliance
- [x] Light client, devnet acceptance tests, container testnet, fault injection
- [x] Payment, invoice and compute contracts
- [ ] CI green end-to-end on all components
- [ ] First tagged testnet release with a published image

## Next: product
- [ ] Seuaro Pay gas station (sponsored transactions from capped vaults), ADR-0003
- [ ] Regulated stablecoin issuer partnership (business), COMPETITIVE-ANALYSIS P7
- [ ] Test stablecoin and merchant checkout demo on testnet
- [ ] Deterministic compute job specification (ADR-0007) and a pilot workload
- [ ] ADR-0005 (upgrades and emergency powers), ADR-0006 (settlement UX)
- [ ] On-chain coin metadata verified in wallets

## Later: decentralization and assurance
- [ ] Independent validators across ≥ 5 ASNs meeting ADR-0004
- [ ] Multi-region public testnet; W1–W7 benchmarks reproduced by a third party
- [ ] Independent audits of patches, contracts and light client
- [ ] Public bug bounty
- [ ] 30-day clean soak after the last consensus-affecting change
- [ ] Legal sign-off on SEU, payments and compute (docs/legal/COUNSEL-CHECKLIST.md)

## Deferred until their components are proven
Shielded payments, native post-quantum accounts, light-client bridges (see the [register](docs/architecture/PROVEN-TECHNIQUES.md)).
