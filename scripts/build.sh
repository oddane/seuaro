#!/usr/bin/env bash
# Build Seuaro from the pinned upstream source:
#   1. verify the pinned upstream commit (fetch-upstream.sh resets it to pristine)
#   2. apply the numbered patches in patches/ (FORK-DELTA.md lists each one)
#   3. regenerate the compiled system packages with upstream's own tool, and
#      fail if anything other than the patched package changed
#   4. build the binaries with --locked, plus seuaro-verify in the same workspace
#   5. install them under Seuaro names with LICENSE, NOTICE and a generated
#      THIRD-PARTY-LICENSES.md
source "$(dirname "$0")/lib.sh"
require git cargo perl python3

"$SEUARO_ROOT/scripts/fetch-upstream.sh"
mkdir -p "$BIN_DIR"

profile="release"

# RocksDB 8.10 (pinned by upstream) misses `#include <cstdint>`, which GCC 13+
# no longer pulls in transitively. Force-include it for C++ dependencies.
# Build flag only (FORK-DELTA D6).
export CXXFLAGS="${CXXFLAGS:-} -include cstdint"
target_dir="${CARGO_TARGET_DIR:-$UPSTREAM_DIR/target}/$profile"

# --- 2. patches -------------------------------------------------------------
shopt -s nullglob
patches=("$SEUARO_ROOT"/patches/*.patch)
for p in "${patches[@]}"; do
  log "applying $(basename "$p")"
  git -C "$UPSTREAM_DIR" apply --check "$p" || die "patch does not apply: $(basename "$p")"
  git -C "$UPSTREAM_DIR" apply "$p"
done

# --- 3. system packages ----------------------------------------------------------
log "regenerating compiled system packages (upstream build-system-packages tool)"
( cd "$UPSTREAM_DIR" && UPDATE=1 cargo test --locked --profile "$profile" \
    -p sui-framework --test build-system-packages )

# Only the patched framework package (and its generated docs/API listing) may
# change. Any other difference means the regeneration was not deterministic.
unexpected="$(git -C "$UPSTREAM_DIR" status --porcelain --untracked-files=no \
  | awk '{print $2}' \
  | grep -vE '^crates/sui-framework/packages/sui-framework/sources/sui\.move$' \
  | grep -vE '^crates/sui-framework/packages_compiled/sui-framework$' \
  | grep -vE '^crates/sui-framework/docs/' \
  | grep -vE '^crates/sui-framework/published_api\.txt$' \
  | grep -vE '^crates/sui/src/main\.rs$|^crates/sui-node/src/main\.rs$|^crates/sui-faucet/src/faucet_config\.rs$' || true)"
[[ -z "$unexpected" ]] || { echo "$unexpected" >&2; die "unexpected upstream files changed after patching"; }
git -C "$UPSTREAM_DIR" diff --quiet -- crates/sui-framework/packages_compiled/sui-framework \
  && die "patch 0001 did not change the compiled framework; regeneration failed"

# --- 4. build ------------------------------------------------------------------------
log "building node, CLI and faucet ($profile, --locked)"
( cd "$UPSTREAM_DIR" && cargo build --locked --profile "$profile" -p sui -p sui-node -p sui-faucet )

restore_overlay() {
  git -C "$UPSTREAM_DIR" checkout -q -- Cargo.toml Cargo.lock
  rm -rf "$UPSTREAM_DIR/crates/seuaro-verify"
}
trap restore_overlay EXIT

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

log "generating THIRD-PARTY-LICENSES.md"
( cd "$UPSTREAM_DIR" && cargo metadata --format-version 1 --locked ) \
  | python3 -I "$SEUARO_ROOT/scripts/third-party-licenses.py" sui sui-node sui-faucet seuaro-verify \
  > "$BIN_DIR/THIRD-PARTY-LICENSES.md"

# --- 5. install under Seuaro names --------------------------------------------------
install -m 0755 "$target_dir/sui"           "$BIN_DIR/seuaro"
install -m 0755 "$target_dir/sui-node"      "$BIN_DIR/seuaro-node"
install -m 0755 "$target_dir/sui-faucet"    "$BIN_DIR/seuaro-faucet"
install -m 0755 "$target_dir/seuaro-verify" "$BIN_DIR/seuaro-verify"
install -m 0644 "$SEUARO_ROOT/LICENSE" "$SEUARO_ROOT/NOTICE" "$BIN_DIR/"

"$BIN_DIR/seuaro" --version
log "binaries installed in $BIN_DIR (patched: ${#patches[@]} patch(es); see FORK-DELTA.md)"
