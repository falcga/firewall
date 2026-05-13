#!/usr/bin/env bash
# ============================================================================
# update-firewall.sh — единое обновление всего firewall из репозитория
# Запуск: sudo bash update-firewall.sh
# Что делает:
#   1. Проверяет наличие обновлений в git (если установлен через clone)
#   2. Если git-репозиторий — стягивает изменения (git pull)
#   3. Если не git — спрашивает URL и клонирует/скачивает
#   4. Синхронизирует файлы в FIREWALL_ROOT
#   5. Перезапускает сервисы (mihomo, shell2http, zapret)
# ============================================================================
set -uo pipefail

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }
header(){ printf "\n${CYAN}=== %s ===${NC}\n" "$1"; }

# Определяем корень
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-setup-tui"
STATE_FILE="$STATE_DIR/state.conf"
FIREWALL_ROOT="${FIREWALL_ROOT:-/opt/firewall}"
SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"

# Загружаем state
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
fi

usage() {
  cat <<EOF
Использование: $(basename "$0") [--root DIR] [--no-pull] [--no-restart] [--no-sync] [--help]

  --root DIR       Целевой каталог установки (по умолч. \$FIREWALL_ROOT или /opt/firewall)
  --no-pull        Не стягивать обновления из git
  --no-restart     Не перезапускать сервисы после обновления
  --no-sync        Не выполнять sync списков/геодаты
  --no-build       Не пересобирать списки
  --no-interactive Не задавать вопросов (batch mode)
  --help           Эта справка

Примеры:
  sudo bash $(basename "$0")
  sudo bash $(basename "$0") --root /opt/firewall
  sudo bash $(basename "$0") --no-pull --no-restart
EOF
}

check_git_update() {
  local repo_dir="$1"
  header "Проверка обновлений git"

  if [[ ! -d "$repo_dir/.git" ]]; then
    warn "Каталог $repo_dir — не git-репозиторий"
    return 1
  fi

  cd "$repo_dir" || return 1

  # Проверяем, есть ли remote
  local remote
  remote="$(git remote -v 2>/dev/null | head -1 || true)"
  if [[ -z "$remote" ]]; then
    warn "Нет git-remote в $repo_dir"
    return 1
  fi

  info "Репозиторий: $remote"

  # Сохраняем текущий HEAD
  local old_head
  old_head="$(git rev-parse HEAD)"

  # Проверяем наличие обновлений
  info "Проверка обновлений..."
  local fetch_output
  fetch_output="$(git fetch 2>&1)" || {
    warn "Не удалось выполнить git fetch: $fetch_output"
    return 1
  }

  local local_rev remote_rev
  local_rev="$(git rev-parse HEAD)"
  remote_rev="$(git rev-parse '@{upstream}' 2>/dev/null || echo "$local_rev")"

  if [[ "$local_rev" == "$remote_rev" ]]; then
    info "Уже актуально (HEAD: ${local_rev:0:8})"
    return 0
  fi

  # Есть изменения — показываем лог
  info "Доступны обновления:"
  git log --oneline "$local_rev..$remote_rev" 2>/dev/null | head -n 20

  echo ""
  info "Стягиваю изменения (git pull)..."
  git pull --ff-only 2>&1 || {
    warn "Не удалось выполнить git pull. Возможно, есть локальные изменения."
    warn "Попробуй: git stash && git pull"
    return 1
  }

  local new_head
  new_head="$(git rev-parse HEAD)"
  if [[ "$old_head" != "$new_head" ]]; then
    info "Обновлено: ${old_head:0:8} → ${new_head:0:8}"
  fi
  return 0
}

