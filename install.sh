#!/bin/sh
set -eu

fatal(){ printf '%s\n' "$1" >&2; exit 1; }
show_help(){
 printf '%s\n' "sudo ./install.sh [-r|--root|--firewall-root DIR] [-h|--help]" "-r DIR install/copy target (default FIREWALL_ROOT=/opt/firewall)" "Unset SUBSCRIPTION_URL in env triggers interactive prompt (stdin or /dev/tty)." >&2
 exit 0
}

CDPATH=: FW_ROOT=""
FW_ROOT="$(cd "$(dirname "$0")" && pwd)" || fatal "cd script"
FW_ROOT="${FW_ROOT%/}"

SU="${SUBSCRIPTION_URL:-}"
FR="${FIREWALL_ROOT:-/opt/firewall}"

while [ "$#" -gt 0 ]; do
 case "$1" in
 -r|--root|--firewall-root)
   [ -n "${2:-}" ] || fatal "missing path after $1"
   FR="$2"
   shift 2
   ;;
 -h|--help)
   show_help
   ;;
 --)
   shift
   break
   ;;
 -*)
   fatal "unknown option: $1"
   ;;
 *)
   fatal "unexpected argument: $1"
   ;;
 esac
done

FR="${FR%/}"
export FIREWALL_ROOT="$FR"

if [ -z "$SU" ]; then
 printf '%s' "SUBSCRIPTION_URL (https://...): " >&2
 if [ -t 0 ]; then
   read -r SUBSCRIPTION_URL || SUBSCRIPTION_URL=
 else
   read -r SUBSCRIPTION_URL < /dev/tty || SUBSCRIPTION_URL=
 fi
else
 SUBSCRIPTION_URL="$SU"
fi

export SUBSCRIPTION_URL FW_ROOT SCRIPT_DIR FIREWALL_ROOT
SCRIPT_DIR="$FW_ROOT"

# === ЛОГИРОВАНИЕ ===
LOG_FILE="/tmp/firewall-install.log"
exec 2>"$LOG_FILE"
exec 1>"$LOG_FILE"

# Дублируем вывод в терминал тоже
exec 3>&1
log() {
    echo "$@" >&3
    echo "$@"
}

log "========================================"
log "  Firewall Installer"
log "  Дата: $(date)"
log "  Архитектура: $(uname -m)"
log "  FW_ROOT: $FW_ROOT"
log "  FIREWALL_ROOT: $FR"
log "========================================"
log ""

# === АВТОУСТАНОВКА ЗАВИСИМОСТЕЙ ===
log "[*] Установка пакетов..."
apt-get update
apt-get install -y curl git dialog wget tar gzip xz-utils coreutils \
  ca-certificates python3 nftables iptables nginx apache2-utils \
  libnfnetlink-dev libnetfilter-queue-dev libcap-dev \
  build-essential autoconf automake libtool pkg-config jq 2>/dev/null || {
    log "[!] Некоторые пакеты не установились, продолжаем..."
  }

# === УСТАНОВКА SHELL2HTTP ===
install_shell2http() {
  if command -v shell2http >/dev/null 2>&1; then
    log "[*] shell2http уже установлен: $(which shell2http)"
    return 0
  fi
  log "[*] Установка shell2http..."
  local arch="$(uname -m)"
  local suffix=""
  case "$arch" in
    x86_64) suffix="amd64" ;;
    aarch64|arm64) suffix="arm64" ;;
    armv7l) suffix="arm" ;;
    *) suffix="amd64" ;;
  esac
  local url="https://github.com/msoap/shell2http/releases/latest/download/shell2http-linux-${suffix}.tar.gz"
  log "  → Скачивание: $url"
  if curl -fsSL "$url" | tar -xzf - -C /usr/local/bin/ shell2http 2>/dev/null; then
    chmod +x /usr/local/bin/shell2http
    log "  ✓ shell2http установлен"
  else
    log "  [!] Не удалось скачать shell2http"
    if command -v go >/dev/null 2>&1; then
      log "  → Пробуем через go install..."
      go install github.com/msoap/shell2http@latest 2>/dev/null || log "  [!] go install тоже не сработал"
    fi
  fi
}

