#!/usr/bin/env bash
# Shared defaults for Raspberry Pi gateway (adjust paths once here).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/catalog"
STATE="${STATE:-$ROOT/state}"
SECRETS="${SECRETS:-$ROOT/secrets}"

UPSTREAM_ZAPRET_BASE="https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/main/lists"
RULES_DAT_API="https://api.github.com/repos/runetfreedom/russia-v2ray-rules-dat/releases/latest"

GEO_DIR="${GEO_DIR:-$STATE/geodata}"
GEO_TAG_FILE="$GEO_DIR/last-tag.txt"

flowseal_lists=(
  list-general.txt
  list-google.txt
  list-exclude.txt
  ipset-exclude.txt
  ipset-all.txt
)

# Проверка DNS — если не резолвится, ставим 8.8.8.8
ensure_dns() {
  if ! host raw.githubusercontent.com >/dev/null 2>&1 && \
     ! nslookup raw.githubusercontent.com >/dev/null 2>&1 && \
     ! curl -fsSL -o /dev/null --connect-timeout 3 "https://raw.githubusercontent.com" 2>/dev/null; then
    echo "⚠️ DNS не работает. Устанавливаю nameserver 8.8.8.8..."
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null 2>&1 || \
    echo "nameserver 8.8.8.8" | tee /etc/resolv.conf >/dev/null 2>&1 || true
    sleep 1
  fi
}

fetch_remote() {
  local path="$1" url="$2"
  mkdir -p "$(dirname "$path")"
  curl -fsSL "$url" -o "$path.tmp" && mv -f "$path.tmp" "$path"
}

# Прогресс-бар для длинных операций
progress_bar() {
  local current="$1" total="$2" label="${3:-}"
  local percent=0
  local bar_len=30
  if [ "$total" -gt 0 ]; then
    percent=$(( current * 100 / total ))
  fi
  local filled=$(( current * bar_len / total ))
  local empty=$(( bar_len - filled ))
  local bar=""
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  printf "\r\033[K%s [%s] %3d%%" "${label:+$label }" "$bar" "$percent"
}

# Обёртка для последовательного скачивания с прогрессом
fetch_remote_with_progress() {
  local path="$1" url="$2" label="${3:-}"
  if [ -n "$label" ]; then
    echo -n "  $label ... "
  fi
  mkdir -p "$(dirname "$path")"
  if curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$path.tmp"; then
    mv -f "$path.tmp" "$path"
    if [ -n "$label" ]; then
      echo "✓"
    fi
    return 0
  else
    rm -f "$path.tmp"
    if [ -n "$label" ]; then
      echo "✗ failed"
    fi
    return 1
  fi
}

ensure_dirs() {
  mkdir -p "$STATE/generated" "$STATE/providers" "$GEO_DIR" \
    "$ROOT/catalog/upstream" "$SECRETS" 2>/dev/null || true
}