sync_files() {
  local src_dir="$1" dst_dir="$2"
  header "Синхронизация файлов в $dst_dir"

  if [[ ! -d "$src_dir" ]]; then
    error "Исходный каталог $src_dir не найден"
    return 1
  fi

  mkdir -p "$dst_dir"

  # Синхронизируем, исключая .git, state, secrets, catalog/upstream (они свои)
  info "Копирование из $src_dir в $dst_dir (исключая .git, state, secrets, catalog/upstream)..."
  rsync -av --delete \
    --exclude='.git/' \
    --exclude='state/' \
    --exclude='secrets/' \
    --exclude='catalog/upstream/' \
    --exclude='.idea/' \
    "$src_dir/" "$dst_dir/" 2>&1 || {
    # fallback на cp если нет rsync
    warn "rsync не найден, использую cp"
    cp -r \
      --parents \
      "$src_dir"/scripts/*.sh \
      "$src_dir"/contrib/* \
      "$src_dir"/deploy/* \
      "$src_dir"/srv/* \
      "$dst_dir/" 2>/dev/null || true
  }

  # Делаем скрипты исполняемыми
  find "$dst_dir/scripts" -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  find "$dst_dir/contrib" -maxdepth 1 -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

  info "Синхронизация завершена"
}

run_sync() {
  local root="$1"
  header "Синхронизация списков и геодаты"

  if [[ ! -d "$root/scripts" ]]; then
    error "Каталог $root/scripts не найден"
    return 1
  fi

  # sync-zapret-lists
  if [[ -f "$root/scripts/sync-zapret-lists-upstream.sh" ]]; then
    info "Загрузка списков Flowseal..."
    bash "$root/scripts/sync-zapret-lists-upstream.sh" 2>&1 || warn "sync-zapret-lists: ошибка $?"
  else
    warn "sync-zapret-lists-upstream.sh не найден"
  fi

  # sync-geodat
  if [[ -f "$root/scripts/sync-geodat.sh" ]]; then
    info "Загрузка геодаты..."
    bash "$root/scripts/sync-geodat.sh" 2>&1 || warn "sync-geodat: ошибка $?"
  else
    warn "sync-geodat.sh не найден"
  fi
}

run_build() {
  local root="$1"
  header "Сборка списков"

  if [[ -f "$root/scripts/build-lists.sh" ]]; then
    info "Сборка hostlist/IP-списков..."
    bash "$root/scripts/build-lists.sh" 2>&1 || warn "build-lists: ошибка $?"
  else
    warn "build-lists.sh не найден"
  fi
}

restart_services() {
  header "Перезапуск сервисов"

  if ! command -v systemctl >/dev/null 2>&1; then
    warn "systemctl не найден — пропускаю перезапуск"
    return
  fi

  # Restart mihomo
  if systemctl cat mihomo.service >/dev/null 2>&1; then
    info "Перезапуск mihomo.service..."
    systemctl restart mihomo.service || warn "mihomo restart: код $?"
  else
    warn "mihomo.service не найден"
  fi

  # Restart shell2http
  if systemctl cat firewall-shell2http.service >/dev/null 2>&1; then
    info "Перезапуск firewall-shell2http.service..."
    systemctl restart firewall-shell2http.service || warn "shell2http restart: код $?"
  else
    warn "firewall-shell2http.service не найден"
  fi

  # Restart zapret
  if [[ -f "$root/scripts/svc-restart-zapret.sh" ]]; then
    info "Перезапуск zapret..."
    bash "$root/scripts/svc-restart-zapret.sh" || warn "zapret restart: код $?"
  fi

  # Restart nginx
  if systemctl cat nginx.service >/dev/null 2>&1; then
    info "Перезапуск nginx.service..."
    systemctl reload nginx 2>/dev/null || systemctl restart nginx || warn "nginx restart: код $?"
  fi

  info "Сервисы перезапущены"
}

install_firewall_command() {
  local root="$1"
  header "Установка команды firewall"

  local script_src="$root/scripts/setup-tui.sh"
  local symlink_target="/usr/local/bin/firewall"

  if [[ ! -f "$script_src" ]]; then
    warn "$script_src не найден — пропускаю"
    return
  fi

  # Создаём обёртку
  cat > /tmp/firewall-wrapper.sh << 'WRAPPER'
#!/usr/bin/env bash
# Обёртка для firewall TUI (установлена update-firewall.sh)
# Запуск: firewall [--help]
set -uo pipefail

# Определяем корень
if [[ -n "${FIREWALL_ROOT:-}" ]]; then
  ROOT="$FIREWALL_ROOT"
elif [[ -f "/opt/firewall/scripts/setup-tui.sh" ]]; then
  ROOT="/opt/firewall"
else
  # Пытаемся найти
  for d in /opt/firewall /home/*/lms/firewall /root/firewall; do
    if [[ -f "$d/scripts/setup-tui.sh" ]]; then
      ROOT="$d"
      break
    fi
  done
fi

if [[ -z "${ROOT:-}" ]]; then
  echo "Ошибка: не найден каталог установки firewall" >&2
  echo "Задайте FIREWALL_ROOT или установите в /opt/firewall" >&2
  exit 1
fi

case "${1:-}" in
  --help|-h)
    cat <<HELP
Использование: firewall [options]

  Без аргументов — запуск TUI (интерактивная настройка)
  --help, -h     Эта справка
  --update       Обновление firewall из репозитория (sudo)
  --status       Статус сервисов
  --version      Версия (последний коммит git)

HELP
    ;;
  --update)
    exec sudo bash "$ROOT/scripts/update-firewall.sh" "${@:2}"
    ;;
  --status)
    systemctl status mihomo.service --no-pager 2>/dev/null || echo "mihomo: не найден"
    systemctl status firewall-shell2http.service --no-pager 2>/dev/null || echo "shell2http: не найден"
    ;;
  --version)
    if [[ -d "$ROOT/.git" ]]; then
      cd "$ROOT" && git log --oneline -1 2>/dev/null || echo "неизвестно"
    else
      echo "неизвестно (не git)"
    fi
    ;;
  *)
    exec sudo bash "$ROOT/scripts/setup-tui.sh"
    ;;
