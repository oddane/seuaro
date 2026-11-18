# Security Policy

## Reporting a vulnerability
Please **do not** open a public issue for security problems.

Report privately through GitHub's private vulnerability reporting: **Security → Report a vulnerability** on this repository. Include affected component and version (commit), steps to reproduce, impact, and any proof of concept.

We aim to acknowledge reports within 2 business days and to give a remediation plan within 10 business days. Please allow up to 90 days for a fix before public disclosure; we will credit reporters who want credit.

## Scope
- In scope: everything in this repository (scripts, `tools/seuaro-verify`, Move packages in `packages/`, container setup, patches).
- Upstream code: vulnerabilities in the pinned Sui source should also be reported to the upstream project under its own policy. We track upstream advisories and patch within 24 hours of triage (docs/delivery/IMPLEMENTATION.md).

## Status
Seuaro is unaudited testnet software. There is no bug bounty yet; one is a launch gate (docs/operations/LAUNCH-GATES.md, G5).
