#!/usr/bin/env python3
"""Seuaro decentralization report (ADR-0004).

Reads the live validator set from a full node and reports how concentrated
control is: by validator, and by the infrastructure each validator discloses
in its on-chain description as `asn=...; provider=...; region=...`.

Why: in August 2026 a single routing failure at one hosting network took
~29% of Solana's stake offline and brought it within a few points of the 1/3
finality-halt threshold. Concentration hides in shared providers, not in
validator counts. Thresholds below follow Solana's own delegation-program
caps (<25% of stake per ASN, <=15% per data center).

Usage: decentralization-report.py [--rpc URL] [--enforce]
Exit code 1 with --enforce if any policy limit is exceeded.
"""
import argparse
import json
import re
import sys
import urllib.request

HALT = 1 / 3          # BFT: this much stake offline stops finality
LIMITS = {            # max share of total voting power per group
    "validator": 0.10,
    "operator": 0.15,
    "asn": 0.25,
    "provider": 0.25,
    "region": 0.33,
}


def rpc(url, method, params=None):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}).encode()
    req = urllib.request.Request(url, body, {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=20) as r:
        res = json.load(r)
    if "error" in res:
        raise SystemExit(f"RPC error: {res['error']}")
    return res["result"]


def tags(description):
    found = dict(re.findall(r"(asn|provider|region|operator)\s*=\s*([^;\s]+)", description or "", re.I))
    return {k.lower(): v for k, v in found.items()}


def nakamoto(shares):
    """Fewest entities whose combined power reaches the halt threshold."""
    total, n = 0.0, 0
    for s in sorted(shares, reverse=True):
        total += s
        n += 1
        if total >= HALT:
            return n
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rpc", default="http://127.0.0.1:9000")
    ap.add_argument("--enforce", action="store_true")
    args = ap.parse_args()

    state = rpc(args.rpc, "suix_getLatestSuiSystemState")
    vals = state["activeValidators"]
    power = {v["suiAddress"]: int(v.get("votingPower", 0)) for v in vals}
    total = sum(power.values()) or 1

    groups = {k: {} for k in LIMITS}
    for v in vals:
        share = power[v["suiAddress"]] / total
        t = tags(v.get("description", ""))
        keys = {
            "validator": v.get("name") or v["suiAddress"],
            "operator": t.get("operator", v.get("name") or v["suiAddress"]),
            "asn": t.get("asn", "undisclosed"),
            "provider": t.get("provider", "undisclosed"),
            "region": t.get("region", "undisclosed"),
        }
        for g, key in keys.items():
            groups[g][key] = groups[g].get(key, 0.0) + share

    print(f"Seuaro decentralization report — epoch {state['epoch']}, {len(vals)} validators")
    violations = []
    for g, limit in LIMITS.items():
        shares = groups[g]
        top = sorted(shares.items(), key=lambda kv: -kv[1])
        print(f"\n{g}: Nakamoto coefficient {nakamoto(shares.values())} "
              f"(entities needed to reach 1/3 and halt finality); limit {limit:.0%} each")
        for key, s in top[:8]:
            flag = ""
            if s > limit:
                flag = "  <-- OVER LIMIT"
                violations.append(f"{g} '{key}' holds {s:.1%} (limit {limit:.0%})")
            if s >= HALT:
                flag = "  <-- CAN HALT FINALITY ALONE"
            print(f"  {s:7.2%}  {key}{flag}")

    undisclosed = groups["asn"].get("undisclosed", 0.0)
    if undisclosed > 0:
        violations.append(f"{undisclosed:.1%} of stake does not disclose its ASN/provider")

    print()
    if violations:
        print("Policy findings:")
        for v in violations:
            print(f"  - {v}")
    else:
        print("All ADR-0004 concentration limits met.")
    if args.enforce and violations:
        sys.exit(1)


if __name__ == "__main__":
    main()
