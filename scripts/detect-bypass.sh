#!/usr/bin/env bash
# Проверка обхода блокировок — детектит, работают ли меры обхода (zapret, mihomo)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GENERATED_DIR="${ROOT}/state/generated"

# Список тестовых сайтов для проверки доступности
TEST_SITES=(
  "https://rutube.ru"
  "https://vk.com"
  "https://yandex.ru"
  "https://ok.ru"
  "https://www.mos.ru"
  "https://www.kremlin.ru"
  "https://www.gosuslugi.ru"
)

# Список заблокированных сайтов для проверки обхода
BLOCKED_SITES=(
  "https://www.youtube.com"
  "https://twitter.com"
  "https://www.facebook.com"
  "https://www.instagram.com"
  "https://t.me"
  "https://discord.com"
)

usage() {
  cat <<EOF
Использование: $(basename "$0") [--quick] [--full] [--dns-only] [--verbose]

  --quick       Быстрая проверка — только заблокированные сайты (3 попытки)
  --full        Полная проверка — все тесты + traceroute
  --dns-only    Только проверка DNS
  --verbose     Подробный вывод
  --help        Эта справка

Пример:
  $(basename "$0") --quick
  $(basename "$0") --full --verbose
EOF
}

check_dns() {
  local domain="$1"
  local result
  result="$(dig +short "$domain" 2>/dev/null || nslookup "$domain" 2>/dev/null | grep -A1 'Name:' | tail -n1 | awk '{print $NF}' || echo "FAIL")"
  printf '%s' "$result"
}

check_http() {
  local url="$1" timeout="$2"
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout "${timeout}" --max-time "$((timeout + 2))" "$url" 2>/dev/null || echo "000")"
  printf '%s' "$code"
}

check_ping() {
  local host="$1"
  local result
  result="$(ping -c 1 -W 3 "$host" 2>&1 | grep -oE '1 (received|packets received)' || echo "FAIL")"
  if [[ "$result" == "1 "* ]]; then echo "OK"; else echo "FAIL"; fi
}

detect_bypass_mechanisms() {
  echo "=== Детектирование работающих механизмов обхода ==="

  # Проверка Mihomo
  if command -v mihomo >/dev/null 2>&1; then
    local mihomo_pid
    mihomo_pid="$(pgrep mihomo 2>/dev/null || true)"
    if [[ -n "$mihomo_pid" ]]; then
      echo "  ✓ Mihomo: запущен (PID $mihomo_pid)"
    else
      echo "  ✗ Mihomo: бинарник есть, но процесс не запущен"
    fi
  else
    echo "  ✗ Mihomo: не установлен"
  fi

  # Проверка zapret (nfqws)
  local nfqws=""
  for p in /usr/local/bin/nfqws /opt/zapret/nfqws /usr/bin/nfqws /usr/local/sbin/nfqws; do
    if [[ -x "$p" ]]; then
      nfqws="$p"
      break
    fi
  done
  if [[ -n "$nfqws" ]]; then
    local nfqws_pid
    nfqws_pid="$(pgrep -f nfqws 2>/dev/null || true)"
    if [[ -n "$nfqws_pid" ]]; then
      echo "  ✓ nfqws: запущен ($nfqws_pid)"
    else
      echo "  ✗ nfqws: бинарник есть ($nfqws), процесс не запущен"
    fi
  else
    echo "  ✗ nfqws/zapret: не установлен"
  fi

  # Проверка стратегий
  if [[ -f "$GENERATED_DIR/zapret-strategies.conf" ]]; then
    local strategies
    strategies="$(cat "$GENERATED_DIR/zapret-strategies.conf")"
    echo "  ✓ Стратегии zapret: $strategies"
  else
    echo "  - Стратегии zapret: не настроены"
  fi

  # Проверка WireGuard
  if command -v wg >/dev/null 2>&1 || command -v wg-quick >/dev/null 2>&1; then
    local wg_interfaces
    wg_interfaces="$(wg show interfaces 2>/dev/null || echo '')"
    if [[ -n "$wg_interfaces" ]]; then
      echo "  ✓ WireGuard: активен ($wg_interfaces)"
    else
      echo "  - WireGuard: установлен, но не активен"
    fi
  else
    echo "  - WireGuard: не установлен"
  fi

  # Проверка OpenVPN
  if command -v openvpn >/dev/null 2>&1; then
    local ovpn_pid
    ovpn_pid="$(pgrep openvpn 2>/dev/null || true)"
    if [[ -n "$ovpn_pid" ]]; then
      echo "  ✓ OpenVPN: запущен (PID $ovpn_pid)"
    else
      echo "  - OpenVPN: установлен, но не активен"
    fi
  else
    echo "  - OpenVPN: не установлен"
  fi

  # Проверка глобальных iptables/nftables правил zapret
  if command -v nft >/dev/null 2>&1; then
    local nft_zapret
    nft_zapret="$(nft list ruleset 2>/dev/null | grep -c zapret || true)"
    if [[ "$nft_zapret" -gt 0 ]]; then
      echo "  ✓ nftables: правила zapret обнаружены"
    else
      echo "  - nftables: правила zapret не найдены"
    fi
  fi

  echo ""
}

