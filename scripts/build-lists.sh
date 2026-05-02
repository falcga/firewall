#!/usr/bin/env bash
# Собирает hostlist/IP для zapret и фрагмент правил для mihomo из catalog/user + upstream Flowseal.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_dirs

zhost="$STATE/generated/zapret-hostlist.txt"
zexclude="$STATE/generated/zapret-hostlist-exclude.txt"
zipset="$STATE/generated/zapret-ip.txt"
zipset_ex="$STATE/generated/zapret-ip-exclude.txt"
sanitize_domains() {
  grep -Ev '^[[:space:]]*(#|$|;)' "$@" \
    | awk '{ print tolower($1) }' \
    | sed 's/^\.//' \
    | sort -u
}

sanitize_subnets() {
  grep -Ev '^[[:space:]]*(#|$|;)' "$@" \
    | awk '{ print $1 }' \
    | sort -u
}

filter_ips_stream() {
  grep -Ev '^[[:space:]]*(#|$|;)' \
    | awk 'NF>=1 && $1 ~ /^[0-9]+\./ { print $1 }' \
    | sort -u
}

: >"$zhost" : >"$zexclude" : >"$zipset" : >"$zipset_ex"

if [ ! -f "$CATALOG/upstream/list-general.txt" ]; then
  echo "Upstream lists missing — run scripts/sync-zapret-lists-upstream.sh first" >&2
  exit 2
fi

{
  sanitize_domains "$CATALOG/upstream/list-general.txt" "$CATALOG/upstream/list-google.txt"
  [ -f "$CATALOG/user/domains-zapret.txt" ] && sanitize_domains "$CATALOG/user/domains-zapret.txt"
} | sort -u >"$zhost"

{
  sanitize_domains "$CATALOG/upstream/list-exclude.txt"
  [ -f "$CATALOG/user/domains-direct.txt" ] && sanitize_domains "$CATALOG/user/domains-direct.txt"
} | sort -u >"$zexclude"

{
  cat "$CATALOG/upstream/ipset-all.txt" 2>/dev/null || true
  cat "$CATALOG/upstream/ipset-all.backup.txt" 2>/dev/null || true
  [ -f "$CATALOG/user/ip-zapret.txt" ] && cat "$CATALOG/user/ip-zapret.txt"
} | filter_ips_stream >"$zipset.tmp" && mv -f "$zipset.tmp" "$zipset" \
  || { : >"$zipset"; rm -f "$zipset.tmp" 2>/dev/null || true; }

{
  sanitize_subnets "$CATALOG/upstream/ipset-exclude.txt"
  [ -f "$CATALOG/user/ip-direct.txt" ] && sanitize_subnets "$CATALOG/user/ip-direct.txt"
} | sort -u >"$zipset_ex"

# Mihomo user rules (prepend in gen-mihomo-config.sh).
rules_out="$STATE/generated/mihomo-user-rules.yaml"
{
  if [ -f "$CATALOG/user/domains-direct.txt" ]; then
    while read -r d; do [ -z "$d" ] && continue; echo "- DOMAIN-SUFFIX,$d,DIRECT,no-resolve"; done \
      < <(sanitize_domains "$CATALOG/user/domains-direct.txt")
  fi
  if [ -f "$CATALOG/user/domains-vpn.txt" ]; then
    while read -r d; do [ -z "$d" ] && continue; echo "- DOMAIN-SUFFIX,$d,PROXY,no-resolve"; done \
      < <(sanitize_domains "$CATALOG/user/domains-vpn.txt")
  fi
} >"$rules_out"

echo "Wrote zapret:"
echo "  hostlist → $zhost"
echo "  exclude  → $zexclude"
echo "  ips      → $zipset"
echo "  ip-exc   → $zipset_ex"
echo " mihomo   → $rules_out"
