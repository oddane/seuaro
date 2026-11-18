#!/usr/bin/env bash
# Phase 1 acceptance tests against a running devnet (scripts/devnet-up.sh).
#
# Covers: API-01, CONS-01, CONS-05, AUTH-01, LEDGER-04 (see docs/security/INVARIANTS.md).
# Each check prints PASS/FAIL; the script exits non-zero on the first failure.
source "$(dirname "$0")/../scripts/lib.sh"
check_protocol_env
SUI="$(sui_bin)"
VERIFY="$(verify_bin)"
TOOL=(python3 -I "$SEUARO_ROOT/scripts/devnet_tool.py")
CLIENT=(--client.config "$(client_config)")
GENESIS="$CONFIG_DIR/genesis.blob"
WORK="$DEVNET_DIR/test-work"
rm -rf "$WORK" && mkdir -p "$WORK"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

verify() { "$VERIFY" --genesis "$GENESIS" --checkpoints "$INGEST_DIR" "$@"; }

wait_final() { # digest -> waits until the verifier reports FINAL
  local d="$1"
  for _ in $(seq 1 60); do
    if verify tx --digest "$d" >"$WORK/final-$d.json" 2>/dev/null; then return 0; fi
    sleep 2
  done
  return 1
}

recipient_mist() {
  "$SUI" client "${CLIENT[@]}" gas "$1" --json >"$WORK/gas-r.json"
  python3 -I -c '
import json,sys
t=open(sys.argv[1]).read(); s=min(i for i in (t.find("{"),t.find("[")) if i>=0); d=json.loads(t[s:])
def walk(o):
    if isinstance(o,dict):
        yield o
        for v in o.values(): yield from walk(v)
    elif isinstance(o,list):
        for v in o: yield from walk(v)
print(sum(int(x.get("mistBalance",0)) for x in walk(d) if "gasCoinId" in x))' "$WORK/gas-r.json"
}

pay() { # coin recipient amount extra-args... -> writes $WORK/last.json
  local coin="$1" to="$2" amt="$3"; shift 3
  "$SUI" client "${CLIENT[@]}" pay-sui --input-coins "$coin" --recipients "$to" \
    --amounts "$amt" --gas-budget 50000000 "$@"
}

# --- setup -----------------------------------------------------------------
"$SUI" client "${CLIENT[@]}" addresses --json >"$WORK/addr.json"
mapfile -t ADDRS < <("${TOOL[@]}" addresses "$WORK/addr.json")
SENDER="${ADDRS[0]}"; RECIP="${ADDRS[1]}"
[[ "$SENDER" != "$RECIP" ]] || RECIP=0x000000000000000000000000000000000000000000000000000000000000beef
echo "sender $SENDER -> recipient $RECIP"

# --- API-01: transfers are reported FINAL only after certificate verification --
digests=()
for i in 1 2 3; do
  "$SUI" client "${CLIENT[@]}" gas "$SENDER" --json >"$WORK/gas.json"
  coin="$("${TOOL[@]}" largest-coin "$WORK/gas.json")"
  pay "$coin" "$RECIP" 1000 --json >"$WORK/pay-$i.json" || fail "transfer $i rejected"
  "${TOOL[@]}" tx-succeeded "$WORK/pay-$i.json" >/dev/null || fail "transfer $i failed"
  digests+=("$("${TOOL[@]}" tx-digest "$WORK/pay-$i.json")")
done
for d in "${digests[@]}"; do
  wait_final "$d" || fail "API-01: $d never verified as final"
  grep -q '"success":true' "$WORK/final-$d.json" || fail "API-01: $d final but not successful"
done
pass "API-01: ${#digests[@]} transfers verified FINAL from certified checkpoints"

# --- LEDGER-04: two transactions spending the same coin version -------------
"$SUI" client "${CLIENT[@]}" gas "$SENDER" --json >"$WORK/gas.json"
coin="$("${TOOL[@]}" largest-coin "$WORK/gas.json")"
before="$(recipient_mist "$RECIP")"
pay "$coin" "$RECIP" 1111 --serialize-signed-transaction >"$WORK/txA.b64"
pay "$coin" "$RECIP" 2222 --serialize-signed-transaction >"$WORK/txB.b64"
txA="$(grep -E '^[A-Za-z0-9+/=]{100,}$' "$WORK/txA.b64" | tail -1)"
txB="$(grep -E '^[A-Za-z0-9+/=]{100,}$' "$WORK/txB.b64" | tail -1)"
[[ -n "$txA" && -n "$txB" ]] || fail "LEDGER-04: could not serialize signed transactions"
"$SUI" client "${CLIENT[@]}" execute-combined-signed-tx --signed-tx-bytes "$txA" --json >"$WORK/execA.json" 2>&1 || true
"$SUI" client "${CLIENT[@]}" execute-combined-signed-tx --signed-tx-bytes "$txB" --json >"$WORK/execB.json" 2>&1 || true
# Replay of the first transaction must not move value twice.
"$SUI" client "${CLIENT[@]}" execute-combined-signed-tx --signed-tx-bytes "$txA" --json >"$WORK/execA2.json" 2>&1 || true
sleep 5
after="$(recipient_mist "$RECIP")"
delta=$((after - before))
case "$delta" in
  1111|2222) pass "LEDGER-04: conflicting spends + replay moved value exactly once (delta $delta)";;
  *) fail "LEDGER-04: recipient balance changed by $delta (expected 1111 or 2222)";;
esac

# --- CONS-01 + CONS-05: full chain from genesis, across committee hand-offs ---
need="${SEUARO_MIN_HANDOFFS:-2}"
for _ in $(seq 1 120); do
  if verify sync --min-handoffs "$need" >"$WORK/sync.json" 2>"$WORK/sync.err"; then break; fi
  sleep 3
done
grep -q '"result":"VERIFIED"' "$WORK/sync.json" 2>/dev/null \
  || { cat "$WORK/sync.err" >&2; fail "CONS-01/05: chain did not verify with $need hand-offs"; }
pass "CONS-01/CONS-05: $(cat "$WORK/sync.json")"

# --- Tampering must be rejected ----------------------------------------------
verify self-test >"$WORK/selftest.json" || fail "self-test: tampered data was accepted"
pass "tamper self-test: $(cat "$WORK/selftest.json")"

# --- AUTH-01: a client with another network's genesis rejects this chain -----
mkdir -p "$WORK/foreign"
"$SUI" genesis --working-dir "$WORK/foreign" --committee-size 4 >"$WORK/foreign.log" 2>&1 \
  || fail "could not create foreign genesis"
if "$VERIFY" --genesis "$WORK/foreign/genesis.blob" --checkpoints "$INGEST_DIR" sync >/dev/null 2>"$WORK/foreign.err"; then
  fail "AUTH-01: checkpoints accepted under a foreign genesis"
fi
pass "AUTH-01: foreign genesis rejected ($(head -c 160 "$WORK/foreign.err"))"

echo "All Phase 1 checks passed."
