#!/usr/bin/env bash
# Start the 4-validator devnet plus one full node that writes every executed
# checkpoint to devnet/checkpoints for the finality verifier.
source "$(dirname "$0")/lib.sh"
check_protocol_env
SUI="$(sui_bin)"

[[ -f "$CONFIG_DIR/genesis.blob" ]] || die "no genesis; run scripts/devnet-genesis.sh"
if [[ -f "$DEVNET_DIR/pid" ]] && kill -0 "$(cat "$DEVNET_DIR/pid")" 2>/dev/null; then
  die "devnet already running (pid $(cat "$DEVNET_DIR/pid"))"
fi
python3 -I "$SEUARO_ROOT/scripts/devnet_tool.py" check-config "$CONFIG_DIR"

log "starting devnet (chain feature set: $SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE)"
nohup "$SUI" start \
  --network.config "$CONFIG_DIR" \
  --data-ingestion-dir "$INGEST_DIR" \
  --with-faucet \
  >"$LOG_DIR/devnet.log" 2>&1 &
echo $! >"$DEVNET_DIR/pid"

timeout_s="${SEUARO_START_TIMEOUT:-240}"
for ((i = 0; i < timeout_s; i += 2)); do
  if ! kill -0 "$(cat "$DEVNET_DIR/pid")" 2>/dev/null; then
    tail -80 "$LOG_DIR/devnet.log" >&2
    die "devnet process exited during startup"
  fi
  if "$SUI" client --client.config "$(client_config)" chain-identifier >"$DEVNET_DIR/chain-id" 2>/dev/null; then
    log "devnet up, chain id $(tr -d '[:space:]' <"$DEVNET_DIR/chain-id"), pid $(cat "$DEVNET_DIR/pid")"
    exit 0
  fi
  sleep 2
done
tail -80 "$LOG_DIR/devnet.log" >&2
die "devnet RPC not ready after ${timeout_s}s"
