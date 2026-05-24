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

LOGS_DIR="${LOGS_DIR:-$ROOT/logs}"
UPDATE_LOG="$LOGS_DIR/firewall-update.log"

flowseal_lists=(
  list-general.txt
  list-google.txt
  list-exclude.txt
  ipset-exclude.txt
  ipset-all.txt
)

# ─── Логирование ────────────────────────────────────────────────────────────
# init_logs — создать директорию логов и очистить старые (>7 дней)
init_logs() {
  mkdir -p "$LOGS_DIR"
  find "$LOGS_DIR" -name '*.log' -mtime +7 -delete 2>/dev/null || true
}

# log — записать в лог-файл и вывести краткое сообщение в терминал
log() {
  local msg="$1" level="${2:-INFO}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  init_logs
  printf '[%s] %-5s %s\n' "$ts" "$level" "$msg" >> "$UPDATE_LOG"
}

# log_console — вывести в терминал только важное (с уровнем)
log_console() {
  local msg="$1" level="${2:-INFO}"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] %s %s\n' "$ts" "$msg" >&2
}

# log_step — короткое сообщение в терминал + подробный лог
log_step() {
  local step="$1" msg="$2"
  init_logs
  echo "[${step}] ${msg}" >&2
  log "[${step}] ${msg}"
}

# log_error — ошибка с выводом в stderr
log_error() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[${ts}] ОШИБКА: ${msg}" >&2
  printf '[%s] ERROR %s\n' "$ts" "$msg" >> "$UPDATE_LOG"
}

# run_silent — выполнить команду, спрятав stdout (только stderr в лог)
run_silent() {
  local label="$1"
  shift
  log "[${label}] $*"
  "$@" >> "$UPDATE_LOG" 2>&1 || {
    local rc=$?
    log_error "[${label}] failed (exit ${rc})"
    return "$rc"
  }
}

# run_with_progress — выполнить с прогресс-баром (stdout скрыт)
run_with_progress() {
  local label="$1"
  shift
  log "[${label}] $*"
  "$@" 2>&1 | while IFS= read -r line; do
    # показываем строки с прогрессом и ошибки
    if [[ "$line" =~ ^(📦|📥|✅|⚠️|\[|Wrote) ]] || [[ "$line" =~ (error|Error|fail) ]]; then
      log_console "$line"
    fi
    echo "$line" >> "$UPDATE_LOG"
  done
  local rc=${PIPESTATUS[0]}
  if [ "$rc" -ne 0 ]; then
    log_error "[${label}] failed (exit ${rc})"
  fi
  return "$rc"
}

# ─── DNS ────────────────────────────────────────────────────────────────────
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

# ─── HTTP helper с прокси ──────────────────────────────────────────────────
# Устанавливает прокси для curl, если задан PROXY
FERWALL_PROXY="${FIREWALL_PROXY:-}"
_fetch() {
  local url="$1" out="$2" desc="${3:-}"
  local curl_args=(-fsSL --connect-timeout 15 --max-time 120)
  if [ -n "$FERWALL_PROXY" ]; then
    curl_args+=(-x "$FERWALL_PROXY")
  fi
  if curl "${curl_args[@]}" "$url" -o "$out.tmp" 2>/dev/null; then
    mv -f "$out.tmp" "$out"
    return 0
  fi
  rm -f "$out.tmp"
  return 1
}

fetch_remote() {
  local path="$1" url="$2"
  mkdir -p "$(dirname "$path")"
  _fetch "$url" "$path"
}

# ─── Прогресс-бар ──────────────────────────────────────────────────────────
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

fetch_remote_with_progress() {
  local path="$1" url="$2" label="${3:-}"
  if [ -n "$label" ]; then
    echo -n "  $label ... "
  fi
  mkdir -p "$(dirname "$path")"
  if _fetch "$url" "$path"; then
    if [ -n "$label" ]; then
      echo "✓"
    fi
    return 0
  else
    rm -f "$path.tmp" 2>/dev/null || true
    if [ -n "$label" ]; then
      echo "✗ failed"
    fi
    return 1
  fi
}

ensure_dirs() {
  mkdir -p "$STATE/generated" "$STATE/providers" "$GEO_DIR" \
    "$ROOT/catalog/upstream" "$SECRETS" "$LOGS_DIR" 2>/dev/null || true
}