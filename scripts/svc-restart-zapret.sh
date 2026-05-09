#!/usr/bin/env bash
set -euo pipefail

ZAPRET_SERVICE="${ZAPRET_SERVICE:-}"

if [[ -n "$ZAPRET_SERVICE" ]]; then
  exec systemctl restart "$ZAPRET_SERVICE"
fi

for s in zapret.service zapret-firewall.service nft-zapret.service; do
  if systemctl cat "$s" >/dev/null 2>&1; then
    exec systemctl restart "$s"
  fi
done

if [[ -x /usr/local/etc/init.d/zapret ]]; then
  exec /usr/local/etc/init.d/zapret restart
fi

if [[ -x /opt/zapret/init.d.sysv ]]; then
  exec /opt/zapret/init.d.sysv restart
fi

echo "Zapret service не найден — задайте ZAPRET_SERVICE или установите bol-van/zapret." >&2
exit 127
