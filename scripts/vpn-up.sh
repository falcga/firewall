#!/usr/bin/env bash
# Поднять VPN-соединение (WireGuard или OpenVPN)
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-setup-tui"
STATE_FILE="$STATE_DIR/state.conf"
VPN_CONFIG_DIR="${VPN_CONFIG_DIR:-$ROOT/secrets/vpn}"

# Загрузка state
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
fi

VPN_PROTO="${VPN_PROTO:-wireguard}"
VPN_CONFIG="${VPN_CONFIG:-}"

usage() {
  cat <<EOF
Использование: $(basename "$0") [--proto wireguard|openvpn] [--config /path/to/config]

  --proto       Протокол VPN: wireguard (по умолч.) или openvpn
  --config      Путь к конфигурационному файлу
  --help        Эта справка

Примеры:
  $(basename "$0")
  $(basename "$0") --proto wireguard --config /etc/wireguard/wg0.conf
  $(basename "$0") --proto openvpn --config /etc/openvpn/client.conf
EOF
}

find_wg_config() {
  # Ищем конфиг WireGuard
  for f in /etc/wireguard/*.conf "$VPN_CONFIG_DIR/wireguard"/*.conf; do
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

find_ovpn_config() {
  for f in /etc/openvpn/*.conf /etc/openvpn/client/*.conf "$VPN_CONFIG_DIR/openvpn"/*.ovpn; do
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

wg_up() {
  local config="$1"
  local interface
  interface="$(basename "$config" .conf)"

  if command -v wg-quick >/dev/null 2>&1; then
    echo "Поднимаю WireGuard: $interface ($config)"
    wg-quick up "$config" 2>&1
    return $?
  elif command -v wg >/dev/null 2>&1; then
    echo "wg-quick не найден, пробую ip link + wg set..."
    # Ручной подъём WireGuard
    if ip link show "$interface" >/dev/null 2>&1; then
      echo "Интерфейс $interface уже существует"
      return 0
    fi
    # Парсим конфиг и поднимаем вручную
    local private_key address endpoint public_key
    private_key="$(grep 'PrivateKey' "$config" | awk '{print $3}')"
    address="$(grep 'Address' "$config" | awk '{print $3}')"
    endpoint="$(grep 'Endpoint' "$config" | awk '{print $3}')"
    public_key="$(grep 'PublicKey' "$config" | awk '{print $3}')"

    if [[ -z "$private_key" || -z "$address" ]]; then
      echo "Ошибка: не удалось распарсить $config" >&2
      return 1
    fi

    ip link add "$interface" type wireguard
    wg set "$interface" private-key <(echo "$private_key") peer "$public_key" endpoint "$endpoint" allowed-ips 0.0.0.0/0
    ip addr add "$address" dev "$interface"
    ip link set "$interface" up
    ip route add default dev "$interface" metric 100
    return 0
  else
    echo "WireGuard не установлен" >&2
    return 127
  fi
}

ovpn_up() {
  local config="$1"

  if ! command -v openvpn >/dev/null 2>&1; then
    echo "OpenVPN не установлен" >&2
    return 127
  fi

  # Проверяем, не запущен ли уже
  if pgrep -f "openvpn.*$config" >/dev/null 2>&1; then
    echo "OpenVPN уже запущен с конфигом $config"
    return 0
  fi

  echo "Запускаю OpenVPN: $config"
  openvpn --config "$config" --daemon --log /var/log/openvpn-firewall.log 2>&1
  local ec=$?
  if [[ "$ec" -eq 0 ]]; then
    echo "OpenVPN запущен. PID: $(pgrep -f "openvpn.*$config" | head -1)"
  fi
  return $ec
}

main() {
  local proto="$VPN_PROTO"
  local config=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proto) proto="$2"; shift ;;
      --config) config="$2"; shift ;;
      --help) usage; exit 0 ;;
      *) config="$1" ;;
    esac
    shift
  done

  case "$proto" in
    wireguard|wg)
      [[ -z "$config" ]] && config="$(find_wg_config)" || true
      if [[ -z "$config" ]]; then
        echo "WireGuard конфиг не найден. Создай /etc/wireguard/*.conf или $VPN_CONFIG_DIR/wireguard/" >&2
        exit 1
      fi
      wg_up "$config"
      ;;
    openvpn|ovpn)
      [[ -z "$config" ]] && config="$(find_ovpn_config)" || true
      if [[ -z "$config" ]]; then
        echo "OpenVPN конфиг не найден. Создай /etc/openvpn/*.conf" >&2
        exit 1
      fi
      ovpn_up "$config"
      ;;
    *)
      echo "Неизвестный протокол: $proto" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"