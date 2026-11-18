# Contributing to Seuaro

## License of contributions
Seuaro is licensed under the Apache License 2.0. By contributing you agree that your contribution is licensed under the same terms (Apache-2.0, section 5).

## Developer Certificate of Origin
Every commit must be signed off, certifying the [Developer Certificate of Origin 1.1](https://developercertificate.org/): you wrote the change or otherwise have the right to submit it under the project license.

```
git commit -s -m "Your message"
```
This adds `Signed-off-by: Your Name <you@example.com>`. Use your real name.

## Rules
- **No upstream changes outside `patches/`.** Every change to upstream behavior is a numbered patch, listed in `docs/architecture/FORK-DELTA.md`, and needs two reviewers.
- **Keep upstream notices.** Never remove copyright or license headers from upstream files. New files carry `// Copyright (c) Seuaro contributors` and `// SPDX-License-Identifier: Apache-2.0`.
- **No third-party code without a compatible license.** Allowed: Apache-2.0, MIT, BSD, ISC, Zlib, Unicode, CC0. Anything else needs maintainer approval.
- **No Sui branding** in anything users see (TRADEMARKS.md).
- **No secrets.** Never commit keys, seeds, `devnet/` or `net/` state.
- **AI-generated code** is welcome but is treated as untrusted: it needs tests and a human reviewer like any other change.
- Consensus, cryptography, gas, serialization, genesis and upgrade code require two reviewers.
