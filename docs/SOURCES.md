# Research sources — reviewed 2026-11-18

Legend: **[V]** content checked for v0.4; **[C]** carried over from v0.3, link not re-checked.

## Consensus, execution and incidents
1. [V] Sui Jan 14 2026 consensus incident: https://www.sui.io/blog/sui-mainnet-network-stall-resolution
2. [V] Sui May 28–29 2026 upgrade incidents: https://www.sui.io/blog/sui-mainnet-halts-resolved-after-major-upgrade
3. [V] Mysticeti design and production results (Kokoris Kogias, Sonnino, Danezis): https://decentralizedthoughts.github.io/2026-03-06-mysticeti-revolutionizing-consensus-on-sui
4. [C] Sui Mysticeti consensus architecture: https://docs.sui.io/develop/sui-architecture/consensus
5. [C] Sui transaction lifecycle and certified effects: https://docs.sui.io/develop/transactions/transaction-lifecycle
6. [C] Yale mechanized Mysticeti paper (modified protocol, liveness caveat): https://www.cs.yale.edu/flint/certikos/publications/sp26.html
7. [C] Sui Move Prover research summary: https://www.sui.io/blog/asymptotic-move-prover-formal-verification
8. [C] Sui source tree/license: https://github.com/MystenLabs/sui
9. [V] Solana Alpenglow status (activated 2026-10-21; ~150 ms target): https://solana.com/upgrades/alpenglow — *replaces the v0.3 roundup link*
10. [C] Ethereum Foundation 2026 protocol priorities: https://blog.ethereum.org/2026/02/18/protocol-priorities-update-2026

## Accounts and cryptography
11. [V] Sui post-quantum plan (ML-DSA-65 native; SLH-DSA in Move vaults; mainnet Q1 2027 target): https://www.sui.io/blog/making-sui-quantum-ready
12. [C] NIST FIPS 204 (ML-DSA): https://csrc.nist.gov/pubs/fips/204/final
13. [V] Sui zkLogin: https://docs.sui.io/build/zk_login
14. [V] Sui passkey on mainnet: https://www.sui.io/blog/passkey-seamless-user-onboarding

## Privacy and proofs
15. [V] Zcash Orchard soundness flaw, CVE-2026-54496: https://dbugs.ptsecurity.com/vulnerability/PT-2026-56057
16. [V] zkSecurity post-fix Orchard audit with formal circuit verification (July 2026): https://reports.zksecurity.xyz/reports/zcash-orchard.md
17. [V] RISC Zero rv32im soundness flaw (CVE-2025-52484) and 2025 ZK vulnerability review: https://cantina.xyz/blog/cantina-x-zksync-the-2026-guide-to-securing-zkps
18. [V] SP1 security update (Jan 2025): https://blog.succinct.xyz/sp1-security-update-1-27-25/
19. [V] zkVM differential fuzzing results (zkvmBlast): https://blog.zksecurity.xyz/posts/zkvmblast/
20. [C] RISC Zero zkVM docs: https://dev.risczero.com/zkvm/quickstart

## TEEs and bridges
21. [V] TEE.fail (SGX/TDX/SEV-SNP key extraction): https://thehackernews.com/2025/10/new-teefail-side-channel-attack.html
22. [V] IBC's clean production record (Blockworks, Apr 2026): https://blockworks.com/insights/ibc-neglected-bridge

## Process
23. [C] NIST SSDF SP 800-218: https://csrc.nist.gov/pubs/sp/800/218/final
24. [C] Sui local network instructions: https://docs.sui.io/getting-started/onboarding/local-network

All benchmark targets are proposed, not demonstrated for Seuaro. Vendor targets and external benchmarks do not transfer automatically to an independent fork.
