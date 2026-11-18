#!/usr/bin/env python3
"""Write THIRD-PARTY-LICENSES.md for the crates compiled into the given binaries.

Reads `cargo metadata --format-version 1` on stdin; arguments are the root
packages (e.g. sui sui-node sui-faucet seuaro-verify). Lists every package in
their normal (non-dev) dependency closure with its version, license and source.
Packages without license metadata are listed as UNKNOWN and reported on
stderr; set SEUARO_STRICT_LICENSES=1 to make that an error (release builds).
"""
import json
import os
import sys


def main():
    roots = set(sys.argv[1:])
    meta = json.load(sys.stdin)
    pkgs = {p["id"]: p for p in meta["packages"]}
    nodes = {n["id"]: n for n in meta["resolve"]["nodes"]}
    start = [pid for pid, p in pkgs.items() if p["name"] in roots and pid in nodes]
    missing_roots = roots - {pkgs[pid]["name"] for pid in start}
    if missing_roots:
        sys.exit(f"root packages not found: {sorted(missing_roots)}")

    seen, stack = set(), list(start)
    while stack:
        pid = stack.pop()
        if pid in seen:
            continue
        seen.add(pid)
        for dep in nodes[pid].get("deps", []):
            kinds = {k.get("kind") for k in dep.get("dep_kinds", [])}
            if kinds and kinds <= {"dev"}:
                continue
            stack.append(dep["pkg"])

    rows, unknown = [], []
    for pid in seen:
        p = pkgs[pid]
        lic = p.get("license") or ("see license file" if p.get("license_file") else None)
        if lic is None:
            unknown.append(f'{p["name"]} {p["version"]}')
            lic = "UNKNOWN"
        src = p.get("repository") or ("local" if p.get("source") is None else p.get("source"))
        rows.append((p["name"], p["version"], lic, src))
    rows.sort()

    out = sys.stdout
    out.write("# Third-Party Licenses\n\n")
    out.write("Generated at build time from the exact dependency graph of the shipped binaries "
              f"({', '.join(sorted(roots))}). Full license texts are in each package's source.\n\n")
    out.write(f"{len(rows)} packages.\n\n| Package | Version | License | Source |\n|---|---|---|---|\n")
    for name, ver, lic, src in rows:
        out.write(f"| {name} | {ver} | {lic} | {src} |\n")
    if unknown:
        sys.stderr.write("WARNING: packages without license metadata (review before release):\n  "
                         + "\n  ".join(unknown) + "\n")
        if os.environ.get("SEUARO_STRICT_LICENSES") == "1":
            sys.exit(1)


if __name__ == "__main__":
    main()
