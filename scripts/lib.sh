#!/usr/bin/env bash
# Shared helpers for Seuaro scripts. Source this file; do not execute it.
set -euo pipefail

SEUARO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export SEUARO_ROOT

# shellcheck disable=SC1091
source "$SEUARO_ROOT/UPSTREAM.lock"

UPSTREAM_DIR="${SEUARO_UPSTREAM_DIR:-$SEUARO_ROOT/upstream/sui}"
BIN_DIR="${SEUARO_BIN_DIR:-$SEUARO_ROOT/bin}"
DEVNET_DIR="${SEUARO_DEVNET_DIR:-$SEUARO_ROOT/devnet}"
CONFIG_DIR="$DEVNET_DIR/config"
INGEST_DIR="$DEVNET_DIR/checkpoints"
LOG_DIR="$DEVNET_DIR/logs"
export UPSTREAM_DIR BIN_DIR DEVNET_DIR CONFIG_DIR INGEST_DIR LOG_DIR

# ADR-0008: every Seuaro process runs Sui mainnet's protocol feature set.
# This must be identical on every node; check_protocol_env enforces it.
export SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE="$SEUARO_PROTOCOL_CHAIN"

log()  { printf '\033[1;34m[seuaro]\033[0m %s\n' "$*" >&2; }
warn() { printf '\033[1;33m[seuaro] WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[seuaro] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "missing required command: $c"
  done
}

# The Seuaro CLI (upstream `sui` binary with patches, installed as `seuaro`).
sui_bin() {
  [[ -x "$BIN_DIR/seuaro" ]] || die "seuaro binary not found in $BIN_DIR; run scripts/build.sh"
  printf '%s' "$BIN_DIR/seuaro"
}

verify_bin() {
  [[ -x "$BIN_DIR/seuaro-verify" ]] || die "seuaro-verify not found in $BIN_DIR; run scripts/build.sh"
  printf '%s' "$BIN_DIR/seuaro-verify"
}

# Refuse to run with protocol-config overrides other than the chain override.
# A per-node override is a consensus split waiting to happen (ADR-0008, risk R2).
check_protocol_env() {
  [[ "${SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE:-}" == "$SEUARO_PROTOCOL_CHAIN" ]] \
    || die "SUI_PROTOCOL_CONFIG_CHAIN_OVERRIDE must be '$SEUARO_PROTOCOL_CHAIN'"
  if env | grep -q '^SUI_PROTOCOL_CONFIG_OVERRIDE'; then
    die "SUI_PROTOCOL_CONFIG_OVERRIDE* variables are forbidden on Seuaro nodes"
  fi
}

client_config() { printf '%s' "$CONFIG_DIR/client.yaml"; }
