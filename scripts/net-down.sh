#!/usr/bin/env bash
# Stop the container testnet. Pass --wipe to also delete all state and keys.
source "$(dirname "$0")/lib.sh"
require docker
COMPOSE=(docker compose -f "$SEUARO_ROOT/docker/compose.yaml")
if [[ "${1:-}" == "--wipe" ]]; then
  "${COMPOSE[@]}" --profile tools down -v --remove-orphans
  log "network stopped and all volumes (including keys) deleted"
else
  "${COMPOSE[@]}" --profile tools down --remove-orphans
  log "network stopped; state kept (scripts/net-up.sh --resume to restart)"
fi
