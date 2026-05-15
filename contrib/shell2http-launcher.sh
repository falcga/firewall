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
  /vpn-status             "bash '$ROOT/scripts/vpn-status.sh'"
