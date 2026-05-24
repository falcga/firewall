#!/usr/bin/env bash
# Синхронизация geodata (geoip.dat + geosite.dat) через API GitHub.
# Поддерживает прокси через FIREWALL_PROXY (http://... или socks5://...).
set -euo pipefail
. "$(dirname "$0")/lib.sh"
ensure_dirs

log_step "🌍" "Синхронизация geodata..."

# Функция для детального вывода ошибки curl
_geodata_fetch() {
  local url="$1" out="$2" label="${3:-файл}"
  local curl_args=(-fL --retry 3 --connect-timeout 15 --max-time 120)
  if [ -n "$FERWALL_PROXY" ]; then
    curl_args+=(-x "$FERWALL_PROXY")
    log "  прокси: $FERWALL_PROXY"
  fi

  local http_code
  http_code="$(curl "${curl_args[@]}" -w '%{http_code}' -o "$out.part" "$url" 2>/tmp/geodata_err.log)" || {
    local rc=$?
    local err_msg
    err_msg="$(cat /tmp/geodata_err.log 2>/dev/null || true)"
    log_error "Не удалось скачать ${label} с ${url} (HTTP ${http_code:-?})"
    if [[ "$err_msg" == *"Connection refused"* ]] || [[ "$err_msg" == *"Connection timed out"* ]]; then
      log_error "  → Не могу соединиться. Проверьте интернет или настройте FIREWALL_PROXY"
      if [ -z "$FERWALL_PROXY" ]; then
        log_error "  → Например: FIREWALL_PROXY=socks5://127.0.0.1:1080 firewall update"
      fi
    elif [[ "$err_msg" == *"SSL"* ]] || [[ "$err_msg" == *"certificate"* ]]; then
      log_error "  → Проблема с SSL/TLS. Попробуйте обновить ca-certificates"
    elif [ "$http_code" = "502" ] || [ "$http_code" = "503" ] || [ "$http_code" = "504" ]; then
      log_error "  → Временная ошибка сервера ($http_code). Повторите позже"
    elif [ "$http_code" = "403" ]; then
      log_error "  → Доступ запрещён (403). Возможно, превышен лимит запросов к GitHub API"
    elif [ "$http_code" = "404" ]; then
      log_error "  → Файл не найден (404). Возможно, изменился формат тега"
    else
      log_error "  → ${err_msg}"
    fi
    return "$rc"
  }

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    mv -f "$out.part" "$out"
    log "  ${label}: OK (${url})"
    return 0
  fi

  log_error "Неожиданный HTTP-статус ${http_code} для ${label}"
  rm -f "$out.part"
  return 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

REL="$tmpdir/rel.json"
log "  запрос API: $RULES_DAT_API"

# Пробуем через прокси, если задан
curl_args=(-fsSL --connect-timeout 15 --max-time 60)
if [ -n "$FERWALL_PROXY" ]; then
  curl_args+=(-x "$FERWALL_PROXY")
fi

http_code="$(curl "${curl_args[@]}" -w '%{http_code}' "$RULES_DAT_API" -o "$REL" 2>/tmp/api_err.log)" || {
  rc=$?
  err="$(cat /tmp/api_err.log 2>/dev/null)"
  if [[ "$err" == *"Connection"* ]] || [ "$rc" = "7" ] || [ "$rc" = "28" ]; then
    if [ -n "$FERWALL_PROXY" ]; then
      log_error "API GitHub недоступен через прокси $FERWALL_PROXY"
    else
      log_error "API GitHub недоступен напрямую. Попробуйте настроить FIREWALL_PROXY для скачивания через VPN"
      log_error "  sudo FIREWALL_PROXY=socks5://127.0.0.1:1080 firewall update"
    fi
  else
    log_error "Ошибка при запросе GitHub API: ${err}"
  fi
  exit 1
}

if [ "$http_code" != "200" ]; then
  log_error "GitHub API ответил HTTP ${http_code}"
  [ "$http_code" = "403" ] && log_error "  → Превышен лимит запросов к GitHub API"
  exit 1
fi

tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <"$REL" 2>/dev/null)" || {
  log_error "Не удалось извлечь tag_name из ответа API GitHub"
  exit 1
}
[ -n "$tag" ] || { log_error "Пустой tag_name"; exit 1; }

log "  тег: $tag"

base='https://github.com/runetfreedom/russia-v2ray-rules-dat/releases/download'
dl() {
  local name="$1"
  log_step "📦" "  загрузка ${name}..."
  _geodata_fetch "${base}/${tag}/${name}" "$GEO_DIR/$name" "$name"
}

dl geoip.dat
dl geosite.dat

echo "$tag" >"$GEO_TAG_FILE"
echo "  ✓ geodata: ${tag} → ${GEO_DIR}" >&2
log "geodata установлены (${tag})"