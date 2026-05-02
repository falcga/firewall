#!/usr/bin/env bash
# Fetch Flowseal text lists used for merge (upstream).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_dirs

for f in "${flowseal_lists[@]}"; do
  out="$CATALOG/upstream/$f"
  echo "Fetching $UPSTREAM_ZAPRET_BASE/$f → $out"
  fetch_remote "$out" "$UPSTREAM_ZAPRET_BASE/$f"
done

echo "Fetching ipset backup list"
fetch_remote "$CATALOG/upstream/ipset-all.backup.txt" \
  "$UPSTREAM_ZAPRET_BASE/ipset-all.txt.backup"
