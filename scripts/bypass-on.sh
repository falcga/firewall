#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIHOMO_SERVICE="${MIHOMO_SERVICE:-mihomo.service}"
Z="${ZAPRET_SERVICE:-}"

for s in zapret.service zapret-firewall.service nft-zapret.service; do
  if systemctl cat "$s" >/dev/null 2>&1 && [[ -z "$Z" ]]; then Z="$s"; break; fi
done

"$ROOT/scripts/gen-mihomo-config.sh" >/dev/null
systemctl start "$MIHOMO_SERVICE" || systemctl restart "$MIHOMO_SERVICE"

if [[ -n "$Z" ]]; then systemctl start "$Z" || true; fi

if [[ -z "$Z" && -x /usr/local/etc/init.d/zapret ]]; then
  /usr/local/etc/init.d/zapret start || true
fi

echo bypass-on выполнено — проверьте zapret-хостлисты если сервис кастомный.