# === УСТАНОВКА MIHOMO ===
install_mihomo() {
  if command -v mihomo >/dev/null 2>&1 || [ -f /usr/local/bin/mihomo ]; then
    log "[*] Mihomo уже установлен"
    return 0
  fi
  if [ "${SKIP_BINARIES:-}" = "1" ]; then
    log "[*] SKIP_BINARIES=1, пропускаем Mihomo"
    return 0
  fi
  log "[*] Установка Mihomo..."
  local arch="$(uname -m)"
  local suffix=""
  case "$arch" in
    x86_64) suffix="amd64" ;;
    aarch64|arm64) suffix="arm64" ;;
    armv7l) suffix="armv7" ;;
    *) suffix="amd64" ;;
  esac
  local url="https://github.com/MetaCubeX/mihomo/releases/latest/download/mihomo-linux-${suffix}-compatible.gz"
  log "  → Скачивание: $url"
  if curl -fsSL "$url" | gzip -d > /usr/local/bin/mihomo 2>/dev/null; then
    chmod +x /usr/local/bin/mihomo
    log "  ✓ Mihomo установлен"
  else
    log "  [!] Не удалось скачать Mihomo"
  fi
}

# === УСТАНОВКА ZAPRET ===
install_zapret() {
  if [ -d /opt/zapret ] || [ -f /usr/local/bin/nfqws ] || [ -f /usr/local/bin/tpws ]; then
    log "[*] Zapret уже установлен"
    return 0
  fi
  log "[*] Установка zapret (bol-van)..."

  # Определяем архитектуру zapret
  local arch="$(uname -m)"
  local zapret_arch=""
  case "$arch" in
    x86_64) zapret_arch="linux-x86_64" ;;
    i386|i686) zapret_arch="linux-x86" ;;
    aarch64|arm64) zapret_arch="linux-arm64" ;;
    armv7l|armv6l) zapret_arch="linux-arm" ;;
    mips) zapret_arch="linux-mips" ;;
    mipsel) zapret_arch="linux-mipsel" ;;
    mips64) zapret_arch="linux-mips64" ;;
    ppc|ppc64) zapret_arch="linux-ppc" ;;
    *) zapret_arch="" ;;
  esac

  log "  → Архитектура системы: $arch"
  log "  → Архитектура zapret: $zapret_arch"

  # Удаляем старую установку
  rm -rf /opt/zapret /tmp/zapret-download

  # Скачиваем release
  local release_url=""
  local release_tag=""

  if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    log "  → Получаем информацию о release..."
    release_tag=$(curl -fsSL "https://api.github.com/repos/bol-van/zapret/releases/latest" 2>/dev/null | jq -r '.tag_name')
    release_url=$(curl -fsSL "https://api.github.com/repos/bol-van/zapret/releases/latest" 2>/dev/null | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -1)
    log "  → Последний release: $release_tag"
  fi

  # Fallback на прямую ссылку
  if [ -z "$release_url" ] && [ -n "$release_tag" ]; then
    release_url="https://github.com/bol-van/zapret/releases/download/${release_tag}/zapret-${release_tag}.tar.gz"
  fi

  # Пробуем известные версии
  if [ -z "$release_url" ]; then
    log "  → Пробуем известные версии..."
    for ver in "v71.4" "v71.3" "v71.2" "v71.1" "v71.0" "v70.5" "v70.4" "v70.3"; do
      local test_url="https://github.com/bol-van/zapret/releases/download/${ver}/zapret-${ver}.tar.gz"
      if curl -fsSL -I "$test_url" >/dev/null 2>&1; then
        release_url="$test_url"
        release_tag="$ver"
        log "  → Найдена версия: $ver"
        break
      fi
    done
  fi

  if [ -z "$release_url" ]; then
    log "[!] Не удалось найти release zapret"
    log "    Установите вручную:"
    log "    cd /tmp && git clone --depth=1 https://github.com/bol-van/zapret.git"
    log "    cd zapret && ./install_easy.sh"
    return 1
  fi

  log "  → Скачивание: $release_url"
  mkdir -p /tmp/zapret-download
  if ! curl -fsSL -L "$release_url" -o /tmp/zapret-download/zapret.tar.gz 2>/dev/null; then
    log "[!] Ошибка скачивания zapret"
    return 1
  fi

  log "  → Распаковка..."
  tar -xzf /tmp/zapret-download/zapret.tar.gz -C /tmp/zapret-download/ 2>/dev/null || {
    log "[!] Ошибка распаковки"
    return 1
  }

  local extracted=""
  for dir in /tmp/zapret-download/zapret*; do
    if [ -d "$dir" ] && [ "$dir" != "/tmp/zapret-download" ]; then
      extracted="$dir"
      break
    fi
  done

  if [ -z "$extracted" ]; then
    log "[!] Директория zapret не найдена после распаковки"
    return 1
  fi

  mv "$extracted" /opt/zapret
  log "  ✓ Zapret распакован в /opt/zapret"

  cd /opt/zapret

  # Устанавливаем бинарники через install_bin.sh
  log "[*] Установка бинарников..."
  chmod +x install_bin.sh 2>/dev/null || true

  if ./install_bin.sh 2>/tmp/zapret-bin.log; then
    log "  ✓ Бинарники установлены через install_bin.sh"
  else
    log "  [!] install_bin.sh не сработал, пробуем вручную..."
    if [ -d "binaries/${zapret_arch}" ]; then
      log "  → Копируем бинарники из binaries/${zapret_arch}/"
      for bin in nfqws tpws mdig ip2net; do
        if [ -f "binaries/${zapret_arch}/${bin}" ]; then
          cp "binaries/${zapret_arch}/${bin}" ./${bin} 2>/dev/null || true
          chmod +x ./${bin} 2>/dev/null || true
          log "    ✓ ${bin}"
        fi
      done
    else
      log "  [!] Папка binaries/${zapret_arch} не найдена"
      log "  → Доступные архитектуры: $(ls binaries/ 2>/dev/null | grep '^linux-' | tr '\n' ' ')"
    fi
  fi

  # Запуск install_easy.sh с авто-ответами
  log "[*] Настройка через install_easy.sh..."
  chmod +x install_easy.sh

  # Авто-ответы для Raspberry Pi / nftables / nfqws
  {
    echo "2"      # nftables
    echo "n"      # ipv6
    echo "1"      # flow offload = none
    echo "n"      # tpws socks
    echo "n"      # tpws transparent
    echo "Y"      # nfqws
    echo "1"      # LAN = none
    echo "1"      # WAN = any
    echo "1"      # filter = none
  } | ./install_easy.sh >/tmp/zapret-install.log 2>&1

  local status=$?
  log "  → install_easy.sh завершился с кодом: $status"

  # Запускаем сервис в любом случае если есть конфиг
  if [ -f /opt/zapret/config ] || [ -f /etc/systemd/system/zapret.service ] || [ -f /opt/zapret/init.d/systemd/zapret.service ]; then
    log "[*] Активация сервиса zapret..."
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable zapret.service 2>/dev/null || true
    systemctl start zapret.service 2>/dev/null || true

    if systemctl is-active zapret.service >/dev/null 2>&1; then
      log "  ✓ Zapret запущен и активен"
    else
      log "  [!] Zapret установлен, но сервис не запустился"
      log "      Попробуйте вручную: sudo systemctl start zapret"
    fi
  fi

  if [ $status -eq 0 ] || [ -f /opt/zapret/config ]; then
    log "[*] Zapret установлен в /opt/zapret"
    log "[*] Конфиг: /opt/zapret/config"
  else
    log "[!] install_easy.sh завершился с кодом $status"
    log "    Лог: /tmp/zapret-install.log"
  fi

  cd - >/dev/null
  rm -rf /tmp/zapret-download
}

