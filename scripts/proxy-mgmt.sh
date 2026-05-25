#!/usr/bin/env bash
# Proxy management module for bash TUI
# Depends on: proxy-parse.py (Python), lib.sh (bash), dialog (TUI)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

PROXY_HELPER="$ROOT/scripts/proxy-parse.py"
CONFIGS_FILE="$ROOT/v2ray_tui/configs.json"
SUBS_FILE="$ROOT/v2ray_tui/subscriptions.json"
CONFIG_COLUMNS=("Name" "Type" "Server" "Port" "Status")

# ─── Helpers ──────────────────────────────────────────────────────────────────
ensure_py_helper() {
  if [ ! -f "$PROXY_HELPER" ]; then
    log_error "Python helper not found: $PROXY_HELPER"
    return 1
  fi
}

proxy_json() {
  python3 "$PROXY_HELPER" "$@"
}

# load_configs — загрузить список прокси из configs.json
load_configs() {
  python3 "$PROXY_HELPER" load-configs 2>/dev/null || echo "[]"
}

# save_config_json — сохранить JSON в configs.json (через stdin)
save_config_json() {
  python3 "$PROXY_HELPER" save-config
}

# count_configs — количество прокси в списке
count_configs() {
  load_configs | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0"
}

# get_active_proxy — получить активную прокси (или первую, если активных нет)
get_active_proxy() {
  load_configs | python3 -c "
import json,sys
cfgs = json.load(sys.stdin)
active = [c for c in cfgs if c.get('active')]
if active:
  c = active[0]
  print(f\"{c.get('remark','?')} ({c.get('server','?')}:{c.get('port','?'))}\")
else:
  print('(none active)')
"
}

# get_proxy_status — общее состояние
get_proxy_status() {
  local count=$(count_configs)
  local mihomo_status=$(python3 -c "
import subprocess
try:
  r = subprocess.run(['systemctl','is-active','mihomo.service'], capture_output=True, text=True)
  print('✓ active' if 'active' in r.stdout else '✗ inactive')
except:
  print('✗ not found')
" 2>/dev/null || echo "?")
  
  local sys_proxy=$(python3 -c "
import platform, subprocess
sys = platform.system().lower()
try:
  if sys == 'linux':
    r = subprocess.run(['gsettings','get','org.gnome.system.proxy','mode'], capture_output=True, text=True)
    print('✓ enabled' if 'manual' in r.stdout else '✗ disabled')
  elif sys == 'windows':
    r = subprocess.run(['reg','query','HKCU\\\\Software\\\\Microsoft\\\\Windows\\\\CurrentVersion\\\\Internet Settings','/v','ProxyEnable'], capture_output=True, text=True)
    print('✓ enabled' if '0x1' in r.stdout else '✗ disabled')
  else:
    print('?')
except:
  print('?')
" 2>/dev/null || echo "?")
  
  local active=$(get_active_proxy)
  
  echo "Mihomo: $mihomo_status | Proxies: $count | Active: $active | System: $sys_proxy"
}

# ─── CRUD Operations ──────────────────────────────────────────────────────────

# add_proxy_from_uri <uri> — добавить прокси из URI
add_proxy_from_uri() {
  local uri="$1"
  ensure_py_helper || return 1
  local json=$(proxy_json parse "$uri")
  
  if echo "$json" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
    # Tag as active if first proxy
    local count=$(count_configs)
    if [ "$count" = "0" ]; then
      echo "$json" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d['active']=True
print(json.dumps(d))
" | save_config_json
    else
      echo "$json" | save_config_json
    fi
    log "proxy added from URI: $(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('remark','unknown'))")"
    return 0
  else
    log_error "Failed to parse URI: $(echo "$json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error','unknown'))")"
    return 1
  fi
}

# delete_proxy <index> — удалить прокси по индексу
delete_proxy() {
  local idx="$1"
  ensure_py_helper || return 1
  
  local configs=$(load_configs)
  local name=$(echo "$configs" | python3 -c "
import json,sys
cfgs=json.load(sys.stdin)
i=int($idx)
print(cfgs[i].get('remark','Proxy '+str(i+1)) if 0<=i<len(cfgs) else '?')
")
  
  echo "$configs" | python3 -c "
import json,sys
cfgs=json.load(sys.stdin)
i=int($idx)
if 0 <= i < len(cfgs):
    cfgs.pop(i)
print(json.dumps(cfgs))
" | save_config_json
  
  log "proxy deleted: $name (index $idx)"
  echo "$name"
}

# toggle_proxy <index> — переключить активность прокси
toggle_proxy() {
  local idx="$1"
  ensure_py_helper || return 1
  
  local configs=$(load_configs)
  local name=$(echo "$configs" | python3 -c "
import json,sys
cfgs=json.load(sys.stdin)
i=int($idx)
if 0<=i<len(cfgs):
  print(cfgs[i].get('remark','Proxy '+str(i+1)))
else:
  print('?')
")
  
  echo "$configs" | python3 -c "
import json,sys
cfgs=json.load(sys.stdin)
i=int($idx)
if 0 <= i < len(cfgs):
    # Toggle this one, deactivate all others
    cfgs[i]['active'] = not cfgs[i].get('active', False)
    for j in range(len(cfgs)):
        if j != i:
            cfgs[j]['active'] = False
print(json.dumps(cfgs))
" | save_config_json
  
  log "proxy toggled: $name (index $idx)"
  echo "$name"
}

# ─── Subscription Management ──────────────────────────────────────────────────

# load_subs — загрузить список подписок
load_subs() {
  if [ -f "$SUBS_FILE" ]; then
    cat "$SUBS_FILE"
  else
    echo "[]"
  fi
}

# save_subs <json> — сохранить список подписок
save_subs() {
  echo "$1" > "$SUBS_FILE"
  log "subscriptions saved"
}

# add_sub <name> <url>
add_sub() {
  local name="$1" url="$2"
  local subs=$(load_subs)
  echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
subs.append({'name': '$name', 'url': '$url', 'enabled': True, 'last_updated': None})
print(json.dumps(subs, indent=2, ensure_ascii=False))
" > "$SUBS_FILE"
  log "subscription added: $name"
}

# remove_sub <index>
remove_sub() {
  local idx="$1"
  local subs=$(load_subs)
  local name=$(echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
i=int($idx)
print(subs[i].get('name','?') if 0<=i<len(subs) else '?')
")
  echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
i=int($idx)
if 0 <= i < len(subs):
    subs.pop(i)
print(json.dumps(subs, indent=2, ensure_ascii=False))
" > "$SUBS_FILE"
  log "subscription removed: $name"
  echo "$name"
}

# toggle_sub <index>
toggle_sub() {
  local idx="$1"
  local subs=$(load_subs)
  echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
i=int($idx)
if 0 <= i < len(subs):
    subs[i]['enabled'] = not subs[i].get('enabled', True)
print(json.dumps(subs, indent=2, ensure_ascii=False))
" > "$SUBS_FILE"
}

# fetch_sub <url> — скачать и сохранить прокси из подписки
fetch_sub() {
  local url="$1"
  ensure_py_helper || return 1
  
  local result=$(proxy_json fetch-subscription "$url")
  if echo "$result" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'error' not in d else 1)" 2>/dev/null; then
    local imported=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('imported',0))")
    log "subscription fetched: $imported proxies imported from $url"
    return 0
  else
    local err=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error','unknown'))")
    log_error "Failed to fetch subscription: $err"
    return 1
  fi
}

# update_sub <index> — обновить определённую подписку
update_sub() {
  local idx="$1"
  local subs=$(load_subs)
  local url=$(echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
i=int($idx)
print(subs[i].get('url','')) if 0<=i<len(subs) else print('')
")
  if [ -n "$url" ]; then
    fetch_sub "$url"
  else
    log_error "Invalid subscription index"
    return 1
  fi
}

# update_all_subs — обновить все подписки
update_all_subs() {
  local subs=$(load_subs)
  local urls=$(echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
for s in subs:
    if s.get('enabled', True):
        print(s['url'])
")
  local success=0 fail=0
  while IFS= read -r url; do
    [ -z "$url" ] && continue
    if fetch_sub "$url"; then
      success=$((success+1))
    else
      fail=$((fail+1))
    fi
  done <<< "$urls"
  echo "Updated: $success OK, $fail failed"
  log "subscription update all: $success OK, $fail failed"
}

# update_system_proxy <enable|disable> — toggle system proxy (OS specific)
update_system_proxy() {
  local action="$1"
  local server="${2:-127.0.0.1}"
  local port="${3:-7890}"
  
  case "$(uname -s)" in
    Linux)
      if command -v gsettings &>/dev/null; then
        if [ "$action" = "enable" ]; then
          gsettings set org.gnome.system.proxy mode manual
          gsettings set org.gnome.system.proxy.http host "$server"
          gsettings set org.gnome.system.proxy.http port "$port"
          gsettings set org.gnome.system.proxy.https host "$server"
          gsettings set org.gnome.system.proxy.https port "$port"
        else
          gsettings set org.gnome.system.proxy mode none
        fi
        return 0
      elif [ -f /etc/environment ]; then
        if [ "$action" = "enable" ]; then
          echo "http_proxy=http://$server:$port" >> /etc/environment 2>/dev/null || true
          echo "https_proxy=http://$server:$port" >> /etc/environment 2>/dev/null || true
        else
          sed -i '/http_proxy/d; /https_proxy/d' /etc/environment 2>/dev/null || true
        fi
        return 0
      fi
      return 0  # Silently succeed if no proxy management available
      ;;
    Darwin)
      # macOS — use networksetup
      local svc="Wi-Fi"
      if [ "$action" = "enable" ]; then
        networksetup -setwebproxy "$svc" "$server" "$port" 2>/dev/null || true
        networksetup -setwebproxystate "$svc" on 2>/dev/null || true
      else
        networksetup -setwebproxystate "$svc" off 2>/dev/null || true
      fi
      return 0
      ;;
    MINGW*|CYGWIN*|MSYS*)
      if [ "$action" = "enable" ]; then
        reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 1 /f 2>/dev/null || true
        reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyServer /t REG_SZ /d "$server:$port" /f 2>/dev/null || true
      else
        reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable /t REG_DWORD /d 0 /f 2>/dev/null || true
      fi
      return 0
      ;;
  esac
}

# system_proxy_status — получить статус системного прокси
system_proxy_status() {
  case "$(uname -s)" in
    Linux)
      if command -v gsettings &>/dev/null; then
        local mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null)
        if [[ "$mode" == *"manual"* ]]; then
          echo "enabled"
        else
          echo "disabled"
        fi
      else
        if grep -q "http_proxy" /etc/environment 2>/dev/null; then
          echo "enabled"
        else
          echo "disabled (no gsettings)"
        fi
      fi
      ;;
    Darwin)
      local svc="Wi-Fi"
      networksetup -getwebproxy "$svc" 2>/dev/null | grep -q "Enabled: Yes" && echo "enabled" || echo "disabled"
      ;;
    MINGW*|CYGWIN*|MSYS*)
      reg query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings" /v ProxyEnable 2>/dev/null | grep -q "0x1" && echo "enabled" || echo "disabled"
      ;;
    *) echo "unknown" ;;
  esac
}

