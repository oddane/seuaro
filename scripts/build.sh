#!/usr/bin/env bash
# Build the pinned upstream binaries (unmodified, --locked) and the Seuaro
# finality verifier. The verifier is built inside the upstream workspace so it
# uses exactly the same dependency versions; the upstream tree is restored to
# pristine afterwards.
source "$(dirname "$0")/lib.sh"
require git cargo perl

"$SEUARO_ROOT/scripts/fetch-upstream.sh"
mkdir -p "$BIN_DIR"

profile="release"

# RocksDB 8.10 (pinned by upstream) misses `#include <cstdint>`, which GCC 13+
# no longer pulls in transitively. Force-include it for C++ dependencies.
# Build flag only: no source change (FORK-DELTA D6).
export CXXFLAGS="${CXXFLAGS:-} -include cstdint"
target_dir="${CARGO_TARGET_DIR:-$UPSTREAM_DIR/target}/$profile"

log "building upstream sui + sui-node ($profile, --locked)"
( cd "$UPSTREAM_DIR" && cargo build --locked --profile "$profile" -p sui -p sui-node )

restore_upstream() {
  git -C "$UPSTREAM_DIR" checkout -q -- Cargo.toml Cargo.lock
  rm -rf "$UPSTREAM_DIR/crates/seuaro-verify"
}
trap restore_upstream EXIT

log "overlaying tools/seuaro-verify into the upstream workspace"
rm -rf "$UPSTREAM_DIR/crates/seuaro-verify"
cp -R "$SEUARO_ROOT/tools/seuaro-verify" "$UPSTREAM_DIR/crates/seuaro-verify"
rm -rf "$UPSTREAM_DIR/crates/seuaro-verify/target"
perl -0pi -e 's/^members = \[/members = [\n    "crates\/seuaro-verify",/m' "$UPSTREAM_DIR/Cargo.toml"
grep -q '"crates/seuaro-verify"' "$UPSTREAM_DIR/Cargo.toml" || die "failed to add seuaro-verify to workspace"

log "building seuaro-verify"
( cd "$UPSTREAM_DIR" && cargo build --profile "$profile" -p seuaro-verify )

# The verifier must not change any upstream dependency version: Cargo.lock may
# only gain the seuaro-verify package entry, never lose or change lines.
deleted="$(git -C "$UPSTREAM_DIR" diff --numstat -- Cargo.lock | awk '{s+=$2} END {print s+0}')"
[[ "$deleted" == "0" ]] \
  || { git -C "$UPSTREAM_DIR" diff -- Cargo.lock | head -50 >&2; die "seuaro-verify changed upstream dependency versions"; }

for b in sui sui-node seuaro-verify; do
  install -m 0755 "$target_dir/$b" "$BIN_DIR/$b"
done

"$BIN_DIR/sui" --version
log "binaries installed in $BIN_DIR"