esac
WRAPPER

  sudo install -m 0755 /tmp/firewall-wrapper.sh "$symlink_target" 2>/dev/null || {
    warn "Не удалось установить $symlink_target (нужны права root)"
    rm -f /tmp/firewall-wrapper.sh
    return 1
  }
  rm -f /tmp/firewall-wrapper.sh

  info "Команда 'firewall' установлена в $symlink_target"
  info "Запуск: firewall          — TUI"
  info "        firewall --update — обновление из репозитория"
  info "        firewall --status — статус сервисов"
}

main() {
  local root="$ROOT"
  local do_pull=true
  local do_restart=true
  local do_sync=true
  local do_build=true
  local interactive=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --root) root="$2"; shift ;;
      --no-pull) do_pull=false ;;
      --no-restart) do_restart=false ;;
      --no-sync) do_sync=false ;;
      --no-build) do_build=false ;;
      --no-interactive) interactive=false ;;
      --help) usage; exit 0 ;;
      *) root="$1" ;;
    esac
    shift
  done

  # Если root указан, используем его, иначе FIREWALL_ROOT
  if [[ "$root" == "$ROOT" ]]; then
    root="$FIREWALL_ROOT"
  fi

  echo ""
  echo "${CYAN}======================================${NC}"
  echo "${CYAN}  Firewall Update Script${NC}"
  echo "${CYAN}======================================${NC}"
  echo ""
  info "Исходный каталог: $ROOT"
  info "Целевой каталог:  $root"
  info "SUBSCRIPTION_URL: ${SUBSCRIPTION_URL:-не задан}"
  echo ""

  # 1. Проверка git-обновлений
  if $do_pull; then
    check_git_update "$ROOT" || warn "Пропускаю git-обновление"
  fi

  # 2. Синхронизация файлов
  if [[ "$ROOT" != "$root" ]]; then
    sync_files "$ROOT" "$root"
  else
    info "Исходный и целевой каталоги совпадают ($ROOT) — копирование не требуется"
  fi

  # 3. Синхронизация списков
  if $do_sync; then
    run_sync "$root"
  fi

  # 4. Сборка списков
  if $do_build; then
    run_build "$root"
  fi

  # 5. Установка команды firewall
  install_firewall_command "$root"

  # 6. Перезапуск сервисов
  if $do_restart; then
    restart_services "$root"
  fi

  header "Готово!"
  info "Firewall обновлён."
  if [[ -x /usr/local/bin/firewall ]]; then
    info "Запусти TUI: firewall"
  else
    info "Запусти TUI: sudo bash $root/scripts/setup-tui.sh"
  fi
}

main "$@"