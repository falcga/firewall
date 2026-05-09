#!/usr/bin/env bash
# Все маршруты для shell2http (ставьте бинарь в /usr/local/bin/shell2http).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${SHELL2HTTP_BIN:-/usr/local/bin/shell2http}"
LISTEN="${SHELL2HTTP_LISTEN:-127.0.0.1:8899}"
exec "$BIN" -listen "$LISTEN" \
  /full-refresh "$ROOT/scripts/full-refresh.sh" \
  /subscription-refresh "$ROOT/scripts/update-subscription.sh" \
  /zapret-restart "$ROOT/scripts/svc-restart-zapret.sh" \
  /mihomo-restart "$ROOT/scripts/svc-restart-mihomo.sh" \
  /sync-build "$ROOT/scripts/sync-build.sh" \
  /bypass-off "$ROOT/scripts/bypass-off.sh" \
  /bypass-on "$ROOT/scripts/bypass-on.sh" \
  /low-power-on "$ROOT/scripts/low-power-toggle.sh" on \
  /low-power-off "$ROOT/scripts/low-power-toggle.sh" off
