#!/usr/bin/env python3
"""Seuaro container entrypoint.

Roles (first argument):
  ceremony-init        create the genesis ceremony, test accounts and config templates
  validator-join NAME  (in validator NAME's container) generate keys, add to ceremony
  ceremony-distribute  write the token distribution schedule (test allocation)
  ceremony-build       build the unsigned genesis checkpoint
  validator-sign NAME  (in validator NAME's container) verify and sign genesis
  ceremony-finalize    combine signatures into genesis.blob
  validator NAME       run a validator
  fullnode             run the public full node (RPC + checkpoint files)
  faucet               run the faucet against the full node
  exec CMD...          run any command (client, verifier, ...)

Private keys of a validator are generated and kept only in that validator's
/opt/sui/key-pairs volume. The shared /ceremony volume only ever receives
public validator info and signatures, as in Sui's own mainnet ceremony.
"""
import csv
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

import yaml

CEREMONY = "/ceremony"
KEYS = "/opt/sui/key-pairs"
DB = "/opt/sui/db"
CHECKPOINTS = "/opt/sui/checkpoints"
USERS = "/users"
TEMPLATES = f"{CEREMONY}/templates"
GENESIS = f"{CEREMONY}/genesis.blob"

MIST_PER_SUI = 10**9
TOTAL_SUPPLY_MIST = 10_000_000_000 * MIST_PER_SUI
VALIDATOR_STAKE_MIST = 30_000_000 * MIST_PER_SUI  # MIN_VALIDATOR_JOINING_STAKE
FAUCET_MIST = 1_000_000_000 * MIST_PER_SUI
TEST_USER_MIST = 100_000_000 * MIST_PER_SUI
TEST_USERS = ["buyer", "merchant", "arbiter"]
ZERO_ADDRESS = "0x" + "0" * 64


def log(msg):
    print(f"[seuaro] {msg}", file=sys.stderr, flush=True)


def die(msg):
    log(f"ERROR: {msg}")
    sys.exit(1)


def run(*cmd, cwd=None, env=None):
    log("$ " + " ".join(cmd))
    res = subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)
    if res.returncode != 0:
        sys.stderr.write(res.stdout + res.stderr)
        die(f"command failed ({res.returncode}): {cmd[0]} {cmd[1] if len(cmd) > 1 else ''}")
    return res.stdout


def check_env():
    if os.environ.get("SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE") != "mainnet":
        die("SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE must be 'mainnet' (ADR-0008)")
    bad = [k for k in os.environ if k.startswith("SUI_PROTOCOL_CONFIG_OVERRIDE")]
    if bad:
        die(f"forbidden protocol overrides set: {bad}")


def ceremony(*args):
    return run("sui", "genesis-ceremony", "--path", CEREMONY, *args)


def scratch_client_config(root):
    """Minimal client config so the CLI neither prompts nor creates (and prints) a key."""
    cfg = os.path.join(root, "client-config")
    os.makedirs(cfg, exist_ok=True)
    with open(os.path.join(cfg, "sui.keystore"), "w") as f:
        f.write("[]")
    with open(os.path.join(cfg, "client.yaml"), "w") as f:
        f.write(f"keystore:\n  File: {cfg}/sui.keystore\nexternal_keys: ~\nenvs:\n"
                "  - alias: local\n    rpc: http://127.0.0.1:9000\n    ws: ~\n    basic_auth: ~\n"
                "active_env: local\nactive_address: ~\n")
    return dict(os.environ, SUI_CONFIG_DIR=cfg)


def gen_key(scheme):
    """Generate a key with `sui keytool`; returns (address, base64 file content)."""
    with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as cfg_root:
        run("sui", "keytool", "generate", scheme, "--json", cwd=d,
            env=scratch_client_config(cfg_root))
        files = glob.glob(os.path.join(d, "*.key"))
        if len(files) != 1:
            die(f"expected one key file from keytool, found {files}")
        content = open(files[0]).read().strip()
        addr = os.path.basename(files[0])[: -len(".key")]
        if addr.startswith("bls-"):
            addr = addr[len("bls-"):]
        return addr, content


def write_private(path, content):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(content)


