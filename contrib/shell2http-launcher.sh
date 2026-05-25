#!/usr/bin/env bash
# Все маршруты для shell2http (ставьте бинарь в /usr/local/bin/shell2http).
# set -e отключён — shell2http не любит exit из хуков, остаётся только u (unset vars)
set -uo pipefail
ROOT="${SHELL2HTTP_ROOT:-"$(cd "$(dirname "$0")/.." && pwd)"}"
BIN="${SHELL2HTTP_BIN:-/usr/local/bin/shell2http}"
HOST="${SHELL2HTTP_HOST:-127.0.0.1}"
PORT="${SHELL2HTTP_PORT:-8899}"

# Проверка наличия бинарника
if ! command -v "$BIN" >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
  echo "ERROR: shell2http binary not found at $BIN" >&2
  exit 1
fi

# shell2http запускает хук как: /bin/sh -c "команда"
# Поэтому передаём один вызов bash, который запускает нужный скрипт
exec "$BIN" -host "$HOST" -port "$PORT" -add-exit \
  /full-refresh           "bash '$ROOT/scripts/full-refresh.sh'" \
  /firewall-update        "bash '$ROOT/scripts/update-firewall.sh --no-restart'" \
  /subscription-refresh   "bash '$ROOT/scripts/update-subscription.sh'" \
  /zapret-restart         "bash '$ROOT/scripts/svc-restart-zapret.sh'" \
  /mihomo-restart         "bash '$ROOT/scripts/svc-restart-mihomo.sh'" \
  /sync-build             "bash '$ROOT/scripts/sync-build.sh'" \
  /bypass-off             "bash '$ROOT/scripts/bypass-off.sh'" \
  /bypass-on              "bash '$ROOT/scripts/bypass-on.sh'" \
  /low-power-on           "bash '$ROOT/scripts/low-power-toggle.sh' on" \
  /low-power-off          "bash '$ROOT/scripts/low-power-toggle.sh' off" \
  /zapret-strategies      "bash '$ROOT/scripts/apply-zapret-strategies.sh'" \
  /detect-bypass          "bash '$ROOT/scripts/detect-bypass.sh'" \
  /vpn-up                 "bash '$ROOT/scripts/vpn-up.sh'" \
  /vpn-down               "bash '$ROOT/scripts/vpn-down.sh'" \
  /vpn-status             "bash '$ROOT/scripts/vpn-status.sh'" \
  \
  # ─── Proxy Management API ──────────────────────────────────────────── \
  /proxy-list             "bash '$ROOT/scripts/proxy-mgmt.sh' list" \
  /proxy-status           "bash '$ROOT/scripts/proxy-mgmt.sh' status" \
  /proxy-count            "bash '$ROOT/scripts/proxy-mgmt.sh' count" \
  /proxy-add              "read uri; bash '$ROOT/scripts/proxy-mgmt.sh' add \"\$uri\"" \
  /proxy-delete           "read idx; bash '$ROOT/scripts/proxy-mgmt.sh' delete \"\$idx\"" \
  /proxy-toggle           "read idx; bash '$ROOT/scripts/proxy-mgmt.sh' toggle \"\$idx\"" \
  /mihomo-logs            "bash '$ROOT/scripts/proxy-mgmt.sh' mihomo-logs 100" \
  /geo-update             "bash '$ROOT/scripts/proxy-mgmt.sh' geo-update" \
  \
  # ─── Subscription API ───────────────────────────────────────────────── \
  /sub-list               "bash '$ROOT/scripts/proxy-mgmt.sh' sub-list" \
  /sub-add                "read -r name url; bash '$ROOT/scripts/proxy-mgmt.sh' sub-add \"\$name\" \"\$url\"" \
  /sub-remove             "read idx; bash '$ROOT/scripts/proxy-mgmt.sh' sub-remove \"\$idx\"" \
  /sub-toggle             "read idx; bash '$ROOT/scripts/proxy-mgmt.sh' sub-toggle \"\$idx\"" \
  /sub-fetch              "read url; bash '$ROOT/scripts/proxy-mgmt.sh' sub-fetch \"\$url\"" \
  /sub-update-all         "bash '$ROOT/scripts/proxy-mgmt.sh' sub-update-all" \
  \
  # ─── System Proxy API ───────────────────────────────────────────────── \
  /sysproxy-on            "bash '$ROOT/scripts/proxy-mgmt.sh' sysproxy-on ${2:-127.0.0.1} ${3:-7890}" \
  /sysproxy-off           "bash '$ROOT/scripts/proxy-mgmt.sh' sysproxy-off" \
  /sysproxy-status        "bash '$ROOT/scripts/proxy-mgmt.sh' sysproxy-status"
