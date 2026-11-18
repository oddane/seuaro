#!/usr/bin/env python3
"""Small helpers for the devnet scripts. Standard library only; run with `python3 -I`."""
import json
import re
import sys
from pathlib import Path


def fail(msg):
    print(f"[seuaro] ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def check_config(config_dir):
    """Reject node configs that could pull data from Sui's own networks.

    With the mainnet chain override (ADR-0008), a non-empty
    transaction_kv_store_read_config.base_url would make a node fall back to
    Sui mainnet's key-value store for missing data.
    """
    files = sorted(p for p in Path(config_dir).glob("*.yaml") if p.name != "client.yaml")
    if not files:
        fail(f"no node yaml configs in {config_dir}")
    for f in files:
        text = f.read_text()
        for m in re.finditer(r"transaction[-_]kv[-_]store[-_]read[-_]config:\s*\n((?:[ \t]+.*\n)*)", text):
            url = re.search(r"base[-_]url:\s*(\S*)", m.group(1))
            if url and url.group(1) not in ("", '""', "''", "~", "null"):
                fail(f"{f.name}: transaction_kv_store_read_config.base_url must be empty, found {url.group(1)}")
        for ext in sorted(set(re.findall(r"https?://[^\s\"']*(?:sui\.io|mystenlabs\.com)[^\s\"']*", text))):
            print(f"[seuaro] WARNING: {f.name} references external endpoint {ext}", file=sys.stderr)
    print(f"[seuaro] {len(files)} node configs checked: no Sui key-value store fallback")


KV_BLOCK = re.compile(
    r"(transaction[-_]kv[-_]store[-_]read[-_]config:[ \t]*\n(?:[ \t]+[^\n]*\n)*?[ \t]+base[-_]url:[ \t]*)(\S+)")


def scrub_config(config_dir):
    """Blank the upstream default that points nodes at Sui mainnet's KV store.

    Upstream node configs default transaction_kv_store_read_config.base_url to
    https://transactions.sui.io/. With the mainnet chain override (ADR-0008)
    a node would fall back to Sui mainnet data for anything missing locally.
    """
    changed = 0
    for f in sorted(p for p in Path(config_dir).glob("*.yaml") if p.name != "client.yaml"):
        text = f.read_text()
        new, n = KV_BLOCK.subn(lambda m: m.group(1) + '""', text)
        if n:
            f.write_text(new)
            changed += n
    print(f"[seuaro] blanked {changed} key-value store fallback URL(s)")


def _walk(obj):
    if isinstance(obj, dict):
        yield obj
        for v in obj.values():
            yield from _walk(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from _walk(v)


def _load_json(text):
    # The CLI may print log lines before the JSON document.
    start = min([i for i in (text.find("{"), text.find("[")) if i >= 0], default=-1)
    if start < 0:
        fail("no JSON in command output:\n" + text[:2000])
    return json.loads(text[start:])


def largest_coin(path):
    data = _load_json(Path(path).read_text())
    best = None
    for d in _walk(data):
        cid = d.get("gasCoinId") or d.get("gas_coin_id")
        bal = d.get("mistBalance", d.get("mist_balance"))
        if cid and bal is not None and (best is None or int(bal) > best[1]):
            best = (cid, int(bal))
    if not best:
        fail("no gas coins found")
    print(best[0])


def coins(path):
    """Print all gas coin IDs, largest balance first."""
    data = _load_json(Path(path).read_text())
    found = {}
    for d in _walk(data):
        cid = d.get("gasCoinId") or d.get("gas_coin_id")
        bal = d.get("mistBalance", d.get("mist_balance"))
        if cid and bal is not None:
            found[cid] = int(bal)
    for cid, _ in sorted(found.items(), key=lambda kv: -kv[1]):
        print(cid)


def tx_digest(path):
    data = _load_json(Path(path).read_text())
    for d in _walk(data):
        if "transactionDigest" in d:
            print(d["transactionDigest"])
            return
    if isinstance(data, dict) and "digest" in data:
        print(data["digest"])
        return
    fail("no transaction digest in output")


def tx_succeeded(path):
    data = _load_json(Path(path).read_text())
    for d in _walk(data):
        st = d.get("status")
        if isinstance(st, dict) and "status" in st:
            if st["status"] != "success":
                fail(f"transaction failed: {st}")
            print("success")
            return
    fail("no execution status in output")


def addresses(path):
    data = _load_json(Path(path).read_text())
    active = data.get("activeAddress") or data.get("active_address")
    others = [a[1] for a in data.get("addresses", []) if a[1] != active]
    print(active)
    for a in others or [active]:
        print(a)


def field(path, key):
    print(_load_json(Path(path).read_text())[key])


def package_id(path):
    data = _load_json(Path(path).read_text())
    for d in _walk(data):
        if d.get("type") == "published" and "packageId" in d:
            print(d["packageId"])
            return
    fail("no published package in output")


def created(path, type_substr):
    data = _load_json(Path(path).read_text())
    for d in _walk(data):
        if d.get("type") == "created" and type_substr in str(d.get("objectType", "")):
            print(d["objectId"])
            return
    fail(f"no created object of type *{type_substr}*")


def event_field(path, event_substr, key):
    data = _load_json(Path(path).read_text())
    for d in _walk(data):
        if event_substr in str(d.get("type", "")) and isinstance(d.get("parsedJson"), dict):
            print(d["parsedJson"][key])
            return
    fail(f"no event *{event_substr}* in output")


COMMANDS = {
    "check-config": check_config,
    "scrub-config": scrub_config,
    "largest-coin": largest_coin,
    "coins": coins,
    "tx-digest": tx_digest,
    "tx-succeeded": tx_succeeded,
    "addresses": addresses,
    "field": field,
    "package-id": package_id,
    "created": created,
    "event-field": event_field,
}

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in COMMANDS:
        fail(f"usage: devnet_tool.py {{{','.join(COMMANDS)}}} ARGS...")
    COMMANDS[sys.argv[1]](*sys.argv[2:])