def write_client_config(dirname, keys, active, rpc):
    os.makedirs(dirname, exist_ok=True)
    write_private(os.path.join(dirname, "sui.keystore"), json.dumps(keys, indent=2))
    cfg = {
        "keystore": {"File": os.path.join(dirname, "sui.keystore")},
        "external_keys": None,
        "envs": [{"alias": "seuaro", "rpc": rpc, "ws": None, "basic_auth": None}],
        "active_env": "seuaro",
        "active_address": active,
    }
    with open(os.path.join(dirname, "client.yaml"), "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)


# --- ceremony ---------------------------------------------------------------

def ceremony_init():
    if os.path.exists(os.path.join(CEREMONY, "parameters")):
        die("ceremony already initialised; remove the ceremony volume to start over")
    ceremony("init")

    epoch_ms = int(os.environ.get("SEUARO_EPOCH_MS", "30000"))
    pfile = os.path.join(CEREMONY, "parameters")
    params = yaml.safe_load(open(pfile))
    key = next((k for k in params if "epoch" in k and "duration" in k), None)
    if key is None:
        die(f"no epoch duration field in {pfile}: {list(params)}")
    params[key] = epoch_ms
    with open(pfile, "w") as f:
        yaml.safe_dump(params, f, sort_keys=False)
    log(f"epoch duration set to {epoch_ms} ms")

    # Test accounts (testnet only). Each gets its own keystore directory.
    addresses, all_keys = {}, []
    for name in ["faucet"] + TEST_USERS:
        addr, key = gen_key("ed25519")
        addresses[name] = addr
        all_keys.append(key)
        write_client_config(os.path.join(USERS, name), [key], addr, "http://fullnode:9000")
    write_client_config(USERS, all_keys, addresses["buyer"], "http://fullnode:9000")
    with open(os.path.join(USERS, "addresses.json"), "w") as f:
        json.dump(addresses, f, indent=2)

    # Config templates generated by the pinned binary itself, so every field
    # matches this exact version. Their throwaway keys are replaced at render time.
    with tempfile.TemporaryDirectory() as d:
        run("sui", "genesis", "--working-dir", d, "--committee-size", "1")
        os.makedirs(TEMPLATES, exist_ok=True)
        skip = {"network.yaml", "fullnode.yaml", "client.yaml"}
        vals = [p for p in glob.glob(os.path.join(d, "*.yaml")) if os.path.basename(p) not in skip]
        if len(vals) != 1:
            die(f"expected one validator template, found {vals}")
        shutil.copy(vals[0], os.path.join(TEMPLATES, "validator.yaml"))
        shutil.copy(os.path.join(d, "fullnode.yaml"), os.path.join(TEMPLATES, "fullnode.yaml"))
    log("ceremony initialised")


def validator_join(name):
    os.makedirs(KEYS, exist_ok=True)
    files = {
        "protocol": ("bls12381", "protocol.key"),
        "account": ("ed25519", "account.key"),
        "network": ("ed25519", "network.key"),
        "worker": ("ed25519", "worker.key"),
    }
    for _, (scheme, fname) in files.items():
        path = os.path.join(KEYS, fname)
        if not os.path.exists(path):
            _, content = gen_key(scheme)
            write_private(path, content)
    ceremony(
        "add-validator",
        "--name", name,
        "--validator-key-file", os.path.join(KEYS, "protocol.key"),
        "--worker-key-file", os.path.join(KEYS, "worker.key"),
        "--account-key-file", os.path.join(KEYS, "account.key"),
        "--network-key-file", os.path.join(KEYS, "network.key"),
        "--network-address", f"/dns/{name}/tcp/8080/http",
        "--p2p-address", f"/dns/{name}/udp/8084",
        "--narwhal-primary-address", f"/dns/{name}/udp/8081",
        "--narwhal-worker-address", f"/dns/{name}/udp/8082",
        "--description", f"Seuaro test validator {name}; operator={name}; asn=AS-LOCAL; provider=docker; region=local",
        "--image-url", "https://example.invalid/validator.png",
        "--project-url", "https://example.invalid",
    )
    log(f"{name} joined the ceremony (keys stay in this container's volume)")


def ceremony_distribute():
    out = ceremony("list-validators")
    rows = list(csv.DictReader(out.strip().splitlines()))
    if not rows:
        die("no validators in ceremony")
    users = json.load(open(os.path.join(USERS, "addresses.json")))

    allocations = []
    for r in rows:
        addr = r["account-address"]
        allocations.append((addr, VALIDATOR_STAKE_MIST, addr))
    allocations.append((users["faucet"], FAUCET_MIST, ""))
    for u in TEST_USERS:
        allocations.append((users[u], TEST_USER_MIST, ""))
    subsidy = TOTAL_SUPPLY_MIST - sum(a[1] for a in allocations)
    if subsidy < 0:
        die("allocations exceed total supply")

    with open(os.path.join(CEREMONY, "token-distribution-schedule"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["recipient-address", "amount-mist", "staked-with-validator"])
        for addr, amt, staked in allocations:
            w.writerow([addr, amt, staked])
        w.writerow([ZERO_ADDRESS, subsidy, ""])  # stake subsidy fund, must be last
    log(f"test token distribution written: {len(rows)} validators staked, "
        f"{1 + len(TEST_USERS)} funded accounts, subsidy fund {subsidy // MIST_PER_SUI} SUI")


def ceremony_build():
    print(ceremony("build-unsigned-checkpoint"))


def validator_sign(name):
    ceremony("verify-and-sign", "--key-file", os.path.join(KEYS, "protocol.key"))
    log(f"{name} signed the genesis checkpoint")


def ceremony_finalize():
    print(ceremony("finalize"))
    if not os.path.exists(GENESIS):
        die("genesis.blob not produced")


# --- node configs -------------------------------------------------------------

def scrub_external(cfg):
    """Never read Sui's own networks (ADR-0008 R1)."""
    kv = cfg.get("transaction-kv-store-read-config")
    if isinstance(kv, dict) and kv.get("base-url"):
        kv["base-url"] = ""
    cfg.pop("state-archive-read-config", None)


def common(cfg):
    cfg["metrics-address"] = "0.0.0.0:9184"
    cfg["admin-interface-port"] = 1337
    cfg["genesis"] = {"genesis-file-location": GENESIS}
    p2p = cfg.setdefault("p2p-config", {})
    p2p["listen-address"] = "0.0.0.0:8084"
    scrub_external(cfg)


def render_validator(name):
    cfg = yaml.safe_load(open(os.path.join(TEMPLATES, "validator.yaml")))
    for k in ["protocol", "worker", "account", "network"]:
        cfg[f"{k}-key-pair"] = {"path": os.path.join(KEYS, f"{k}.key")}
    cfg["db-path"] = os.path.join(DB, "authorities_db")
    cfg["network-address"] = "/ip4/0.0.0.0/tcp/8080/http"
    cfg["json-rpc-address"] = "0.0.0.0:9000"
    cc = cfg.get("consensus-config")
    if not isinstance(cc, dict):
        die("validator template has no consensus-config")
    cc["db-path"] = os.path.join(DB, "consensus_db")
    cc.pop("listen-address", None)
    cc.pop("external-address", None)
    common(cfg)
    cfg["p2p-config"]["external-address"] = f"/dns/{name}/udp/8084"
    cfg["p2p-config"].pop("seed-peers", None)
    path = os.path.join(KEYS, "node.yaml")
    with open(path, "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)
    return path


def render_fullnode():
    cfg = yaml.safe_load(open(os.path.join(TEMPLATES, "fullnode.yaml")))
    cfg["db-path"] = os.path.join(DB, "full_node_db")
    cfg["network-address"] = "/ip4/0.0.0.0/tcp/8080/http"
    cfg["json-rpc-address"] = "0.0.0.0:9000"
    common(cfg)
    validators = [v.strip() for v in os.environ.get("SEUARO_VALIDATORS", "v1,v2,v3,v4").split(",")]
    cfg["p2p-config"]["external-address"] = "/dns/fullnode/udp/8084"
    cfg["p2p-config"]["seed-peers"] = [{"address": f"/dns/{v}/udp/8084"} for v in validators]
    cec = cfg.setdefault("checkpoint-executor-config", {})
    cec["data-ingestion-dir"] = CHECKPOINTS
    os.makedirs(CHECKPOINTS, exist_ok=True)
    path = os.path.join(DB, "fullnode.yaml")
    with open(path, "w") as f:
        yaml.safe_dump(cfg, f, sort_keys=False)
    return path


def wait_for_genesis():
    for _ in range(300):
        if os.path.exists(GENESIS):
            return
        time.sleep(1)
    die("genesis.blob did not appear in /ceremony")


def run_validator(name):
    check_env()
    wait_for_genesis()
    if not os.path.exists(os.path.join(KEYS, "protocol.key")):
        die(f"{name} has no keys; it must join the ceremony first")
    path = render_validator(name)
    os.execvp("sui-node", ["sui-node", "--config-path", path])


def run_fullnode():
    check_env()
    wait_for_genesis()
    path = render_fullnode()
    os.execvp("sui-node", ["sui-node", "--config-path", path])


def run_faucet():
    check_env()
    env = dict(os.environ, SUI_CONFIG_DIR=os.path.join(USERS, "faucet"))
    for _ in range(300):
        res = subprocess.run(["sui", "client", "--client.config",
                              os.path.join(USERS, "faucet", "client.yaml"), "chain-identifier"],
                             capture_output=True, text=True, env=env)
        if res.returncode == 0:
            break
        time.sleep(2)
    else:
        die("full node RPC never became ready")
    os.execvpe("sui-faucet", ["sui-faucet", "--host-ip", "0.0.0.0", "--port", "5003",
                              "--amount", str(10 * MIST_PER_SUI)], env)


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("help", "-h", "--help"):
        print(__doc__)
        return
    role, args = sys.argv[1], sys.argv[2:]
    name = args[0] if args else os.environ.get("SEUARO_NODE_NAME", "")
    roles = {
        "ceremony-init": ceremony_init,
        "validator-join": lambda: validator_join(name),
        "ceremony-distribute": ceremony_distribute,
        "ceremony-build": ceremony_build,
        "validator-sign": lambda: validator_sign(name),
        "ceremony-finalize": ceremony_finalize,
        "validator": lambda: run_validator(name),
        "fullnode": run_fullnode,
        "faucet": run_faucet,
    }
    if role == "exec":
        check_env()
        os.execvp(args[0], args)
    if role not in roles:
        die(f"unknown role {role}")
    if role.startswith("validator") and not name:
        die(f"{role} needs a validator name")
    check_env()
    roles[role]()


if __name__ == "__main__":
    main()
