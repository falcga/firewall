#!/usr/bin/env bash
# Full refresh: lists + geodata + build + restart
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

total_steps=6
current=0

progress_bar "$current" "$total_steps" "🔄 Полное обновление"
current=$(( current + 1 ))

echo ""
echo "📥 [1/$total_steps] Синхронизация списков..."
"$ROOT/scripts/sync-zapret-lists-upstream.sh" || echo "⚠️  sync-zapret-lists предупреждение" >&2
progress_bar "$current" "$total_steps" "📥 Списки ✓"
current=$(( current + 1 ))

echo "🌍 [2/$total_steps] Синхронизация geodata..."
"$ROOT/scripts/sync-geodat.sh" || echo "⚠️  sync-geodat предупреждение" >&2
progress_bar "$current" "$total_steps" "🌍 Geodata ✓"
current=$(( current + 1 ))

echo "🔨 [3/$total_steps] Сборка списков..."
"$ROOT/scripts/build-lists.sh" || echo "⚠️  build-lists предупреждение" >&2
progress_bar "$current" "$total_steps" "🔨 Build ✓"
current=$(( current + 1 ))

echo "⚙️  [4/$total_steps] Генерация конфига Mihomo..."
"$ROOT/scripts/gen-mihomo-config.sh" || echo "⚠️  gen-mihomo-config предупреждение" >&2
progress_bar "$current" "$total_steps" "⚙️  Config ✓"
current=$(( current + 1 ))

echo "🔄 [5/$total_steps] Рестарт Mihomo..."
"$ROOT/scripts/svc-restart-mihomo.sh" || echo "⚠️  mihomo не перезапустился" >&2
progress_bar "$current" "$total_steps" "🔄 Mihomo ✓"
current=$(( current + 1 ))

echo "🔄 [6/$total_steps] Рестарт Zapret..."
"$ROOT/scripts/svc-restart-zapret.sh" || echo "⚠️  zapret не перезапустился" >&2
progress_bar "$current" "$total_steps" "🔄 Zapret ✓"

echo ""
echo "✅ Полное обновление завершено."