# === УСТАНОВКА ГЕОДАТЫ ===
install_geodata() {
  log "[*] Установка geodata..."
  local geodir="${FR}/state/geodata"
  mkdir -p "$geodir"
  local base="https://raw.githubusercontent.com/runetfreedom/russia-v2ray-rules-dat/release"

  curl -fsSL "${base}/geosite.dat" -o "${geodir}/geosite.dat" 2>/dev/null || log "  [!] geosite.dat не скачался"
  curl -fsSL "${base}/geoip.dat" -o "${geodir}/geoip.dat" 2>/dev/null || log "  [!] geoip.dat не скачался"
  curl -fsSL "${base}/geosite.dat.sha256sum" -o "${geodir}/geosite.dat.sha256sum" 2>/dev/null || true
  curl -fsSL "${base}/geoip.dat.sha256sum" -o "${geodir}/geoip.dat.sha256sum" 2>/dev/null || true

  date +%Y%m%d%H%M > "${geodir}/.version" 2>/dev/null || true
  log "[*] Geodata установлена"
}

# === КОПИРОВАНИЕ ФАЙЛОВ ПРОЕКТА ===
copy_project() {
  log "[*] Копирование файлов в ${FR}..."
  mkdir -p "${FR}"

  # Копируем всё кроме .git
  for item in "${FW_ROOT}"/*; do
    local name=$(basename "$item")
    [ "$name" = ".git" ] && continue
    [ "$name" = "install.sh" ] && continue

    if [ -d "$item" ]; then
      cp -r "$item" "${FR}/" 2>/dev/null || log "  [!] Ошибка копирования $name"
    elif [ -f "$item" ]; then
      cp "$item" "${FR}/" 2>/dev/null || log "  [!] Ошибка копирования $name"
    fi
  done

  # Создаём необходимые директории
  mkdir -p "${FR}/state/generated" "${FR}/state/geodata" "${FR}/catalog/upstream" "${FR}/catalog/user"

  # Сохраняем подписку
  mkdir -p "${FR}/secrets"
  printf '%s' "$SUBSCRIPTION_URL" > "${FR}/secrets/subscription.url"
  chmod 600 "${FR}/secrets/subscription.url" 2>/dev/null || true

  log "[*] Файлы скопированы"
}

# === УСТАНОВКА СКРИПТОВ ===
install_scripts() {
  log "[*] Установка скриптов..."

  # setup-tui.sh
  if [ -f "${FW_ROOT}/scripts/setup-tui.sh" ]; then
    cp "${FW_ROOT}/scripts/setup-tui.sh" "${FR}/scripts/setup-tui.sh"
    chmod +x "${FR}/scripts/setup-tui.sh"
    log "  ✓ setup-tui.sh"
  else
    log "  [!] setup-tui.sh не найден в ${FW_ROOT}/scripts/"
  fi

  # Делаем все скрипты исполняемыми
  for s in "${FR}/scripts/"*.sh; do
    [ -f "$s" ] && chmod +x "$s"
  done

  # firewall CLI
  if [ -f "${FW_ROOT}/firewall" ]; then
    cp "${FW_ROOT}/firewall" /usr/local/bin/firewall
    chmod +x /usr/local/bin/firewall
    log "  ✓ firewall CLI → /usr/local/bin/firewall"
  else
    log "  [!] firewall CLI не найден в ${FW_ROOT}/firewall"
  fi
}

# === SYSTEMD СЕРВИСЫ ===
install_systemd() {
  if [ "${SKIP_SYSTEMD:-}" = "1" ]; then
    log "[*] SKIP_SYSTEMD=1, пропускаем"
    return 0
  fi
  log "[*] Настройка systemd..."

  # Mihomo service
  cat > /etc/systemd/system/mihomo.service <<'EOF'
[Unit]
Description=Mihomo proxy client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mihomo -f /opt/firewall/state/mihomo-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  log "  ✓ mihomo.service"

  # shell2http service
  cat > /etc/systemd/system/firewall-shell2http.service <<'EOF'
[Unit]
Description=Firewall dashboard API
After=network-online.target nginx.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/firewall
ExecStart=/usr/local/bin/shell2http -port 8899 -basic-auth \
  /dashboard/api/full-refresh "bash /opt/firewall/scripts/full-refresh.sh" \
  /dashboard/api/subscription-refresh "bash /opt/firewall/scripts/update-subscription.sh" \
  /dashboard/api/sync-build "bash /opt/firewall/scripts/sync-build.sh" \
  /dashboard/api/zapret-restart "bash /opt/firewall/scripts/svc-restart-zapret.sh" \
  /dashboard/api/mihomo-restart "bash /opt/firewall/scripts/svc-restart-mihomo.sh" \
  /dashboard/api/bypass-off "bash /opt/firewall/scripts/bypass-off.sh" \
  /dashboard/api/bypass-on "bash /opt/firewall/scripts/bypass-on.sh" \
  /dashboard/api/low-power-on "bash /opt/firewall/scripts/low-power-toggle.sh yes" \
  /dashboard/api/low-power-off "bash /opt/firewall/scripts/low-power-toggle.sh no"
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
  log "  ✓ firewall-shell2http.service"

  # Zapret service (если есть)
  if [ -f /opt/zapret/init.d/systemd/zapret.service ]; then
    cp /opt/zapret/init.d/systemd/zapret.service /etc/systemd/system/zapret.service 2>/dev/null || true
    log "  ✓ zapret.service (из zapret)"
  else
    cat > /etc/systemd/system/zapret.service <<'EOF'
[Unit]
Description=Zapret DPI bypass (nfqws)
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/opt/zapret/nfqws --uid=0:0 --qnum=200 \
  --hostlist=/opt/firewall/state/generated/zapret-hostlist.txt \
  --hostlist-exclude=/opt/firewall/state/generated/zapret-hostlist-exclude.txt \
  --dpi-desync=split2 --dpi-desync-fooling=badsum --dpi-desync-repeats=6
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    log "  ✓ zapret.service (создан вручную)"
  fi

  systemctl daemon-reload 2>/dev/null || true
  systemctl enable mihomo.service firewall-shell2http.service zapret.service 2>/dev/null || {
    log "  [!] Не удалось включить все сервисы"
  }
  log "  ✓ Сервисы настроены"
}

# === ПЕРВИЧНАЯ СИНХРОНИЗАЦИЯ ===
first_sync() {
  if [ "${SKIP_SYNC:-}" = "1" ]; then
    log "[*] SKIP_SYNC=1, пропускаем первый sync"
    return 0
  fi
  log "[*] Первичная синхронизация..."
  cd "${FR}"

  if [ -f "${FR}/scripts/sync-zapret-lists-upstream.sh" ]; then
    bash "${FR}/scripts/sync-zapret-lists-upstream.sh" 2>/dev/null || log "  [!] Ошибка sync-zapret-lists"
  fi

  if [ -f "${FR}/scripts/build-lists.sh" ]; then
    bash "${FR}/scripts/build-lists.sh" 2>/dev/null || log "  [!] Ошибка build-lists"
  fi

  if [ -f "${FR}/scripts/gen-mihomo-config.sh" ]; then
    export FIREWALL_VPN_ROUTE="${VPN_MODE:-split}"
    bash "${FR}/scripts/gen-mihomo-config.sh" 2>/dev/null || log "  [!] Ошибка gen-mihomo-config"
  fi

  log "[*] Синхронизация завершена"
}

# === ЗАПУСК ===
log ""
log "========================================"
log "  Начало установки"
log "========================================"
log ""

install_shell2http
install_mihomo
install_zapret
install_geodata
copy_project
install_scripts
install_systemd
first_sync

log ""
log "========================================"
log "  Установка завершена!"
log "========================================"
log ""
log "Директория:    ${FR}"
log "Подписка:      ${SUBSCRIPTION_URL}"
log ""
log "Установленные компоненты:"
log "  Mihomo:      $(command -v mihomo 2>/dev/null || echo 'не найден')"
log "  shell2http:  $(command -v shell2http 2>/dev/null || echo 'не найден')"
log "  Zapret:      $(test -d /opt/zapret && echo '/opt/zapret' || echo 'не найден')"
log "  Geodata:     ${FR}/state/geodata"
log ""
log "CLI управление:"
log "  sudo firewall start       — запустить все сервисы"
log "  sudo firewall stop        — остановить все сервисы"
log "  sudo firewall restart     — перезапустить все сервисы"
log "  sudo firewall status      — показать статус"
log "  sudo firewall settings    — интерактивная настройка (TUI)"
log "  sudo firewall update      — обновить списки и geodata"
log "  sudo firewall logs        — показать логи"
log "  sudo firewall help        — справка"
log ""
log "TUI настройка:"
log "  sudo bash ${FR}/scripts/setup-tui.sh"
log ""
log "Панель: http://<IP>:8088/dashboard/"
log ""
log "Логи установки:"
log "  Общий:   ${LOG_FILE}"
log "  Zapret:  /tmp/zapret-install.log"
log ""
