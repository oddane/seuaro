#!/usr/bin/env bash
# Fault-injection tests against the container testnet (scripts/net-up.sh).
#
#  F1  one validator crashed (f = 1 of 4): chain keeps finalizing      LIVE-01
#      and the restarted validator catches up                          STORE-01
#  F2  two validators crashed (> f): chain halts instead of forking,   CONS-01/03
#      then resumes with all earlier certified checkpoints intact      CONS-04
#  F3  one validator cut off from the network, then reconnected        NET / LIVE-01
#  F4  repeated validator restarts across epoch changes                GOV-02
#  End full chain re-verified from genesis + tamper self-test          CONS-05, API-01
source "$(dirname "$0")/../scripts/lib.sh"
require docker
COMPOSE=(docker compose -f "$SEUARO_ROOT/docker/compose.yaml")

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; "${COMPOSE[@]}" ps >&2; exit 1; }

# Run a command in the client container (test keys, genesis, checkpoint files).
c() { "${COMPOSE[@]}" run --rm -T --no-deps client exec "$@"; }

verify() { c seuaro-verify --genesis /ceremony/genesis.blob --checkpoints /opt/sui/checkpoints "$@"; }

highest() { verify sync 2>/dev/null | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["highest_checkpoint"])'; }

# Send 1000 MIST buyer -> merchant; prints the digest. Fails if not executed in time.
transfer() {
  local t="${1:-60}"
  c bash -c '
    set -euo pipefail
    CFG=/users/buyer/client.yaml
    T="python3 -I /scripts/devnet_tool.py"
    M=$(python3 -I -c "import json; print(json.load(open(\"/users/addresses.json\"))[\"merchant\"])")
    sui client --client.config $CFG gas --json > /tmp/gas.json
    COIN=$($T largest-coin /tmp/gas.json)
    timeout '"$t"' sui client --client.config $CFG pay-sui --input-coins $COIN \
      --recipients $M --amounts 1000 --gas-budget 50000000 --json > /tmp/pay.json
    $T tx-succeeded /tmp/pay.json >/dev/null
    $T tx-digest /tmp/pay.json'
}

final() { # digest -> verified FINAL within ~60 s
  for _ in $(seq 1 30); do
    verify tx --digest "$1" >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

metric() { # node metric -> integer value (0 if unavailable)
  c bash -c "curl -sf http://$1:9184/metrics | awk '/^$2[ {]/ {print int(\$NF); exit}'" 2>/dev/null || echo 0
}

caught_up() { # node -> waits until node is within 5 checkpoints of the full node
  local node="$1"
  for _ in $(seq 1 60); do
    local fn n; fn="$(metric fullnode last_executed_checkpoint)"; n="$(metric "$node" last_executed_checkpoint)"
    if (( fn > 0 && n > 0 && fn - n <= 5 )); then return 0; fi
    sleep 3
  done
  return 1
}

# --- baseline -------------------------------------------------------------------
d="$(transfer)" || fail "baseline transfer"
final "$d" || fail "baseline transfer not FINAL"
pass "baseline: transfer $d FINAL"

# --- F1: one validator down -----------------------------------------------------
"${COMPOSE[@]}" stop -t 5 v4 >/dev/null
d="$(transfer)" || fail "F1: transfer failed with 3/4 validators"
final "$d" || fail "F1: not FINAL with 3/4 validators"
pass "F1: chain live with v4 down (transfer $d FINAL)"
"${COMPOSE[@]}" start v4 >/dev/null
caught_up v4 || fail "F1: v4 did not catch up after restart"
pass "F1: v4 restarted and caught up"

# --- F2: two validators down (beyond the fault threshold) -------------------------
before="$(highest)"
"${COMPOSE[@]}" stop -t 5 v3 v4 >/dev/null
sleep 10
h1="$(highest)"
if transfer 25 >/dev/null 2>&1; then fail "F2: a transaction executed with only 2/4 validators"; fi
sleep 10
h2="$(highest)"
(( h2 == h1 )) || fail "F2: checkpoints advanced ($h1 -> $h2) without a quorum"
pass "F2: with 2/4 validators the chain halted at checkpoint $h2 (no progress, no fork)"
"${COMPOSE[@]}" start v3 v4 >/dev/null
d=""
for _ in $(seq 1 12); do d="$(transfer 30 2>/dev/null)" && break; sleep 5; done
[[ -n "$d" ]] || fail "F2: chain did not resume"
final "$d" || fail "F2: transfer after recovery not FINAL"
after="$(highest)"
(( after > h2 && h2 >= before )) || fail "F2: unexpected checkpoint sequence $before/$h2/$after"
pass "F2: chain resumed (checkpoint $h2 -> $after); history before the halt re-verifies"

# --- F3: network partition of one validator ---------------------------------------
v1="$("${COMPOSE[@]}" ps -q v1)"
docker network disconnect seuaro "$v1"
d="$(transfer)" || { docker network connect seuaro "$v1"; fail "F3: transfer failed with v1 partitioned"; }
final "$d" || { docker network connect seuaro "$v1"; fail "F3: not FINAL with v1 partitioned"; }
docker network connect --alias v1 seuaro "$v1"
caught_up v1 || fail "F3: v1 did not catch up after the partition healed"
pass "F3: chain live during v1 partition; v1 caught up after reconnect"

# --- F4: restarts across epoch changes ----------------------------------------------
epoch0="$(metric fullnode current_epoch)"
for _ in 1 2 3 4 5 6; do
  "${COMPOSE[@]}" restart -t 3 v2 >/dev/null
  sleep 10
done
epoch1="$(metric fullnode current_epoch)"
(( epoch1 >= epoch0 + 2 )) || fail "F4: epochs did not advance during restarts ($epoch0 -> $epoch1)"
d="$(transfer)" || fail "F4: transfer after restarts"
final "$d" || fail "F4: not FINAL after restarts"
caught_up v2 || fail "F4: v2 did not catch up"
pass "F4: 6 restarts of v2 across epochs $epoch0 -> $epoch1; chain live, v2 in sync"

# --- end: full chain from genesis -----------------------------------------------
verify sync --min-handoffs 2 || fail "end: chain does not verify from genesis"
verify self-test >/dev/null || fail "end: tamper self-test"
pass "end: full chain verified from genesis; tampering rejected"
echo "All fault tests passed."