check_site() {
  local url="$1" timeout="$2" verbose="$3"
  local domain
  domain="$(echo "$url" | sed 's|https*://||' | sed 's|/.*$||')"

  local http_code
  http_code="$(check_http "$url" "$timeout")"

  local dns_result
  if [[ "$verbose" == "1" ]]; then
    dns_result="$(check_dns "$domain")"
    if [[ -z "$dns_result" || "$dns_result" == "FAIL" ]]; then
      dns_result="НЕТ РАЗРЕШЕНИЯ"
    fi
  fi

  if [[ "$http_code" == "000" ]]; then
    echo "  ✗ $url → недоступен (таймаут/ошибка)"
    return 1
  elif [[ "$http_code" == "200" ]] || [[ "$http_code" == "301" ]] || [[ "$http_code" == "302" ]]; then
    if [[ "$verbose" == "1" ]]; then
      echo "  ✓ $url → HTTP $http_code (DNS: $dns_result)"
    else
      echo "  ✓ $url → HTTP $http_code"
    fi
    return 0
  else
    if [[ "$verbose" == "1" ]]; then
      echo "  ? $url → HTTP $http_code (DNS: $dns_result)"
    else
      echo "  ? $url → HTTP $http_code"
    fi
    return 2
  fi
}

run_quick_test() {
  local verbose="${1:-0}"
  local timeout="${2:-5}"

  echo "=== Быстрая проверка обхода блокировок ==="
  echo "Проверка: ${#BLOCKED_SITES[@]} заблокированных сайтов"
  echo ""

  local accessible=0
  local inaccessible=0

  for site in "${BLOCKED_SITES[@]}"; do
    if check_site "$site" "$timeout" "$verbose"; then
      accessible=$((accessible + 1))
    else
      inaccessible=$((inaccessible + 1))
    fi
  done

  echo ""
  echo "Итог: доступно $accessible / $((accessible + inaccessible)) заблокированных сайтов"
  if [[ "$accessible" -gt 0 ]]; then
    echo "ВЫВОД: Обход блокировок РАБОТАЕТ ($accessible из $((accessible + inaccessible)) сайтов доступны)"
    exit 0
  else
    echo "ВЫВОД: Обход блокировок НЕ РАБОТАЕТ (0 сайтов доступно)"
    exit 1
  fi
}

