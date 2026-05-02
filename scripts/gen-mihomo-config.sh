#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

MODE="${FIREWALL_VPN_ROUTE:-split}"

subf="$SECRETS/subscription.url"
if [[ ! -f "$subf" ]]; then
  cp "$ROOT/contrib/subscription.url.example" "$subf"
  echo "Шаблон $subf создан — вставьте URL подписки." >&2
  exit 1
fi

SUB_URL="$(tr -d '\r\n' <"$subf")"
grep -Eq '^https?://' <<<"$SUB_URL" || {
  echo "subscription.url — только http(s)" >&2
  exit 1
}

[[ -f "$GEO_DIR/geoip.dat" && -f "$GEO_DIR/geosite.dat" ]] || {
  echo "Нужны $GEO_DIR/{geoip,geosite}.dat → scripts/sync-geodat.sh" >&2
  exit 2
}

secfile="$SECRETS/mihomo-secret.txt"
if [[ ! -f "$secfile" ]]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 >"$secfile"
  chmod 600 "$secfile"
fi
SECRET="$(tr -d '\r\n' <"$secfile")"

subs_safe() {
  python3 -c 'import sys; print(sys.argv[1].replace(chr(39), chr(39)*2))' "$1"
}

SUB_SQ="$(subs_safe "$SUB_URL")"
SEC_SQ="$(subs_safe "$SECRET")"

rules_user="$STATE/generated/mihomo-user-rules.yaml"
[[ -f "$rules_user" ]] || "$ROOT/scripts/build-lists.sh"

outdir="$STATE/mihomo"
mkdir -p "$outdir"
tmp="$outdir/.config.$$"

python3 -c '
import pathlib, sys
tpl_path, geo, sec_sq, sub_sq = sys.argv[1:5]
text = pathlib.Path(tpl_path).read_text(encoding="utf-8")
for needle, val in (
    ("__GEO_PATH__", geo),
    ("__SECRET__", sec_sq),
    ("__SUBSCRIPTION_URL__", sub_sq),
):
    text = text.replace(needle, val)
print(text, end="")
' "${ROOT}/deploy/mihomo/config.head.yaml.tpl" "$GEO_DIR" "$SEC_SQ" "$SUB_SQ" >"$tmp"

{
  printf 'rules:\n'
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    printf '  %s\n' "$r"
  done <"$rules_user"

  case "$MODE" in
  tunnel)
    printf '  - MATCH,PROXY\n'
    ;;
  *)
    printf '  - GEOSITE,ru-blocked,PROXY\n'
    printf '  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve\n'
    printf '  - MATCH,DIRECT\n'
    ;;
  esac
} >>"$tmp"

mv -f "$tmp" "$outdir/config.yaml"
chmod 640 "$outdir/config.yaml"
echo "Wrote $outdir/config.yaml (mode=$MODE)"
