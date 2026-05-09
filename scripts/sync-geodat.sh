#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_dirs

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

REL="$tmpdir/rel.json"
curl -fsSL "$RULES_DAT_API" -o "$REL"

tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <"$REL")"
[ -n "$tag" ]

base='https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/download'
dl() {
  local name="$1"
  curl -fL --retry 3 "${base}/${tag}/${name}" -o "$GEO_DIR/$name.part"
  mv -f "$GEO_DIR/$name.part" "$GEO_DIR/$name"
}

dl geoip.dat
dl geosite.dat

echo "$tag" >"$GEO_TAG_FILE"
echo "geodata установлены ($tag) → $GEO_DIR"
