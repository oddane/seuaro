#!/usr/bin/env bash
# One command to run a Seuaro testnet on this machine.
#
#   scripts/quickstart.sh                    # build from source, then start (30–90 min first time)
#   scripts/quickstart.sh --image IMAGE      # start from a published image (minutes, no compiler)
#
# Starts 4 validators (each with its own keys from the genesis ceremony), a
# public full node, a faucet, Prometheus, Grafana and the explorer, all bound
# to localhost. Testnet only: coins have no value (DISCLAIMER.md).
source "$(dirname "$0")/lib.sh"

image=""
if [[ "${1:-}" == "--image" ]]; then image="${2:?--image needs a value}"; fi

# --- prerequisites -------------------------------------------------------------
docker compose version >/dev/null 2>&1 || die "Docker with Compose v2 is required: https://docs.docker.com/get-docker/"
docker info >/dev/null 2>&1 || die "Docker is installed but not running (start Docker Desktop or the docker service)"
command -v python3 >/dev/null || die "python3 is required"

mem_gb=$(( $(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0) / 1024 / 1024 ))
free_gb=$(( $(df -Pk "$SEUARO_ROOT" | awk 'NR==2 {print $4}') / 1024 / 1024 ))
need_disk=20; [[ -z "$image" ]] && need_disk=60
(( mem_gb == 0 || mem_gb >= 8 )) || die "at least 8 GB RAM needed (found ${mem_gb} GB)"
(( mem_gb == 0 || mem_gb >= 16 )) || warn "16 GB RAM recommended (found ${mem_gb} GB)"
(( free_gb >= need_disk )) || die "at least ${need_disk} GB free disk needed (found ${free_gb} GB)"

# --- build or pull ------------------------------------------------------------------
if [[ -z "$image" ]]; then
  require git cargo clang cmake pkg-config
  log "building from source (first build takes 30–90 minutes)"
  "$SEUARO_ROOT/scripts/build.sh"
  "$SEUARO_ROOT/scripts/net-up.sh"
else
  "$SEUARO_ROOT/scripts/net-up.sh" --image "$image"
fi

cat <<'EOF'

Seuaro testnet is running.

  Explorer     http://127.0.0.1:8080
  RPC          http://127.0.0.1:9000
  Faucet       http://127.0.0.1:5003   (POST /v2/gas {"FixedAmountRequest":{"recipient":"0x…"}})
  Grafana      http://127.0.0.1:3000
  Prometheus   http://127.0.0.1:9090

Use the CLI with a funded test account:
  docker compose -f docker/compose.yaml run --rm client exec \
    seuaro client --client.config /users/buyer/client.yaml gas

Run the checks:     tests/phase2-faults.sh
Stop:               scripts/net-down.sh          (add --wipe to delete all state and keys)
EOF
