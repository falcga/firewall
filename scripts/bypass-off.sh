#!/usr/bin/env bash
# Короткая остановка обходов: трафик идёт «как с Pi» напрямую к провайдеру.
set -euo pipefail
MIHOMO_SERVICE="${MIHOMO_SERVICE:-mihomo.service}"
Z="${ZAPRET_SERVICE:-}"

for s in zapret.service zapret-firewall.service nft-zapret.service; do
  if systemctl cat "$s" >/dev/null 2>&1 && [[ -z "$Z" ]]; then
    Z="$s"
    break
  fi
done

systemctl stop "$MIHOMO_SERVICE" 2>/dev/null || true

if [[ -n "$Z" ]]; then systemctl stop "$Z" || true; fi

if [[ -x /opt/zapret/stop-fw.sh ]]; then
  /opt/zapret/stop-fw.sh || true
elif [[ -x /opt/zapret/stop-fw-nft.sh ]]; then
  /opt/zapret/stop-fw-nft.sh || true
elif [[ -x /usr/local/etc/init.d/zapret ]]; then
  /usr/local/etc/init.d/zapret stop || true
fi

echo bypass-off завершено.
