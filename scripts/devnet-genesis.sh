#!/usr/bin/env bash
# Create a fresh Seuaro devnet genesis: its own chain identity, a 4-validator
# committee and short epochs so committee hand-offs are exercised quickly.
# WARNING: deletes any existing devnet state (including its keys).
source "$(dirname "$0")/lib.sh"
check_protocol_env
SUI="$(sui_bin)"

validators="${SEUARO_VALIDATORS:-4}"
epoch_ms="${SEUARO_EPOCH_MS:-30000}"

if [[ -f "$DEVNET_DIR/pid" ]] && kill -0 "$(cat "$DEVNET_DIR/pid")" 2>/dev/null; then
  die "devnet is running; stop it with scripts/devnet-down.sh first"
fi

rm -rf "$DEVNET_DIR"
mkdir -p "$CONFIG_DIR" "$INGEST_DIR" "$LOG_DIR"
chmod 700 "$DEVNET_DIR"

log "creating genesis: $validators validators, epoch ${epoch_ms} ms"
"$SUI" genesis \
  --working-dir "$CONFIG_DIR" \
  --committee-size "$validators" \
  --epoch-duration-ms "$epoch_ms" \
  --with-faucet >"$LOG_DIR/genesis.log" 2>&1 \
  || { tail -50 "$LOG_DIR/genesis.log" >&2; die "genesis failed"; }

[[ -f "$CONFIG_DIR/genesis.blob" ]] || die "genesis.blob not produced"
python3 -I "$SEUARO_ROOT/scripts/devnet_tool.py" check-config "$CONFIG_DIR"
log "genesis ready in $CONFIG_DIR (keys inside; never commit this directory)"
