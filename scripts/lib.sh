#!/usr/bin/env bash
# Shared defaults for Raspberry Pi gateway (adjust paths once here).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/catalog"
STATE="${STATE:-$ROOT/state}"
SECRETS="${SECRETS:-$ROOT/secrets}"

UPSTREAM_ZAPRET_BASE="https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists"
RULES_DAT_API="https://api.github.com/repos/runetfreedom/russia-v2ray-rules-dat/releases/latest"

GEO_DIR="${GEO_DIR:-$STATE/geodata}"
GEO_TAG_FILE="$GEO_DIR/last-tag.txt"

flowseal_lists=(
  list-general.txt
  list-google.txt
  list-exclude.txt
  ipset-exclude.txt
  ipset-all.txt
)

fetch_remote() {
  local path="$1" url="$2"
  mkdir -p "$(dirname "$path")"
  curl -fsSL "$url" -o "$path.tmp" && mv -f "$path.tmp" "$path"
}

ensure_dirs() {
  mkdir -p "$STATE/generated" "$STATE/providers" "$GEO_DIR" \
    "$ROOT/catalog/upstream" "$SECRETS" 2>/dev/null || true
}
