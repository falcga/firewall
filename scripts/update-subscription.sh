#!/usr/bin/env bash
# Перескачивает конфиг Mihomo из подписки.
# SUBSCRIPTION_IS_CONFIG=1 — полный конфиг, SUBSCRIPTION_IS_CONFIG=0 — только узлы
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

log_step "📡" "Обновление подписки Mihomo..."
"$ROOT/scripts/gen-mihomo-config.sh" || {
  log_error "gen-mihomo-config.sh failed"
  exit 1
}
"$ROOT/scripts/svc-restart-mihomo.sh" || {
  log_error "svc-restart-mihomo.sh failed"
  exit 1
}
echo "  ✓ подписка обновлена" >&2
log "subscription update done"