# update_geodata — обновить geoip и geosite
update_geodata() {
  log_step "🌍" "Updating geo databases..."
  bash "$ROOT/scripts/sync-geodat.sh" && {
    echo "✓ Geo databases updated"
    log "geo update OK"
    return 0
  } || {
    echo "✗ Geo update failed (check logs)"
    return 1
  }
}

# restart_mihomo — перезапустить mihomo
restart_mihomo() {
  log_step "🔄" "Restarting mihomo..."
  bash "$ROOT/scripts/svc-restart-mihomo.sh" 2>/dev/null || {
    systemctl restart mihomo.service 2>/dev/null && echo "✓ Mihomo restarted" || {
      echo "✗ Failed to restart mihomo"
      return 1
    }
  }
}

# mihomo_status — статус mihomo
mihomo_status() {
  systemctl is-active mihomo.service 2>/dev/null || echo "inactive"
}

# get_mihomo_logs <lines> — последние строки лога mihomo
get_mihomo_logs() {
  local lines="${1:-50}"
  journalctl -u mihomo.service --no-pager -n "$lines" 2>/dev/null || {
    echo "No mihomo logs available"
  }
}

# ─── Main ────────────────────────────────────────────────────────────────────
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  cmd="${1:-status}"
  shift 2>/dev/null || true
  
  case "$cmd" in
    add) add_proxy_from_uri "$@" ;;
    delete) delete_proxy "$@" ;;
    toggle) toggle_proxy "$@" ;;
    list) load_configs | python3 -m json.tool ;;
    count) count_configs ;;
    status) get_proxy_status ;;
    
    sub-add) add_sub "$@" ;;
    sub-remove) remove_sub "$@" ;;
    sub-toggle) toggle_sub "$@" ;;
    sub-fetch) fetch_sub "$@" ;;
    sub-update) update_sub "$@" ;;
    sub-update-all) update_all_subs ;;
    sub-list) load_subs | python3 -m json.tool ;;
    
    geo-update) update_geodata ;;
    mihomo-restart) restart_mihomo ;;
    mihomo-status) mihomo_status ;;
    mihomo-logs) get_mihomo_logs "${1:-50}" ;;
    
    sysproxy-on) update_system_proxy enable "${2:-127.0.0.1}" "${3:-7890}" ;;
    sysproxy-off) update_system_proxy disable ;;
    sysproxy-status) system_proxy_status ;;
    
    *) echo "Usage: proxy-mgmt.sh <command> [args...]"
       echo "Commands: add, delete, toggle, list, count, status"
       echo "          sub-add, sub-remove, sub-toggle, sub-fetch, sub-update, sub-update-all, sub-list"
       echo "          geo-update, mihomo-restart, mihomo-status, mihomo-logs"
       echo "          sysproxy-on, sysproxy-off, sysproxy-status" ;;
  esac
fi