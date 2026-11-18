#!/usr/bin/env bash
# Fetch the pinned upstream Sui source at the exact commit in UPSTREAM.lock and
# verify it. Idempotent: an existing checkout is verified, not re-downloaded.
source "$(dirname "$0")/lib.sh"
require git

if [[ -d "$UPSTREAM_DIR/.git" ]]; then
  log "verifying existing checkout in $UPSTREAM_DIR"
else
  log "fetching $UPSTREAM_TAG ($UPSTREAM_COMMIT)"
  mkdir -p "$UPSTREAM_DIR"
  git -C "$UPSTREAM_DIR" init -q
  git -C "$UPSTREAM_DIR" remote add origin "$UPSTREAM_REPO"
  git -C "$UPSTREAM_DIR" fetch -q --depth 1 origin "$UPSTREAM_COMMIT"
  git -C "$UPSTREAM_DIR" -c advice.detachedHead=false checkout -q FETCH_HEAD
fi

head="$(git -C "$UPSTREAM_DIR" rev-parse HEAD)"
[[ "$head" == "$UPSTREAM_COMMIT" ]] \
  || die "upstream HEAD $head does not match pinned $UPSTREAM_COMMIT"

# Confirm the tag still points at the pinned commit (detects a moved tag).
remote_tag="$(git ls-remote "$UPSTREAM_REPO" "refs/tags/$UPSTREAM_TAG^{}" | awk '{print $1}')"
if [[ -z "$remote_tag" ]]; then
  remote_tag="$(git ls-remote "$UPSTREAM_REPO" "refs/tags/$UPSTREAM_TAG" | awk '{print $1}')"
fi
[[ "$remote_tag" == "$UPSTREAM_COMMIT" ]] \
  || die "tag $UPSTREAM_TAG now points to '$remote_tag', not the pinned commit"

if [[ -n "$(git -C "$UPSTREAM_DIR" status --porcelain --untracked-files=no)" ]]; then
  die "upstream checkout has local modifications; Seuaro allows zero local changes"
fi

toolchain="$(sed -n 's/^channel *= *"\(.*\)"/\1/p' "$UPSTREAM_DIR/rust-toolchain.toml")"
[[ "$toolchain" == "$UPSTREAM_RUST_TOOLCHAIN" ]] \
  || die "upstream toolchain $toolchain != pinned $UPSTREAM_RUST_TOOLCHAIN"

max_pv="$(sed -n 's/^const MAX_PROTOCOL_VERSION: u64 = \([0-9]*\);/\1/p' \
  "$UPSTREAM_DIR/crates/sui-protocol-config/src/lib.rs")"
[[ "$max_pv" == "$UPSTREAM_MAX_PROTOCOL_VERSION" ]] \
  || die "upstream MAX_PROTOCOL_VERSION $max_pv != pinned $UPSTREAM_MAX_PROTOCOL_VERSION"

log "upstream OK: $UPSTREAM_TAG @ $UPSTREAM_COMMIT, toolchain $toolchain, protocol <= $max_pv"
