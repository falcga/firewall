#!/usr/bin/env bash
# Генерирует конфиг Mihomo.
#
# Режимы работы:
#   1. SUBSCRIPTION_IS_CONFIG=1 — subscription.url содержит готовый конфиг (скачивается как есть)
#   2. SUBSCRIPTION_IS_CONFIG=0 (по умолч.) — subscription.url содержит только узлы,
#      конфиг собирается из шаблона + скачанных узлов
#
# Прокси: FIREWALL_PROXY=http://... или socks5://... для скачивания геодаты через VPN
set -euo pipefail
. "$(dirname "$0")/lib.sh"

MODE="${FIREWALL_VPN_ROUTE:-split}"
SUBCONFIG="${SUBSCRIPTION_IS_CONFIG:-0}"

subf="$SECRETS/subscription.url"
if [[ ! -f "$subf" ]]; then
  cp "$ROOT/contrib/subscription.url.example" "$subf"
  log_error "Шаблон $subf создан — вставьте URL подписки"
  exit 1
fi

SUB_URL="$(tr -d '\r\n' <"$subf")"
grep -Eq '^https?://' <<<"$SUB_URL" || {
  log_error "subscription.url — только http(s)"
  exit 1
}

outdir="$STATE/mihomo"
mkdir -p "$outdir"

# ─── Режим 1: подписка = полный конфиг ─────────────────────────────────────
if [ "$SUBCONFIG" = "1" ]; then
  log_step "📡" "Режим: подписка = полный конфиг (SUBSCRIPTION_IS_CONFIG=1)"

  curl_args=(-fsSL --connect-timeout 15 --max-time 120)
  if [ -n "$FERWALL_PROXY" ]; then
    curl_args+=(-x "$FERWALL_PROXY")
    log "  прокси: $FERWALL_PROXY"
  fi

  log "  загрузка конфига: $SUB_URL"
  http_code="$(curl "${curl_args[@]}" -w '%{http_code}' -o "$outdir/config.yaml.tmp" "$SUB_URL" 2>/tmp/sub_err.log)" || {
    rc=$?
    err="$(cat /tmp/sub_err.log 2>/dev/null)"
    if [[ "$err" == *"Connection"* ]]; then
      log_error "Не могу соединиться с сервером подписки"
      [ -z "$FERWALL_PROXY" ] && log_error "  → Попробуйте: FIREWALL_PROXY=socks5://127.0.0.1:1080 firewall update"
    else
      log_error "Ошибка загрузки подписки: ${err}"
    fi
    exit 1
  }

  if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
    # Подставляем секрет, если в конфиге есть __SECRET__
    secfile="$SECRETS/mihomo-secret.txt"
    if [[ -f "$secfile" ]]; then
      SECRET="$(tr -d '\r\n' <"$secfile")"
      sed -i "s/__SECRET__/${SECRET}/g" "$outdir/config.yaml.tmp" 2>/dev/null || true
    fi
    mv -f "$outdir/config.yaml.tmp" "$outdir/config.yaml"
    chmod 640 "$outdir/config.yaml"
    echo "  ✓ конфиг загружен из подписки (mode=full)" >&2
    log "config.yaml from subscription"
    exit 0
  fi

  log_error "Сервер подписки ответил HTTP ${http_code}"
  rm -f "$outdir/config.yaml.tmp"
  exit 1
fi

# ─── Режим 2: подписка = только узлы (сборка из шаблона) ───────────────────
log_step "🔧" "Режим: сборка из шаблона (SUBSCRIPTION_IS_CONFIG=0)"

[[ -f "$GEO_DIR/geoip.dat" && -f "$GEO_DIR/geosite.dat" ]] || {
  log_error "Нужны $GEO_DIR/{geoip,geosite}.dat → scripts/sync-geodat.sh"
  exit 2
}

secfile="$SECRETS/mihomo-secret.txt"
if [[ ! -f "$secfile" ]]; then
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 >"$secfile"
  chmod 600 "$secfile"
fi
SECRET="$(tr -d '\r\n' <"$secfile")"

subs_safe() {
  python3 -c 'import sys; print(sys.argv[1].replace(chr(39), chr(39)*2))' "$1"
}
SUB_SQ="$(subs_safe "$SUB_URL")"
SEC_SQ="$(subs_safe "$SECRET")"

rules_user="$STATE/generated/mihomo-user-rules.yaml"
[[ -f "$rules_user" ]] || "$ROOT/scripts/build-lists.sh" 2>/dev/null || true

tmp="$outdir/.config.$$"

python3 -c '
import pathlib, sys
tpl_path, geo, sec_sq, sub_sq = sys.argv[1:5]
text = pathlib.Path(tpl_path).read_text(encoding="utf-8")
for needle, val in (
    ("__GEO_PATH__", geo),
    ("__SECRET__", sec_sq),
    ("__SUBSCRIPTION_URL__", sub_sq),
):
    text = text.replace(needle, val)
print(text, end="")
' "${ROOT}/deploy/mihomo/config.head.yaml.tpl" "$GEO_DIR" "$SEC_SQ" "$SUB_SQ" >"$tmp"

{
  printf 'rules:\n'
  while IFS= read -r r; do
    [[ -z "$r" ]] && continue
    printf '  %s\n' "$r"
  done <"$rules_user"

  case "$MODE" in
  tunnel)
    printf '  - MATCH,PROXY\n'
    ;;
  *)
    printf '  - GEOSITE,ru-blocked,PROXY\n'
    printf '  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve\n'
    printf '  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve\n'
    printf '  - MATCH,DIRECT\n'
    ;;
  esac
} >>"$tmp"

mv -f "$tmp" "$outdir/config.yaml"
chmod 640 "$outdir/config.yaml"
echo "  ✓ config.yaml собран (mode=${MODE})" >&2
log "config.yaml generated (mode=${MODE})"