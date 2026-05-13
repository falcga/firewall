#!/usr/bin/env bash
# Статус VPN-соединения (WireGuard, OpenVPN)
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
Использование: $(basename "$0") [--proto wireguard|openvpn] [--json]

  --proto    Протокол VPN (wireguard по умолч.)
  --json     Вывод в JSON для парсинга
  --help     Эта справка
EOF
}

wg_status() {
  local json="${1:-0}"

  if ! command -v wg >/dev/null 2>&1 && ! command -v wg-quick >/dev/null 2>&1; then
    if [[ "$json" == "1" ]]; then
      echo '{"protocol":"wireguard","installed":false,"active":false,"interfaces":[]}'
    else
      echo "WireGuard: не установлен"
    fi
    return
  fi

  local interfaces
  interfaces="$(wg show interfaces 2>/dev/null || echo '')"

  if [[ "$json" == "1" ]]; then
    local json_interfaces="[]"
    local first=true
    if [[ -n "$interfaces" ]]; then
      for iface in $interfaces; do
        local status
        status="$(wg show "$iface" transfer 2>/dev/null | head -1 || echo "")"
        local listen_port
        listen_port="$(wg show "$iface" listen-port 2>/dev/null || echo "0")"
        local peers
        peers="$(wg show "$iface" peers 2>/dev/null || echo "")"
        local peer_count=0
        [[ -n "$peers" ]] && peer_count="$(echo "$peers" | wc -l)"
        local latest_handshake=""
        for peer in $peers; do
          local hs
          hs="$(wg show "$iface" latest-handshakes 2>/dev/null | grep "$peer" | awk '{print $2}' || echo "0")"
          latest_handshake="$hs"
          break
        done

        if $first; then
          json_interfaces="[{\"name\":\"$iface\",\"listen_port\":$listen_port,\"peer_count\":$peer_count,\"latest_handshake\":$latest_handshake}]"
          first=false
        else
          json_interfaces="$(echo "$json_interfaces" | sed "s/\]$/,{\"name\":\"$iface\",\"listen_port\":$listen_port,\"peer_count\":$peer_count,\"latest_handshake\":$latest_handshake}]/")"
        fi
      done
    fi
    echo "{\"protocol\":\"wireguard\",\"installed\":true,\"active\":$([[ -n "$interfaces" ]] && echo true || echo false),\"interfaces\":$json_interfaces}"
  else
    if [[ -n "$interfaces" ]]; then
      echo "WireGuard: АКТИВЕН"
      for iface in $interfaces; do
        echo "  Интерфейс: $iface"
        wg show "$iface" 2>/dev/null | head -n 20
        echo ""
      done
    else
      echo "WireGuard: установлен, но не активен"
    fi
  fi
}

ovpn_status() {
  local json="${1:-0}"

  if ! command -v openvpn >/dev/null 2>&1; then
    if [[ "$json" == "1" ]]; then
      echo '{"protocol":"openvpn","installed":false,"active":false,"pids":[]}'
    else
      echo "OpenVPN: не установлен"
    fi
    return
  fi

  local pids
  pids="$(pgrep -f "openvpn.*--daemon" 2>/dev/null || true)"

  if [[ "$json" == "1" ]]; then
    local pid_list="[]"
    if [[ -n "$pids" ]]; then
      local first=true
      for pid in $pids; do
        local cmdline
        cmdline="$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ' || echo '')"
        local config=""
        config="$(echo "$cmdline" | grep -oP '(?<=--config )[^ ]+' || echo 'unknown')"
        if $first; then
          pid_list="[{\"pid\":$pid,\"config\":\"$config\"}]"
          first=false
        else
          pid_list="$(echo "$pid_list" | sed "s/\]$/,{\"pid\":$pid,\"config\":\"$config\"}]/")"
        fi
      done
    fi
    echo "{\"protocol\":\"openvpn\",\"installed\":true,\"active\":$([[ -n "$pids" ]] && echo true || echo false),\"pids\":$pid_list}"
  else
    if [[ -n "$pids" ]]; then
      echo "OpenVPN: АКТИВЕН (PID: $(echo "$pids" | tr '\n' ' '))"
    else
      echo "OpenVPN: установлен, но не активен"
    fi
  fi
}

main() {
  local proto="$VPN_PROTO"
  local json=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --proto) proto="$2"; shift ;;
      --json) json=1 ;;
      --help) usage; exit 0 ;;
      *) proto="$1" ;;
    esac
    shift
  done

  case "$proto" in
    wireguard|wg) wg_status "$json" ;;
    openvpn|ovpn) ovpn_status "$json" ;;
    all)
      wg_status "$json"
      echo ""
      ovpn_status "$json"
      ;;
    *)
      echo "Неизвестный протокол: $proto" >&2
      usage
      exit 1
      ;;
  esac
}

main "$@"