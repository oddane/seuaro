# Questions for Legal Counsel (before any public launch)

This is an engineering checklist of questions to take to qualified lawyers. It is **not legal advice** and does not answer any of these questions. Each item should be answered in writing by counsel licensed in the relevant jurisdictions; the answers then become launch-gate evidence (LAUNCH-GATES G4).

## 1. Entity and liability
- [ ] Which legal entity (or entities) develops the software, runs the foundation/treasury, and holds IP and trademarks? Where should each be incorporated?
- [ ] Liability for open-source software we publish, and for operating testnets.
- [ ] Contributor terms (DCO is in place; is a CLA also needed?).

## 2. The SEU coin
- [ ] Is SEU a security, crypto-asset or other regulated instrument in each target market (e.g. US, EU, UK, Singapore)? What must change in ADR-0002 (allocation, vesting, foundation holdings, staking rewards) to reduce that risk?
- [ ] Is any sale, presale, airdrop, validator delegation program, staking reward or testnet reward a regulated offering or distribution?
- [ ] Disclosure documents required (e.g. a crypto-asset white paper in the EU) and who must publish them.
- [ ] Rules for team and investor tokens, lock-ups, and market conduct (insider trading, market manipulation).
- [ ] Tax treatment of genesis allocation, staking rewards and validator commissions.

## 3. Payments
- [ ] Does operating the Seuaro Pay gas station, invoices or merchant escrow make any entity a money transmitter, payment institution or virtual-asset service provider?
- [ ] AML/KYC and sanctions-screening obligations for foundation-run services (gas station, faucet, explorer, RPC).
- [ ] Requirements and contract terms for a stablecoin issuer partnership.
- [ ] Consumer-protection and disclosure duties for merchants using escrow and refunds.

## 4. Compute marketplace
- [ ] Classification of compute jobs, provider bonds and verifier roles; liability for wrong results.
- [ ] Data-protection obligations if jobs process personal data.

## 5. Intellectual property
- [ ] Confirm compliance with Apache-2.0 and CC BY 4.0 for upstream code and docs (NOTICE, THIRD-PARTY-LICENSES.md).
- [ ] Confirm the TRADEMARKS.md position: no Sui branding; listed internal identifiers (e.g. type path `0x2::sui::SUI`) acceptable as technical interfaces.
- [ ] Clearance search and registration for "Seuaro" and "SEU" in relevant classes and jurisdictions.
- [ ] Patents: any known patents on the consensus or verification methods used.

## 6. Operations and users
- [ ] Terms of service and privacy policy for websites, explorer, RPC and faucet.
- [ ] Validator agreements, delegation-program terms and infrastructure-disclosure rules (ADR-0004).
- [ ] Incident disclosure duties after outages or vulnerabilities.
- [ ] Export controls on cryptographic software.
