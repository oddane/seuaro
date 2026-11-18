#!/usr/bin/env bash
# End-to-end test of seuaro_payments on a running devnet: publish the package,
# run escrow flows between three distinct accounts, and confirm each settlement
# is FINAL with seuaro-verify (PAY-01 + API-01).
source "$(dirname "$0")/../scripts/lib.sh"
check_protocol_env
SUI="$(sui_bin)"
VERIFY="$(verify_bin)"
TOOL=(python3 -I "$SEUARO_ROOT/scripts/devnet_tool.py")
CLIENT=(--client.config "$(client_config)")
GENESIS="$CONFIG_DIR/genesis.blob"
WORK="$DEVNET_DIR/payments-work"
SUI_T="0x2::sui::SUI"
CLOCK="0x6"
rm -rf "$WORK" && mkdir -p "$WORK"

pass() { printf '\033[1;32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

as() { "$SUI" client "${CLIENT[@]}" switch --address "$1" >/dev/null; }
coins_of() { "$SUI" client "${CLIENT[@]}" gas "$1" --json >"$WORK/gas.json"; "${TOOL[@]}" coins "$WORK/gas.json"; }
final() {
  local d="$1"
  for _ in $(seq 1 60); do
    "$VERIFY" --genesis "$GENESIS" --checkpoints "$INGEST_DIR" tx --digest "$d" >"$WORK/final.json" 2>/dev/null \
      && grep -q '"success":true' "$WORK/final.json" && return 0
    sleep 2
  done
  return 1
}
run() { # name, then sui client args; output saved to $WORK/<name>.json
  local name="$1"; shift
  "$SUI" client "${CLIENT[@]}" "$@" --gas-budget 500000000 --json >"$WORK/$name.json" 2>"$WORK/$name.err" \
    || { cat "$WORK/$name.err" "$WORK/$name.json" >&2; fail "$name: command failed"; }
  "${TOOL[@]}" tx-succeeded "$WORK/$name.json" >/dev/null || fail "$name: transaction failed"
  local d; d="$("${TOOL[@]}" tx-digest "$WORK/$name.json")"
  final "$d" || fail "$name: $d not verified FINAL"
}

"$SUI" client "${CLIENT[@]}" addresses --json >"$WORK/addr.json"
mapfile -t A < <("${TOOL[@]}" addresses "$WORK/addr.json")
(( ${#A[@]} >= 3 )) || fail "need 3 funded accounts, have ${#A[@]}"
BUYER="${A[0]}"; MERCHANT="${A[1]}"; ARBITER="${A[2]}"
echo "buyer $BUYER  merchant $MERCHANT  arbiter $ARBITER"

# --- publish ------------------------------------------------------------------
as "$BUYER"
run publish publish "$SEUARO_ROOT/packages/seuaro_payments"
PKG="$("${TOOL[@]}" package-id "$WORK/publish.json")"
pass "published seuaro_payments at $PKG (FINAL)"

new_escrow() { # name -> prints escrow id; buyer pays with their second-largest coin
  local name="$1"; as "$BUYER"
  mapfile -t C < <(coins_of "$BUYER")
  (( ${#C[@]} >= 2 )) || fail "buyer needs 2 coins"
  run "$name" call --package "$PKG" --module escrow --function create --type-args "$SUI_T" \
    --args "${C[1]}" "$MERCHANT" "$ARBITER" 600000 "$CLOCK" --gas "${C[0]}"
  "${TOOL[@]}" created "$WORK/$name.json" "::escrow::Escrow<"
}

# --- flow 1: merchant refund returns the full deposit ------------------------
E1="$(new_escrow create1)"
AMT1="$("${TOOL[@]}" event-field "$WORK/create1.json" "::escrow::EscrowCreated" amount)"
as "$MERCHANT"
run refund call --package "$PKG" --module escrow --function refund --type-args "$SUI_T" --args "$E1"
[[ "$("${TOOL[@]}" event-field "$WORK/refund.json" "::escrow::Settled" to_buyer)" == "$AMT1" ]] \
  || fail "refund did not return the full deposit"
[[ "$("${TOOL[@]}" event-field "$WORK/refund.json" "::escrow::Settled" to_merchant)" == "0" ]] \
  || fail "refund paid the merchant"
pass "PAY-01 refund: buyer got exactly $AMT1, merchant 0 (FINAL)"

# --- flow 2: dispute, arbiter splits 70/30 ----------------------------------
E2="$(new_escrow create2)"
AMT2="$("${TOOL[@]}" event-field "$WORK/create2.json" "::escrow::EscrowCreated" amount)"
as "$BUYER"
run dispute call --package "$PKG" --module escrow --function dispute --type-args "$SUI_T" --args "$E2" "$CLOCK"
to_m=$(( AMT2 * 7 / 10 ))
as "$ARBITER"
run resolve call --package "$PKG" --module escrow --function resolve --type-args "$SUI_T" --args "$E2" "$to_m"
got_m="$("${TOOL[@]}" event-field "$WORK/resolve.json" "::escrow::Settled" to_merchant)"
got_b="$("${TOOL[@]}" event-field "$WORK/resolve.json" "::escrow::Settled" to_buyer)"
(( got_m == to_m && got_m + got_b == AMT2 )) || fail "split $got_m + $got_b != $AMT2"
pass "PAY-01 dispute: merchant $got_m + buyer $got_b = deposit $AMT2 (FINAL)"

# --- flow 3: a stranger cannot release someone else's escrow ----------------
E3="$(new_escrow create3)"
as "$ARBITER"
if "$SUI" client "${CLIENT[@]}" call --package "$PKG" --module escrow --function release \
     --type-args "$SUI_T" --args "$E3" --gas-budget 500000000 --json >"$WORK/steal.json" 2>&1 \
   && "${TOOL[@]}" tx-succeeded "$WORK/steal.json" >/dev/null 2>&1; then
  fail "PAY-01: non-buyer released the escrow"
fi
pass "PAY-01 authorization: non-buyer release rejected"

as "$BUYER"
echo "All payment devnet checks passed."
