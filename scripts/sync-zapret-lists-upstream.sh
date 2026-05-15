#!/usr/bin/env bash
# Fetch Flowseal text lists used for merge (upstream).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_dirs

# Проверяем DNS перед началом загрузки
ensure_dns

total=${#flowseal_lists[@]}
total=$(( total + 1 )) # +1 for ipset backup

echo ""
echo "📥 Скачивание списков Flowseal..."

# Сначала пробуем основной URL
BASE_OK=true
if ! curl -fsSL -o /dev/null --connect-timeout 5 "${UPSTREAM_ZAPRET_BASE}/ipset-all.txt" 2>/dev/null; then
  BASE_OK=false
  echo "⚠️  Основной URL недоступен. Пробую mirror..."
fi

current=0
for f in "${flowseal_lists[@]}"; do
  current=$(( current + 1 ))
  out="$CATALOG/upstream/$f"
  progress_bar "$current" "$total" "📦 [$current/$total]"
  fetch_remote_with_progress "$out" "$UPSTREAM_ZAPRET_BASE/$f" "" || true
done

current=$(( current + 1 ))
progress_bar "$current" "$total" "📦 [$current/$total]"
fetch_remote_with_progress "$CATALOG/upstream/ipset-all.backup.txt" \
  "$UPSTREAM_ZAPRET_BASE/ipset-all.txt.backup" "" || true

echo ""
echo "✅ Списки синхронизированы."
