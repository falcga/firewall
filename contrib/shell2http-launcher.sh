#!/usr/bin/env bash
# Все маршруты для shell2http (ставьте бинарь в /usr/local/bin/shell2http).
# set -e отключён — shell2http не любит exit из хуков, остаётся только u (unset vars)
set -uo pipefail
ROOT="${SHELL2HTTP_ROOT:-"$(cd "$(dirname "$0")/.." && pwd)"}"
BIN="${SHELL2HTTP_BIN:-/usr/local/bin/shell2http}"
LISTEN="${SHELL2HTTP_LISTEN:-127.0.0.1:8899}"

# Проверка наличия бинарника
if ! command -v "$BIN" >/dev/null 2>&1 && [ ! -x "$BIN" ]; then
  echo "ERROR: shell2http binary not found at $BIN" >&2
  exit 1
fi

# Функция-обёртка: проверяет существование скрипта перед запуском
safe_exec() {
  local script="$1"
  shift
  if [ -x "$script" ]; then
    exec "$script" "$@"
  else
    echo "ERROR: script not found or not executable: $script" >&2
    exit 127
  fi
}

exec "$BIN" -listen "$LISTEN" \
  /full-refresh           "safe_exec $ROOT/scripts/full-refresh.sh" \
  /subscription-refresh   "safe_exec $ROOT/scripts/update-subscription.sh" \
  /zapret-restart         "safe_exec $ROOT/scripts/svc-restart-zapret.sh" \
  /mihomo-restart         "safe_exec $ROOT/scripts/svc-restart-mihomo.sh" \
  /sync-build             "safe_exec $ROOT/scripts/sync-build.sh" \
  /bypass-off             "safe_exec $ROOT/scripts/bypass-off.sh" \
  /bypass-on              "safe_exec $ROOT/scripts/bypass-on.sh" \
  /low-power-on           "safe_exec $ROOT/scripts/low-power-toggle.sh" on \
  /low-power-off          "safe_exec $ROOT/scripts/low-power-toggle.sh" off \
  /zapret-strategies      "safe_exec $ROOT/scripts/apply-zapret-strategies.sh" \
  /detect-bypass          "safe_exec $ROOT/scripts/detect-bypass.sh" \
  /vpn-up                 "safe_exec $ROOT/scripts/vpn-up.sh" \
  /vpn-down               "safe_exec $ROOT/scripts/vpn-down.sh" \
  /vpn-status             "safe_exec $ROOT/scripts/vpn-status.sh"
