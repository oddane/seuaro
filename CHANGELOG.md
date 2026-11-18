# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases use [Semantic Versioning](https://semver.org/) with a `-testnet` suffix until mainnet.

## [Unreleased]

### Added
- **Phase 1:** pinned upstream build (`UPSTREAM.lock`), independent genesis, single-process devnet, `seuaro-verify` light client with tamper self-tests, acceptance tests (API-01, CONS-01/05, AUTH-01, LEDGER-04).
- **Payments:** `seuaro_payments` Move package: `turnstile`, `vault`, `escrow`, `invoice`, with unit tests and an end-to-end devnet test.
- **Compute:** `seuaro_compute` Move package: job escrow, provider bonds, optimistic challenge window, commit-reveal verifier voting.
- **Container testnet:** multi-party genesis ceremony, four validators, full node, faucet, Prometheus, Grafana and explorer; fault-injection tests.
- **Economics:** ADR-0002 (Seuaro/SEU, fixed 10B supply, allocation, staking schedule) and ADR-0003 (fees and sponsorship); testnet genesis uses them.
- **Decentralization:** ADR-0004 concentration limits and `decentralization-report.py`.
- **Legal and licensing:** LICENSE, NOTICE, TRADEMARKS, DISCLAIMER, SECURITY, CONTRIBUTING (DCO), license audit, counsel checklist, generated THIRD-PARTY-LICENSES.
- **Branding patches:** native coin metadata SEU/Seuaro; programs `seuaro`, `seuaro-node`, `seuaro-faucet`.
- **Run tooling:** `quickstart.sh`, `net-up.sh --image`, CI image publishing to GHCR.
- **Repository:** brand assets, architecture document, issue forms, PR template, CODEOWNERS, governance and support docs.

### Fixed
- Build of pinned RocksDB 8.10 on GCC 13+ (`-include cstdint`).
- Upstream default node configuration pointed at the upstream mainnet key-value store; genesis now blanks it.
