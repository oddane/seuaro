#!/usr/bin/env bash
# Stop the devnet. State and keys in devnet/ are kept for inspection.
source "$(dirname "$0")/lib.sh"

pidfile="$DEVNET_DIR/pid"
[[ -f "$pidfile" ]] || { log "devnet not running"; exit 0; }
pid="$(cat "$pidfile")"
if kill -0 "$pid" 2>/dev/null; then
  log "stopping devnet (pid $pid)"
  kill "$pid"
  for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 1; done
  kill -0 "$pid" 2>/dev/null && { warn "forcing stop"; kill -9 "$pid"; }
fi
rm -f "$pidfile"
log "devnet stopped"
