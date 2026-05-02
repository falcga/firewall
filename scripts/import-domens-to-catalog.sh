#!/usr/bin/env bash
# Разбор import-domens.txt → дополняет catalog/user/domains-zapret.txt и ip-zapret.txt.
set -euo pipefail
. "$(dirname "$0")/lib.sh"

src="${1:-$CATALOG/user/import-domens.txt}"
[ -f "$src" ] || {
  echo "Нет файла $src" >&2
  exit 1
}

touch "$CATALOG/user/domains-zapret.txt" "$CATALOG/user/ip-zapret.txt"

td="$(mktemp)"
ti="$(mktemp)"
trap 'rm -f "$td" "$ti"' EXIT

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%$'\r'}"
  [[ "$line" =~ ^[[:space:]]*(#|$|;) ]] && continue
  read -ra F <<<"$line"
  [[ ${#F[@]} -eq 0 ]] && continue

  if [[ ${#F[@]} -ge 2 && "${F[0]}" =~ ^[0-9]+\.[0-9]+ ]]; then
    echo "${F[0]}" >>"$ti"
    echo "${F[1]}" >>"$td"
  else
    echo "${F[0]}" >>"$td"
  fi
done <"$src"

touch "$ti" "$td"
sort -u "$CATALOG/user/domains-zapret.txt" "$td" -o "$CATALOG/user/domains-zapret.txt"
sort -u "$CATALOG/user/ip-zapret.txt" "$ti" -o "$CATALOG/user/ip-zapret.txt"
echo "Обновлено домены/IP из $src"
