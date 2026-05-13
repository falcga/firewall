#!/usr/bin/env bash
# Опустить VPN-соединение (WireGuard или OpenVPN)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-setup-tui"
STATE_FILE="$STATE_DIR/state.conf"

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
fi

VPN_PROTO="${VPN_PROTO:-wireguard}"

usage() {
  cat <<EOF
Использование: $(basename "$0") [--proto wireguard|openvpn] [--interface имя]

  --proto        Протокол VPN: wireguard (по умолч.) или openvpn
  --interface    Имя интерфейса (для WireGuard, по умолч. wg0)
  --help         Эта справка

Примеры:
  $(basename "$0")
  $(basename "$0") --proto wireguard --interface wg0
  $(basename "$0") --proto openvpn
EOF
}

wg_down() {
  local interface="${1:-wg0}"

  if command -v wg-quick >/dev/null 2>&1; then
    echo "Опускаю WireGuard: $interface"
    wg-quick down "$interface" 2>&1 || true
  fi

  # Дополнительная очистка
  if ip link show "$interface" >/dev/null 2>&1; then
    ip link set "$interface" down 2>/dev/null || true
    ip link delete "$interface" 2>/dev/null || true
    echo "Интерфейс $interface удалён"
  fi

  # Удаляем маршруты
  ip route show | grep "$interface" | while read -r route; do
    ip route del $route 2>/dev/null || true
  done

  echo "WireGuard остановлен"
}

ovpn_down() {
  if ! command -v openvpn >/dev/null 2>&1; then
    echo "OpenVPN не установлен" >&2
    return 127
  fi

  local ovpn_pids
  ovpn_pids="$(pgrep -f "openvpn.*--daemon" 2>/dev/null || true)"
  if [[ -n "$ovpn_pids" ]]; then
    echo "Останавливаю OpenVPN (PID: $ovpn_pids)"
    kill $ovpn_pids 2>/dev/null || true
    sleep 1
    # Проверяем, что остановились
    ovpn_pids="$(pgrep -f "openvpn.*--daemon" 2>/dev/null || true)"
    if [[ -n "$ovpn_pids" ]]; then
      kill -9 $ovpn_pids 2>/dev/null || true
    fi
    echo "OpenVPN остановлен"
  else
    echo "OpenVPN не запущен"
  fi

  # Очищаем tun интерфейсы
  for iface in /sys/class/net/tun*; do
    local name
    name="$(basename "$iface")"
    if [[ -d "$iface" ]]; then
      ip link set "$name" down 2>/dev/null || true
      echo "Интерфейс $name опущен"
    fi
  done
}

main() {
  local proto="$VPN_PROTO"
  local interface=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proto) proto="$2"; shift ;;
      --interface) interface="$2"; shift ;;
      --help) usage; exit 0 ;;
      *) interface="$1" ;;
    esac
    shift
  done

  case "$proto" in
    wireguard|wg)
      wg_down "${interface:-wg0}"
      ;;
    openvpn|ovpn)
      ovpn_down
      ;;
    *)
      echo "Неизвестный протокол: $proto" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"