run_full_test() {
  local verbose="${1:-1}"
  local timeout="${2:-10}"

  echo "==================================="
  echo "ПОЛНАЯ ПРОВЕРКА ОБХОДА БЛОКИРОВОК"
  echo "==================================="
  echo ""

  # Детектируем механизмы
  detect_bypass_mechanisms

  # Проверка DNS
  echo "=== Проверка DNS ==="
  local dns_servers
  dns_servers="$(resolvectl status 2>/dev/null | grep 'DNS Servers' | head -n1 | awk '{print $NF}')"
  if [[ -z "$dns_servers" ]]; then
    dns_servers="$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $NF}' | tr '\n' ' ')"
  fi
  if [[ -n "$dns_servers" ]]; then
    echo "  DNS серверы: $dns_servers"
  fi

  # Проверка разрешения доменов
  for domain in "rutube.ru" "youtube.com" "discord.com" "google.com" "telegram.org"; do
    local dns_result
    dns_result="$(check_dns "$domain")"
    if [[ -z "$dns_result" || "$dns_result" == "FAIL" ]]; then
      echo "  ✗ $domain → НЕ разрешается"
    else
      echo "  ✓ $domain → $dns_result"
    fi
  done
  echo ""

  # Проверка российских сайтов (должны быть доступны)
  echo "=== Российские сайты (доступность без обхода) ==="
  for site in "${TEST_SITES[@]}"; do
    check_site "$site" "$timeout" "$verbose" || true
  done
  echo ""

  # Проверка заблокированных сайтов (обход)
  echo "=== Заблокированные сайты (проверка обхода) ==="
  local bypass_works=0
  for site in "${BLOCKED_SITES[@]}"; do
    if check_site "$site" "$timeout" "$verbose"; then
      bypass_works=$((bypass_works + 1))
    fi
  done
  echo ""

  # Traceroute к одному из заблокированных
  if command -v traceroute >/dev/null 2>&1; then
    local target="youtube.com"
    echo "=== Traceroute к $target ==="
    traceroute -n -q 1 -w 2 "$target" 2>&1 | head -n 15
    echo ""
  fi

  echo "=== Итог ==="
  if [[ "$bypass_works" -gt 0 ]]; then
    echo "  Обход блокировок РАБОТАЕТ ($bypass_works из ${#BLOCKED_SITES[@]} заблокированных доступны)"
    exit 0
  else
    echo "  Обход блокировок НЕ РАБОТАЕТ (0 из ${#BLOCKED_SITES[@]})"
    exit 1
  fi
}

run_dns_only() {
  echo "=== Проверка DNS ==="
  local dns_servers
  dns_servers="$(resolvectl status 2>/dev/null | grep 'DNS Servers' | head -n1 | awk '{print $NF}')"
  if [[ -z "$dns_servers" ]]; then
    dns_servers="$(grep '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $NF}' | tr '\n' ' ')"
  fi
  echo "  DNS серверы: $dns_servers"
  echo ""

  local all_domains=("${TEST_SITES[@]}" "${BLOCKED_SITES[@]}")
  all_domains=("${all_domains[@]}")
  for site in "${BLOCKED_SITES[@]}" "youtube.com" "discord.com" "google.com" "telegram.org"; do
    local domain
    domain="$(echo "$site" | sed 's|https*://||' | sed 's|/.*$||')"
    local dns_result
    dns_result="$(check_dns "$domain")"
    if [[ -z "$dns_result" || "$dns_result" == "FAIL" ]]; then
      echo "  ✗ $domain → НЕ разрешается"
    else
      echo "  ✓ $domain → $dns_result"
    fi
  done

  # Проверка DoH/DoT
  if [[ -f /etc/nginx/conf.d/default.conf ]]; then
    local doh_detect
    doh_detect="$(grep -r 'dns' /etc/nginx/ 2>/dev/null | grep -i 'proxy_pass\|upstream' | head -n 3 || true)"
    if [[ -n "$doh_detect" ]]; then
      echo ""
      echo "  Обнаружена DNS-конфигурация в nginx:"
      echo "  $doh_detect"
    fi
  fi
}

main() {
  local mode="quick"
  local verbose=0

  if [[ $# -eq 0 ]]; then
    run_quick_test "$verbose"
    return
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quick) mode="quick" ;;
      --full) mode="full"; verbose=1 ;;
      --dns-only) mode="dns" ;;
      --verbose) verbose=1 ;;
      --help) usage; exit 0 ;;
      *) echo "Неизвестный аргумент: $1" >&2; usage; exit 1 ;;
    esac
    shift
  done

  case "$mode" in
    quick) run_quick_test "$verbose" ;;
    full) run_full_test "$verbose" ;;
    dns) run_dns_only ;;
  esac
}

main "$@"