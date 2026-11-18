#!/usr/bin/env bash
# Build the node image, run the multi-party genesis ceremony, and start the
# container testnet (4 validators, full node, faucet, monitoring, explorer).
#
#   scripts/net-up.sh            # fresh network (wipes previous volumes)
#   scripts/net-up.sh --resume   # restart an existing network, keep state
source "$(dirname "$0")/lib.sh"
require docker
COMPOSE=(docker compose -f "$SEUARO_ROOT/docker/compose.yaml")
VALIDATORS=(v1 v2 v3 v4)

for b in sui sui-node sui-faucet seuaro-verify; do
  [[ -x "$BIN_DIR/$b" ]] || die "missing $BIN_DIR/$b; run scripts/build.sh"
done

log "building image seuaro/node:local"
docker build -q -f "$SEUARO_ROOT/docker/Dockerfile" -t seuaro/node:local "$SEUARO_ROOT" >/dev/null

if [[ "${1:-}" != "--resume" ]]; then
  log "removing any previous network state"
  "${COMPOSE[@]}" --profile tools down -v --remove-orphans >/dev/null 2>&1 || true

  log "genesis ceremony: init"
  "${COMPOSE[@]}" run --rm -T ceremony ceremony-init
  for v in "${VALIDATORS[@]}"; do
    log "genesis ceremony: $v generates keys and joins"
    "${COMPOSE[@]}" run --rm -T --no-deps "$v" validator-join "$v"
  done
  "${COMPOSE[@]}" run --rm -T ceremony ceremony-distribute
  "${COMPOSE[@]}" run --rm -T ceremony ceremony-build
  for v in "${VALIDATORS[@]}"; do
    log "genesis ceremony: $v verifies and signs"
    "${COMPOSE[@]}" run --rm -T --no-deps "$v" validator-sign "$v"
  done
  "${COMPOSE[@]}" run --rm -T ceremony ceremony-finalize
fi

log "starting network"
"${COMPOSE[@]}" up -d "${VALIDATORS[@]}" fullnode faucet prometheus grafana explorer

log "waiting for the full node RPC"
for _ in $(seq 1 150); do
  if "${COMPOSE[@]}" run --rm -T --no-deps client exec \
       sui client --client.config /users/client.yaml chain-identifier >/tmp/seuaro-chain-id 2>/dev/null; then
    log "network up, chain id $(tr -d '[:space:]' </tmp/seuaro-chain-id)"
    cat <<EOF >&2
  RPC        http://127.0.0.1:9000
  Faucet     http://127.0.0.1:5003
  Explorer   http://127.0.0.1:8080
  Grafana    http://127.0.0.1:3000
  Prometheus http://127.0.0.1:9090
EOF
    exit 0
  fi
  sleep 2
done
"${COMPOSE[@]}" logs --tail 60 >&2
die "full node RPC not ready"
