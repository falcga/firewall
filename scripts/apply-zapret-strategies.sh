#!/usr/bin/env bash
# Применение стратегий запрета DPI (аналог zapret для Windows)
# Стратегии берутся из state.conf и могут комбинироваться.
# Для bol-van/zapret на Linux генерирует параметры для nfqws/tpws.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-setup-tui"
STATE_FILE="$STATE_DIR/state.conf"
GENERATED_DIR="${ROOT}/state/generated"
ZAPRET_STRATEGIES_FILE="$GENERATED_DIR/zapret-strategies.conf"
ZAPRET_STRATEGIES="${ZAPRET_STRATEGIES:-}"

# Загрузка state.conf
if [[ -f "$STATE_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
fi

# Если строка пуста — пытаемся прочитать из файла стратегий
if [[ -z "$ZAPRET_STRATEGIES" && -f "$ZAPRET_STRATEGIES_FILE" ]]; then
  ZAPRET_STRATEGIES="$(cat "$ZAPRET_STRATEGIES_FILE")"
fi

# Парсим стратегии в массив
IFS=',' read -ra STRATEGIES <<< "$ZAPRET_STRATEGIES"

# Маппинг стратегий в параметры nfqws/tpws
declare -A STRAT_MAP
STRAT_MAP[quic]="--dpi-desync-fooling=quic"
STRAT_MAP[tcp-seg]="--dpi-desync-fooling=tcp-seg,badseq"
STRAT_MAP[md5]="--md5sig"
STRAT_MAP[host-fake]="--host-fake=\"www.google.com\""
STRAT_MAP[fake-http]="--dpi-desync-fooling=fake-http"
STRAT_MAP[fake-tls]="--dpi-desync-fooling=fake-tls"
STRAT_MAP[split]="--dpi-desync-fooling=split"
STRAT_MAP[badseq]="--dpi-desync-fooling=badseq"
STRAT_MAP[block]="--dpi-desync=block"
STRAT_MAP[disorder]="--dpi-desync-fooling=disorder"
STRAT_MAP[dataseq]="--dpi-desync-fooling=dataseq"

# Дефолтные параметры desync (если не задано ничего — soft)
DESYNC_MODE="${ZAPRET_DESYNC_MODE:-soft}"
declare -A DESYNC_MAP
DESYNC_MAP[soft]="--dpi-desync=soft"
DESYNC_MAP[hard]="--dpi-desync=hard"
DESYNC_MAP[fake]="--dpi-desync=fake"
DESYNC_MAP[disorder]="--dpi-desync=disorder2"
DESYNC_MAP[dataseq]="--dpi-desync=dataseq"
DESYNC_MAP[block]="--dpi-desync=block"

usage() {
  cat <<EOF
Использование: $(basename "$0") [--list] [--apply] [--show] [--set quic,tcp-seg,md5] [--desync soft|hard|fake]

  --list            Показать доступные стратегии
  --show            Показать текущие активные стратегии
  --set <строка>    Установить стратегии (через запятую)
  --apply           Сгенерировать конфиг и применить (если zapret установлен)
  --desync <mode>   Режим десинхронизации (soft, hard, fake, disorder, dataseq, block)
  --help            Эта справка

Примеры:
  $(basename "$0") --set quic,tcp-seg,md5
  $(basename "$0") --set quic,host-fake,fake-tls --desync fake
  $(basename "$0") --apply
EOF
}

list_strategies() {
  echo "Доступные стратегии (можно комбинировать через запятую):"
  echo ""
  printf "  %-12s %s\n" "Ключ" "Описание"
  printf "  %-12s %s\n" "----" "--------"
  printf "  %-12s %s\n" "quic" "Фулинг QUIC — разрушение DPI на QUIC-трафике"
  printf "  %-12s %s\n" "tcp-seg" "TCP segmentation + badseq — фрагментация TCP"
  printf "  %-12s %s\n" "md5" "MD5 signature — подпись TCP MD5"
  printf "  %-12s %s\n" "host-fake" "Подмена Host на www.google.com"
  printf "  %-12s %s\n" "fake-http" "Вставка фейкового HTTP-запроса"
  printf "  %-12s %s\n" "fake-tls" "Вставка фейкового TLS-рукопожатия"
  printf "  %-12s %s\n" "split" "Разделение потока (split)"
  printf "  %-12s %s\n" "badseq" "Неправильная TCP-последовательность"
  printf "  %-12s %s\n" "disorder" "Перестановка пакетов"
  printf "  %-12s %s\n" "dataseq" "Вставка данных в последовательность"
  printf "  %-12s %s\n" "block" "Полная блокировка десинхронизации"
  echo ""
  echo "Режимы десинхронизации (--dpi-desync):"
  echo "  soft — мягкий (дефолт)"
  echo "  hard — жёсткий"
  echo "  fake — фейковый ответ"
  echo "  disorder2 — перестановка"
  echo "  dataseq — последовательность данных"
  echo "  block — блокировка"
}

show_current() {
  echo "Текущие стратегии:"
  if [[ -n "$ZAPRET_STRATEGIES" ]]; then
    echo "  $ZAPRET_STRATEGIES"
  else
    echo "  (не заданы)"
  fi
  echo "Режим desync: $DESYNC_MODE"
  echo ""
  if [[ -f "$ZAPRET_STRATEGIES_FILE" ]]; then
    echo "Сохранено в: $ZAPRET_STRATEGIES_FILE"
    echo "Содержимое: $(cat "$ZAPRET_STRATEGIES_FILE")"
  fi
}

set_strategies() {
  local input="$1"
  # Валидация: проверяем что все ключи известны
  IFS=',' read -ra PARTS <<< "$input"
  local valid=1
  for s in "${PARTS[@]}"; do
    s="${s// /}"  # trim
    if [[ -z "$s" ]]; then continue; fi
    if [[ ! -v "STRAT_MAP[$s]" ]]; then
      echo "Ошибка: неизвестная стратегия '$s'" >&2
      valid=0
    fi
  done
  if [[ "$valid" -eq 0 ]]; then
    echo "Допустимые стратегии: ${!STRAT_MAP[*]}" >&2
    exit 1
  fi
  ZAPRET_STRATEGIES="$input"
  mkdir -p "$GENERATED_DIR"
  printf '%s' "$ZAPRET_STRATEGIES" > "$ZAPRET_STRATEGIES_FILE"
  echo "Стратегии установлены: $ZAPRET_STRATEGIES"
  echo "Сохранено в $ZAPRET_STRATEGIES_FILE"
}

generate_config() {
  local out="$GENERATED_DIR/zapret-strategy-args.generated.txt"
  mkdir -p "$GENERATED_DIR"

  # Базовые параметры
  local args="${DESYNC_MAP[$DESYNC_MODE]:---dpi-desync=soft}"
  args="$args --dpi-desync-ttl=2"

  # Собираем fooling-параметры
  local fooling_parts=()
  local extra_args=()
  for s in "${STRATEGIES[@]}"; do
    s="${s// /}"
    [[ -z "$s" ]] && continue
    local val="${STRAT_MAP[$s]:-}"
    if [[ -z "$val" ]]; then continue; fi
    if [[ "$val" == --dpi-desync-fooling=* ]]; then
      # Извлекаем значение после =
      local fool_val="${val#*=}"
      fooling_parts+=("$fool_val")
    else
      extra_args+=("$val")
    fi
  done

  # Если есть fooling — собираем вместе
  if [[ ${#fooling_parts[@]} -gt 0 ]]; then
    local fooling_str
    fooling_str="$(IFS=,; echo "${fooling_parts[*]}")"
    args="$args --dpi-desync-fooling=$fooling_str"
  fi

  # Добавляем остальные аргументы
  for ea in "${extra_args[@]}"; do
    args="$args $ea"
  done

  # Параметры для nfqws (хостлисты из generated)
  local hostlist="$GENERATED_DIR/zapret-hostlist.txt"
  local hostlist_exclude="$GENERATED_DIR/zapret-hostlist-exclude.txt"

  if [[ -f "$hostlist" ]]; then
    args="$args --hostlist=$hostlist"
  fi
  if [[ -f "$hostlist_exclude" ]]; then
    args="$args --hostlist-exclude=$hostlist_exclude"
  fi

  printf '%s' "$args" > "$out"
  echo "Конфиг записан: $out"
  echo "Параметры: $args"
}

apply_config() {
  if [[ ! -f "$GENERATED_DIR/zapret-strategy-args.generated.txt" ]]; then
    echo "Нет сгенерированного конфига. Сначала выполни: $(basename "$0") --set ... --apply" >&2
    exit 1
  fi

  local args
  args="$(cat "$GENERATED_DIR/zapret-strategy-args.generated.txt")"

  echo "Применение стратегий zapret..."
  echo "Параметры: $args"

  # Пытаемся найти nfqws
  local nfqws=""
  for p in /usr/local/bin/nfqws /opt/zapret/nfqws /usr/bin/nfqws /usr/local/sbin/nfqws; do
    if [[ -x "$p" ]]; then
      nfqws="$p"
      break
    fi
  done

  if [[ -z "$nfqws" ]]; then
    echo "nfqws не найден. Zapret не установлен или собран не полностью." >&2
    echo "Сгенерированные параметры сохранены в $GENERATED_DIR/zapret-strategy-args.generated.txt" >&2
    echo "Используйте их вручную при запуске nfqws/tpws" >&2
    exit 0
  fi

  echo "Найден nfqws: $nfqws"

  # Останавливаем zapret если запущен
  if command -v systemctl >/dev/null 2>&1; then
    local zapret_service=""
    for s in zapret.service zapret-firewall.service nft-zapret.service; do
      if systemctl cat "$s" >/dev/null 2>&1; then
        zapret_service="$s"
        break
      fi
    done
    if [[ -n "$zapret_service" ]]; then
      echo "Перезапуск $zapret_service с новыми параметрами..."
      # Записываем параметры в конфиг-файл, откуда zapret их читает
      echo "ZAPRET_EXTRA_ARGS=\"$args\"" > /etc/zapret-strategy.env
      systemctl restart "$zapret_service" || echo "WARN: не удалось перезапустить $zapret_service" >&2
    fi
  fi

  echo "Готово. Стратегии применены."
}

main() {
  if [[ $# -eq 0 ]]; then
    show_current
    echo ""
    echo "Используй --help для справки."
    exit 0
  fi

  local mode=""
  local input=""
  local desync_mode=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list) mode="list" ;;
      --show) mode="show" ;;
      --set) mode="set"; input="$2"; shift ;;
      --apply) mode="apply" ;;
      --desync) desync_mode="$2"; shift ;;
      --help) mode="help" ;;
      *)
        if [[ -z "$input" ]]; then
          input="$1"
          mode="set"
        else
          echo "Неизвестный аргумент: $1" >&2
          exit 1
        fi
        ;;
    esac
    shift
  done

  if [[ -n "$desync_mode" ]]; then
    if [[ ! -v "DESYNC_MAP[$desync_mode]" ]]; then
      echo "Ошибка: неизвестный режим desync '$desync_mode'" >&2
      echo "Допустимые: ${!DESYNC_MAP[*]}" >&2
      exit 1
    fi
    DESYNC_MODE="$desync_mode"
    # Сохраняем в state-файл
    mkdir -p "$GENERATED_DIR"
    printf '%s' "$desync_mode" > "$GENERATED_DIR/zapret-desync-mode.txt"
  fi

  case "$mode" in
    list) list_strategies ;;
    show) show_current ;;
    set)
      set_strategies "$input"
      generate_config
      ;;
    apply)
      generate_config
      apply_config
      ;;
    help|*) usage ;;
  esac
}

main "$@"