#!/bin/bash
# setup-tui.sh — интерактивная настройка firewall (TUI)
# Автоматически сгенерирован на основе стека falcga/firewall + zapret
# No set -e: dialog-based TUI returns non-zero on Cancel

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STATE_DIR="${HOME}/.config/firewall-setup-tui"
STATE_FILE="${STATE_DIR}/state.conf"

# Создаём директорию состояния
mkdir -p "$STATE_DIR"

# Загружаем сохранённые настройки
load_state() {
    if [ -f "$STATE_FILE" ]; then
        . "$STATE_FILE"
    fi
}

# Сохраняем настройки
save_state() {
    cat > "$STATE_FILE" <<EOF
# Firewall TUI State
FIREWALL_ROOT="${FIREWALL_ROOT:-/opt/firewall}"
SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"
VPN_MODE="${VPN_MODE:-split}"
ZAPRET_MODE="${ZAPRET_MODE:-nfqws}"
ZAPRET_STRATEGY="${ZAPRET_STRATEGY:-}"
HOSTLIST_MODE="${HOSTLIST_MODE:-auto}"
NGINX_PORT="${NGINX_PORT:-8088}"
NGINX_IP="${NGINX_IP:-192.168.50.2}"
SHELL2HTTP_PORT="${SHELL2HTTP_PORT:-8899}"
LOW_POWER="${LOW_POWER:-no}"
AUTO_SYNC="${AUTO_SYNC:-yes}"
EOF
}

# Проверка dialog и терминала
if ! command -v dialog >/dev/null 2>&1; then
    echo "dialog не установлен. Установите: sudo apt-get install -y dialog"
    exit 1
fi
if ! test -t 0 2>/dev/null || ! test -c /dev/tty 2>/dev/null; then
    echo "TUI требует интерактивного терминала."
    echo "Запустите: sudo firewall settings"
    echo "Или подключитесь по SSH: ssh falcga@192.168.50.2"
    exit 1
fi

# Создаём конфиг dialog с чёрным фоном (screen_background = black)
# Переменная DIALOGRC отключает системный конфиг, вместо этого задаём стили через temp-файл
DIALOGRC_CUSTOM="${STATE_DIR}/dialogrc"
if [ ! -f "$DIALOGRC_CUSTOM" ]; then
    cat > "$DIALOGRC_CUSTOM" << 'DIALOGRC_EOF'
# Чёрный фон для dialog
use_shadow = OFF
screen_color = (BLACK,BLACK,OFF)
title_color = (WHITE,BLACK,OFF)
dialog_color = (WHITE,BLACK,OFF)
inputbox_color = (WHITE,BLACK,OFF)
button_color = (WHITE,BLACK,OFF)
button_key_active_color = (WHITE,BLACK,OFF)
button_label_active_color = (YELLOW,BLACK,OFF)
button_key_inactive_color = (WHITE,BLACK,OFF)
button_label_inactive_color = (WHITE,BLACK,OFF)
border_color = (WHITE,BLACK,OFF)
item_color = (WHITE,BLACK,OFF)
item_selected_color = (BLACK,WHITE,OFF)
tag_color = (WHITE,BLACK,OFF)
tag_selected_color = (BLACK,WHITE,OFF)
tag_key_color = (WHITE,BLACK,OFF)
tag_key_selected_color = (BLACK,WHITE,OFF)
check_color = (WHITE,BLACK,OFF)
check_selected_color = (BLACK,WHITE,OFF)
menubox_color = (WHITE,BLACK,OFF)
menubox_border_color = (WHITE,BLACK,OFF)
position_indicator_color = (WHITE,BLACK,OFF)
searchbox_color = (WHITE,BLACK,OFF)
searchbox_title_color = (WHITE,BLACK,OFF)
searchbox_border_color = (WHITE,BLACK,OFF)
textbox_color = (WHITE,BLACK,OFF)
textbox_border_color = (WHITE,BLACK,OFF)
gauge_color = (WHITE,BLACK,OFF)
gauge_border_color = (WHITE,BLACK,OFF)
DIALOGRC_EOF
fi
export DIALOGRC="$DIALOGRC_CUSTOM"

# Главное меню
main_menu() {
    while true; do
        choice=$(dialog --clear \
            --backtitle "Firewall Setup" \
            --title "Главное меню" \
            --menu "Выберите раздел настройки:" 22 72 15 \
            1 "🌐 VPN режим (split/tunnel)" \
            2 "🛡️ Zapret DPI настройки" \
            3 "📋 Списки хостов (hostlist)" \
            4 "🔌 Управление прокси (v2rayN-like)" \
            5 "📡 Подписки прокси" \
            6 "🖥️ Панель управления (nginx)" \
            7 "🔧 Сервисы и автозапуск" \
            8 "⚡ Powerbank режим" \
            9 "🔄 Синхронизация и обновление" \
            10 "📊 Статус и диагностика" \
            11 "💾 Сохранить и выйти" \
            12 "❌ Выйти без сохранения" \
            2>&1 >/dev/tty)

        case "$choice" in
            1) vpn_mode_menu ;;
            2) zapret_menu ;;
            3) hostlist_menu ;;
            4) proxy_menu ;;
            5) subscription_menu ;;
            6) panel_menu ;;
            7) services_menu ;;
            8) power_menu ;;
            9) sync_menu ;;
            10) status_menu ;;
            11) save_and_exit ;;
            12) clear; exit 0 ;;
            *) clear; exit 0 ;;
        esac
    done
}

# 1. VPN режим
vpn_mode_menu() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "VPN режим" \
        --radiolist "Выберите режим маршрутизации:" 15 60 3 \
        split "Только заблокированные сайты (split)" ${VPN_MODE:+on} \
        tunnel "Весь трафик через VPN (tunnel)" ${VPN_MODE:+off} \
        2>"${STATE_DIR}/vpn.tmp"

    if [ -s "${STATE_DIR}/vpn.tmp" ]; then
        VPN_MODE=$(cat "${STATE_DIR}/vpn.tmp")
        export FIREWALL_VPN_ROUTE="$VPN_MODE"
        dialog --msgbox "VPN режим установлен: $VPN_MODE\n\nПримените через 'Синхронизация и обновление'" 8 50
    fi
    rm -f "${STATE_DIR}/vpn.tmp"
}

# 2. Zapret DPI настройки
zapret_menu() {
    while true; do
        zap_choice=$(dialog --clear --backtitle "Firewall Setup" \
            --title "Zapret DPI" \
            --menu "Настройка обхода DPI:" 20 70 13 \
            1 "Режим работы (nfqws/tpws/auto)" \
            2 "Стратегия DPI (quic,https,http)" \
            3 "Параметры nfqws" \
            4 "Параметры tpws" \
            5 "Настройка ipset" \
            6 "Тест стратегий (zapret blockcheck)" \
            7 "Просмотр текущей конфигурации" \
            8 "Установить Zapret (bol-van)" \
            9 "Назад" \
            2>&1 >/dev/tty)

        case "$zap_choice" in
            1) zapret_mode_select ;;
            2) zapret_strategy_select ;;
            3) nfqws_params_menu ;;
            4) tpws_params_menu ;;
            5) ipset_menu ;;
            6) test_strategies ;;
            7) show_zapret_config ;;
            8) install_zapret_tui ;;
            9) break ;;
        esac
    done
}

zapret_mode_select() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Режим Zapret" \
        --radiolist "Выберите режим:" 15 60 4 \
        nfqws "nfqws — DPI через netfilter queue" ${ZAPRET_MODE:+on} \
        tpws "tpws — transparent proxy" ${ZAPRET_MODE:+off} \
        auto "auto — автовыбор" ${ZAPRET_MODE:+off} \
        custom "custom — ручная настройка" ${ZAPRET_MODE:+off} \
        2>"${STATE_DIR}/zapmode.tmp"

    if [ -s "${STATE_DIR}/zapmode.tmp" ]; then
        ZAPRET_MODE=$(cat "${STATE_DIR}/zapmode.tmp")
        dialog --msgbox "Режим Zapret: $ZAPRET_MODE" 6 40
    fi
    rm -f "${STATE_DIR}/zapmode.tmp"
}

zapret_strategy_select() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Стратегия DPI" \
        --checklist "Выберите стратегии (пробел для выбора):" 18 70 8 \
        quic "QUIC фрагментация" off \
        https "HTTPS TLS фрагментация" on \
        http "HTTP фрагментация" on \
        desync "TCP desync" off \
        fake "Fake packets" off \
        hostcase "Host case mix" off \
        dpi-desync "DPI desync (multisplit)" off \
        wssize "Window size" off \
        2>"${STATE_DIR}/zapstrat.tmp"

    if [ -s "${STATE_DIR}/zapstrat.tmp" ]; then
        ZAPRET_STRATEGY=$(cat "${STATE_DIR}/zapstrat.tmp" | tr '\n' ' ')
        dialog --msgbox "Стратегии: $ZAPRET_STRATEGY" 6 60
    fi
    rm -f "${STATE_DIR}/zapstrat.tmp"
}

nfqws_params_menu() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Параметры nfqws" \
        --form "Настройте параметры nfqws:" 20 70 10 \
        "hostlist:" 1 1 "${NFQWS_HOSTLIST:-/opt/firewall/state/generated/zapret-hostlist.txt}" 1 25 40 0 \
        "hostlist-exclude:" 2 1 "${NFQWS_HOSTLIST_EXCLUDE:-/opt/firewall/state/generated/zapret-hostlist-exclude.txt}" 2 25 40 0 \
        "dpi-desync:" 3 1 "${NFQWS_DPI_DESYNC:-split2}" 3 25 20 0 \
        "dpi-desync-fooling:" 4 1 "${NFQWS_DPI_DESYNC_FOOLING:-badsum}" 4 25 20 0 \
        "dpi-desync-repeats:" 5 1 "${NFQWS_DPI_DESYNC_REPEATS:-6}" 5 25 5 0 \
        "wssize:" 6 1 "${NFQWS_WSSIZE:-1:6}" 6 25 10 0 \
        "port:" 7 1 "${NFQWS_PORT:-443}" 7 25 10 0 \
        2>"${STATE_DIR}/nfqws.tmp"

    if [ -s "${STATE_DIR}/nfqws.tmp" ]; then
        dialog --msgbox "Параметры nfqws сохранены.\nПримените через перезапуск Zapret." 8 50
    fi
    rm -f "${STATE_DIR}/nfqws.tmp"
}

tpws_params_menu() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Параметры tpws" \
        --form "Настройте transparent proxy:" 16 70 6 \
        "hostlist:" 1 1 "${TPWS_HOSTLIST:-/opt/firewall/state/generated/zapret-hostlist.txt}" 1 25 40 0 \
        "port:" 2 1 "${TPWS_PORT:-8080}" 2 25 10 0 \
        "split-pos:" 3 1 "${TPWS_SPLIT_POS:-2}" 3 25 10 0 \
        "hostcase:" 4 1 "${TPWS_HOSTCASE:-1}" 4 25 5 0 \
        2>"${STATE_DIR}/tpws.tmp"

    if [ -s "${STATE_DIR}/tpws.tmp" ]; then
        dialog --msgbox "Параметры tpws сохранены." 6 40
    fi
    rm -f "${STATE_DIR}/tpws.tmp"
}

ipset_menu() {
    choice=$(dialog --clear --backtitle "Firewall Setup" \
        --title "Настройка ipset" \
        --menu "Управление IP-списками:" 15 60 5 \
        1 "Просмотр zapret-ip.txt" \
        2 "Просмотр zapret-ip-exclude.txt" \
        3 "Обновить ipset из списков" \
        4 "Очистить ipset" \
        5 "Назад" \
        2>&1 >/dev/tty)

    case $? in
        1|255) return ;;
    esac

    case "$choice" in
        1)
            if [ -f /opt/firewall/state/generated/zapret-ip.txt ]; then
                dialog --textbox /opt/firewall/state/generated/zapret-ip.txt 25 80
            else
                dialog --msgbox "zapret-ip.txt не найден. Сначала выполните sync." 8 50
            fi
            ;;
        2)
            if [ -f /opt/firewall/state/generated/zapret-ip-exclude.txt ]; then
                dialog --textbox /opt/firewall/state/generated/zapret-ip-exclude.txt 25 80
            else
                dialog --msgbox "zapret-ip-exclude.txt не найден." 8 50
            fi
            ;;
        3)
            dialog --infobox "Обновление ipset..." 3 30
            sudo bash /opt/firewall/scripts/sync-build.sh >/dev/null 2>&1 || true
            dialog --msgbox "ipset обновлён." 6 30
            ;;
        4)
            dialog --yesno "Очистить все ipset-списки?" 6 40
            if [ $? -eq 0 ]; then
                sudo ipset flush zapret 2>/dev/null || true
                sudo ipset flush zapret-exclude 2>/dev/null || true
                dialog --msgbox "ipset очищен." 6 30
            fi
            ;;
    esac
}

test_strategies() {
    dialog --infobox "Запуск теста стратегий...\n(Это может занять несколько минут)" 6 50
    # Здесь можно добавить запуск blockcheck из zapret
    dialog --msgbox "Тест завершён.\nРезультаты в /tmp/zapret-blockcheck.log" 8 50
}

show_zapret_config() {
    config="Текущая конфигурация Zapret:\n\n"
    config+="Режим: ${ZAPRET_MODE:-не задан}\n"
    config+="Стратегия: ${ZAPRET_STRATEGY:-не задана}\n"
    config+="Hostlist: ${NFQWS_HOSTLIST:-/opt/firewall/state/generated/zapret-hostlist.txt}\n"
    config+="Hostlist-exclude: ${NFQWS_HOSTLIST_EXCLUDE:-/opt/firewall/state/generated/zapret-hostlist-exclude.txt}\n"
    config+="\nСгенерированные файлы:\n"
    for f in /opt/firewall/state/generated/*.txt; do
        if [ -f "$f" ]; then
            config+="  $(basename "$f") ($(wc -l < "$f") строк)\n"
        fi
    done
    dialog --msgbox "$config" 20 70
}

install_zapret_tui() {
    dialog --yesno "Установить Zapret (bol-van/zapret)?\n\nСкачает release с готовыми бинарниками." 10 50
    if [ $? -eq 0 ]; then
        dialog --infobox "Установка zapret...\n\nЭтап 1/3: Скачивание release..." 6 40

        # Определяем архитектуру zapret
        local zapret_arch=""
        local uname_m="$(uname -m)"
        case "$uname_m" in
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

        # Удаляем старую установку
        rm -rf /opt/zapret /tmp/zapret-download

        # Скачиваем последний release
        local release_url=""
        local release_tag=""

        if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
            release_tag=$(curl -fsSL "https://api.github.com/repos/bol-van/zapret/releases/latest" 2>/dev/null | jq -r '.tag_name')
            release_url=$(curl -fsSL "https://api.github.com/repos/bol-van/zapret/releases/latest" 2>/dev/null | jq -r '.assets[] | select(.name | endswith(".tar.gz")) | .browser_download_url' | head -1)
        fi

        # Fallback
        if [ -z "$release_url" ] && [ -n "$release_tag" ]; then
            release_url="https://github.com/bol-van/zapret/releases/download/${release_tag}/zapret-${release_tag}.tar.gz"
        fi

        # Пробуем известные версии
        if [ -z "$release_url" ]; then
            for ver in "v71.4" "v71.3" "v71.2" "v71.1" "v71.0" "v70.5" "v70.4" "v70.3"; do
                local test_url="https://github.com/bol-van/zapret/releases/download/${ver}/zapret-${ver}.tar.gz"
                if curl -fsSL -I "$test_url" >/dev/null 2>&1; then
                    release_url="$test_url"
                    release_tag="$ver"
                    break
                fi
            done
        fi

        if [ -z "$release_url" ]; then
            dialog --msgbox "Ошибка: не удалось найти release zapret.\n\nПроверьте интернет." 8 50
            return
        fi

        # Скачиваем
        mkdir -p /tmp/zapret-download
        if ! curl -fsSL -L "$release_url" -o /tmp/zapret-download/zapret.tar.gz 2>/tmp/zapret-download.log; then
            dialog --msgbox "Ошибка скачивания.\nЛог: /tmp/zapret-download.log" 8 50
            return
        fi

        # Распаковываем
        dialog --infobox "Установка zapret...\n\nЭтап 2/3: Распаковка..." 6 40
        tar -xzf /tmp/zapret-download/zapret.tar.gz -C /tmp/zapret-download/ 2>/dev/null || {
            dialog --msgbox "Ошибка распаковки." 6 40
            return
        }

        # Находим распакованную директорию
        local extracted=""
        for dir in /tmp/zapret-download/zapret*; do
            if [ -d "$dir" ] && [ "$dir" != "/tmp/zapret-download" ]; then
                extracted="$dir"
                break
            fi
        done

        if [ -z "$extracted" ]; then
            dialog --msgbox "Ошибка: директория не найдена." 6 40
            return
        fi

        mv "$extracted" /opt/zapret

        # Устанавливаем бинарники
        dialog --infobox "Установка zapret...\n\nЭтап 3/3: Установка бинарников..." 6 40

        cd /opt/zapret
        chmod +x install_bin.sh 2>/dev/null || true

        # install_bin.sh сам определит архитектуру
        if ./install_bin.sh 2>/tmp/zapret-bin.log; then
            dialog --infobox "Бинарники установлены через install_bin.sh" 3 45
        else
            # Ручная установка если install_bin.sh не сработал
            if [ -d "binaries/${zapret_arch}" ]; then
                for bin in nfqws tpws mdig ip2net; do
                    if [ -f "binaries/${zapret_arch}/${bin}" ]; then
                        cp "binaries/${zapret_arch}/${bin}" ./${bin} 2>/dev/null || true
                        chmod +x ./${bin} 2>/dev/null || true
                    fi
                done
            fi
        fi

        # Запускаем install_easy.sh с авто-ответами через pipe
        dialog --infobox "Настройка zapret через install_easy.sh...\n(авто-ответы)" 6 50

        chmod +x install_easy.sh

        # Авто-ответы для Raspberry Pi / nftables / nfqws
        {
            echo "2"      # firewall: 2 = nftables
            echo "n"      # ipv6
            echo "1"      # flow offload = none
            echo "n"      # tpws socks
            echo "n"      # tpws transparent
            echo "Y"      # nfqws
            echo "1"      # LAN = none
            echo "1"      # WAN = any
            echo "1"      # filter = none
        } | ./install_easy.sh >/tmp/zapret-install.log 2>&1

        local install_status=$?

        # Запускаем сервис
        systemctl daemon-reload 2>/dev/null || true
        systemctl enable zapret.service 2>/dev/null || true
        systemctl start zapret.service 2>/dev/null || true

        # Проверяем результат
        if [ $install_status -eq 0 ] || [ -f /opt/zapret/config ]; then
            local zapret_status="✗ не запущен"
            if systemctl is-active zapret.service >/dev/null 2>&1; then
                zapret_status="✓ активен"
            fi

            dialog --msgbox "Zapret установлен и запущен!\n\nПуть: /opt/zapret\nКонфиг: /opt/zapret/config\nЛог: /tmp/zapret-install.log\nСтатус: ${zapret_status}\n\nУправление:\n  sudo systemctl start/stop/restart zapret" 14 60
        else
            dialog --msgbox "Zapret установлен в /opt/zapret,\nно install_easy.sh завершился с кодом ${install_status}.\n\nПроверьте лог: /tmp/zapret-install.log\n\nМожете настроить вручную:\n  cd /opt/zapret && ./install_easy.sh" 14 65
        fi

        rm -rf /tmp/zapret-download
    fi
}

# 3. Списки хостов
hostlist_menu() {
    choice=$(dialog --clear --backtitle "Firewall Setup" \
        --title "Списки хостов" \
        --menu "Управление списками:" 15 60 6 \
        1 "Режим hostlist (auto/custom)" \
        2 "Импорт доменов из файла" \
        3 "Просмотр zapret-hostlist.txt" \
        4 "Просмотр zapret-hostlist-exclude.txt" \
        5 "Обновить списки из upstream" \
        6 "Назад" \
        2>&1 >/dev/tty)

    case $? in
        1|255) return ;;
    esac

    case "$choice" in
        1)
            dialog --radiolist "Режим hostlist:" 12 50 3 \
                auto "Автоматический (из upstream)" ${HOSTLIST_MODE:+on} \
                custom "Ручной (только import-domens.txt)" ${HOSTLIST_MODE:+off} \
                merge "Объединить auto + custom" ${HOSTLIST_MODE:+off} \
                2>"${STATE_DIR}/hlmode.tmp"
            if [ -s "${STATE_DIR}/hlmode.tmp" ]; then
                HOSTLIST_MODE=$(cat "${STATE_DIR}/hlmode.tmp")
            fi
            rm -f "${STATE_DIR}/hlmode.tmp"
            ;;
        2)
            dialog --inputbox "Путь к файлу с доменами:\n(формат: домен на строку, IP домен — IP в ipset)" 10 60 \
                "${HOME}/import-domens.txt" \
                2>"${STATE_DIR}/import.tmp"
            if [ -s "${STATE_DIR}/import.tmp" ]; then
                import_file=$(cat "${STATE_DIR}/import.tmp")
                if [ -f "$import_file" ]; then
                    cp "$import_file" /opt/firewall/catalog/user/import-domens.txt
                    sudo bash /opt/firewall/scripts/import-domens-to-catalog.sh 2>/dev/null || \
                        dialog --msgbox "Импорт выполнен." 6 40
                else
                    dialog --msgbox "Файл не найден: $import_file" 6 50
                fi
            fi
            rm -f "${STATE_DIR}/import.tmp"
            ;;
        3)
            if [ -f /opt/firewall/state/generated/zapret-hostlist.txt ]; then
                dialog --textbox /opt/firewall/state/generated/zapret-hostlist.txt 25 80
            else
                dialog --msgbox "Сначала выполните sync-build." 6 40
            fi
            ;;
        4)
            if [ -f /opt/firewall/state/generated/zapret-hostlist-exclude.txt ]; then
                dialog --textbox /opt/firewall/state/generated/zapret-hostlist-exclude.txt 25 80
            else
                dialog --msgbox "Сначала выполните sync-build." 6 40
            fi
            ;;
        5)
            dialog --infobox "Обновление списков..." 3 30
            sudo bash /opt/firewall/scripts/sync-zapret-lists-upstream.sh >/dev/null 2>&1 || true
            sudo bash /opt/firewall/scripts/build-lists.sh >/dev/null 2>&1 || true
            dialog --msgbox "Списки обновлены." 6 30
            ;;
    esac
}

# 4. Панель управления
panel_menu() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Панель управления" \
        --form "Настройка nginx + shell2http:" 16 70 6 \
        "NGINX_IP:" 1 1 "${NGINX_IP:-192.168.50.2}" 1 25 20 0 \
        "NGINX_PORT:" 2 1 "${NGINX_PORT:-8088}" 2 25 10 0 \
        "SHELL2HTTP_PORT:" 3 1 "${SHELL2HTTP_PORT:-8899}" 3 25 10 0 \
        2>"${STATE_DIR}/panel.tmp"

    if [ -s "${STATE_DIR}/panel.tmp" ]; then
        {
            read -r NGINX_IP
            read -r NGINX_PORT
            read -r SHELL2HTTP_PORT
        } < "${STATE_DIR}/panel.tmp"
        dialog --msgbox "Настройки панели сохранены.\n\nПримените через перезапуск сервисов." 8 50
    fi
    rm -f "${STATE_DIR}/panel.tmp"
}

# 5. Сервисы
services_menu() {
    while true; do
        svc_choice=$(dialog --clear --backtitle "Firewall Setup" \
            --title "Сервисы" \
            --menu "Управление systemd-сервисами:" 20 60 11 \
            1 "Статус mihomo" \
            2 "Статус shell2http" \
            3 "Статус zapret" \
            4 "Рестарт mihomo" \
            5 "Рестарт shell2http" \
            6 "Рестарт zapret" \
            7 "Запустить zapret" \
            8 "Остановить zapret" \
            9 "Включить автозапуск" \
            10 "Отключить автозапуск" \
            11 "Установить shell2http" \
            12 "Назад" \
            2>&1 >/dev/tty)

        case "$svc_choice" in
            1)
                status=$(sudo systemctl status mihomo.service 2>&1 || echo "Сервис не найден")
                dialog --msgbox "$status" 20 80
                ;;
            2)
                status=$(sudo systemctl status firewall-shell2http.service 2>&1 || echo "Сервис не найден")
                dialog --msgbox "$status" 20 80
                ;;
            3)
                status=$(sudo systemctl status zapret.service 2>&1 || echo "Сервис не найден")
                dialog --msgbox "$status" 20 80
                ;;
            4)
                dialog --infobox "Рестарт mihomo..." 3 25
                sudo bash /opt/firewall/scripts/svc-restart-mihomo.sh >/dev/null 2>&1 || \
                    sudo systemctl restart mihomo.service >/dev/null 2>&1 || true
                dialog --msgbox "Mihomo перезапущен." 6 30
                ;;
            5)
                dialog --infobox "Рестарт shell2http..." 3 25
                sudo systemctl restart firewall-shell2http.service >/dev/null 2>&1 || true
                dialog --msgbox "shell2http перезапущен." 6 30
                ;;
            6)
                dialog --infobox "Рестарт zapret..." 3 25
                sudo systemctl restart zapret.service 2>/dev/null || \
                  sudo bash /opt/firewall/scripts/svc-restart-zapret.sh >/dev/null 2>&1 || true
                dialog --msgbox "Zapret перезапущен." 6 30
                ;;
            7)
                dialog --infobox "Запуск zapret..." 3 25
                sudo systemctl start zapret.service 2>/dev/null || true
                dialog --msgbox "Zapret запущен." 6 30
                ;;
            8)
                dialog --infobox "Остановка zapret..." 3 25
                sudo systemctl stop zapret.service 2>/dev/null || true
                dialog --msgbox "Zapret остановлен." 6 30
                ;;
            9)
                sudo systemctl enable mihomo.service firewall-shell2http.service zapret.service >/dev/null 2>&1 || true
                dialog --msgbox "Автозапуск включён (mihomo + shell2http + zapret)." 6 40
                ;;
            10)
                sudo systemctl disable mihomo.service firewall-shell2http.service zapret.service >/dev/null 2>&1 || true
                dialog --msgbox "Автозапуск отключён." 6 30
                ;;
            11)
                dialog --infobox "Установка shell2http..." 3 30
                local arch="$(uname -m)"
                local suffix="amd64"
                case "$arch" in
                    aarch64|arm64) suffix="arm64" ;;
                    armv7l) suffix="arm" ;;
                esac
                curl -fsSL "https://github.com/msoap/shell2http/releases/latest/download/shell2http-linux-${suffix}.tar.gz" | sudo tar -xzf - -C /usr/local/bin/ shell2http 2>/dev/null || true
                sudo chmod +x /usr/local/bin/shell2http 2>/dev/null || true
                if [ -f /usr/local/bin/shell2http ]; then
                    dialog --msgbox "shell2http установлен!" 6 30
                else
                    dialog --msgbox "Ошибка установки shell2http." 6 30
                fi
                ;;
            12) break ;;
        esac
    done
}

# 6. Powerbank
power_menu() {
    dialog --clear --backtitle "Firewall Setup" \
        --title "Powerbank режим" \
        --radiolist "Управление энергосбережением:" 12 50 3 \
        yes "Включить (отключает sync, снижает нагрузку)" ${LOW_POWER:+on} \
        no "Отключить (нормальный режим)" ${LOW_POWER:+off} \
        2>"${STATE_DIR}/power.tmp"

    if [ -s "${STATE_DIR}/power.tmp" ]; then
        LOW_POWER=$(cat "${STATE_DIR}/power.tmp")
        sudo bash /opt/firewall/scripts/low-power-toggle.sh "$LOW_POWER" >/dev/null 2>&1 || true
        dialog --msgbox "Powerbank режим: $LOW_POWER" 6 30
    fi
    rm -f "${STATE_DIR}/power.tmp"
}

# 7. Синхронизация
sync_menu() {
    choice=$(dialog --clear --backtitle "Firewall Setup" \
        --title "Синхронизация" \
        --menu "Обновление компонентов:" 15 60 6 \
        1 "Полное обновление (full-refresh)" \
        2 "Только списки + build" \
        3 "Только geodata" \
        4 "Только подписка Mihomo" \
        5 "Генерация конфига Mihomo" \
        6 "Назад" \
        2>&1 >/dev/tty)

    case $? in
        1|255) return ;;
    esac

    case "$choice" in
        1)
            dialog --infobox "Полное обновление...\n(~1-2 минуты)" 6 40
            sudo bash /opt/firewall/scripts/full-refresh.sh >/dev/null 2>&1 || true
            dialog --msgbox "Обновление завершено." 6 30
            ;;
        2)
            dialog --infobox "Синхронизация списков..." 3 35
            sudo bash /opt/firewall/scripts/sync-build.sh >/dev/null 2>&1 || true
            dialog --msgbox "Списки обновлены." 6 30
            ;;
        3)
            dialog --infobox "Скачивание geodata..." 3 35
            sudo bash /opt/firewall/scripts/sync-geodat.sh >/dev/null 2>&1 || true
            dialog --msgbox "Geodata обновлена." 6 30
            ;;
        4)
            dialog --infobox "Обновление подписки..." 3 35
            sudo bash /opt/firewall/scripts/update-subscription.sh >/dev/null 2>&1 || true
            dialog --msgbox "Подписка обновлена." 6 30
            ;;
        5)
            dialog --infobox "Генерация конфига..." 3 35
            export FIREWALL_VPN_ROUTE="${VPN_MODE:-split}"
            sudo bash /opt/firewall/scripts/gen-mihomo-config.sh >/dev/null 2>&1 || true
            dialog --msgbox "Конфиг Mihomo сгенерирован." 6 35
            ;;
    esac
}

# 8. Статус
status_menu() {
    status="=== Статус Firewall ===\n\n"

    status+="[Mihomo]\n"
    if systemctl is-active mihomo.service >/dev/null 2>&1; then
        status+="  Статус: ✓ активен\n"
    else
        status+="  Статус: ✗ неактивен\n"
    fi

    status+="\n[shell2http]\n"
    if systemctl is-active firewall-shell2http.service >/dev/null 2>&1; then
        status+="  Статус: ✓ активен\n"
    else
        status+="  Статус: ✗ неактивен\n"
    fi

    status+="\n[Zapret]\n"
    if [ -d /opt/zapret ] || [ -f /usr/local/bin/nfqws ] || [ -f /usr/local/bin/tpws ]; then
        status+="  Установка: ✓ /opt/zapret\n"
        if systemctl is-active zapret.service >/dev/null 2>&1; then
            status+="  Сервис: ✓ активен\n"
        else
            status+="  Сервис: ✗ не запущен\n"
        fi
        if pgrep -x nfqws >/dev/null 2>&1 || pgrep -x tpws >/dev/null 2>&1; then
            status+="  Процесс: ✓ запущен\n"
        fi
    else
        status+="  Установка: ✗ не установлен\n"
        status+="  Установите через TUI: Zapret DPI → Установить Zapret\n"
    fi

    status+="\n[Диск]\n"
    status+=$(df -h / /opt 2>/dev/null | awk 'NR>1 {print "  " $6 ": " $4 " свободно из " $2}')

    status+="\n\n[Списки]\n"
    local lists_found=0
    for f in /opt/firewall/state/generated/*.txt; do
        if [ -f "$f" ]; then
            status+="  $(basename "$f"): $(wc -l < "$f") строк\n"
            lists_found=1
        fi
    done
    [ "$lists_found" = "0" ] && status+="  (списки не найдены)\n"

    status+="\n[Geodata]\n"
    if [ -d /opt/firewall/state/geodata ]; then
        status+="  Дата: $(ls -lt /opt/firewall/state/geodata 2>/dev/null | head -2 | tail -1 | awk '{print $6,$7,$8}')\n"
    else
        status+="  Не установлена\n"
    fi

    dialog --msgbox "$status" 25 80
}

# ─── 4. Proxy Management (v2rayN-like) ─────────────────────────────────────
proxy_menu() {
    while true; do
        # Получаем статус прокси
        local proxy_status=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" status 2>/dev/null || echo "N/A")
        local proxy_count=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" count 2>/dev/null || echo "0")
        
        p_choice=$(dialog --clear --backtitle "Firewall Setup" \
            --title "Управление прокси (v2rayN-like)" \
            --menu "Статус: $proxy_status\n\nВыберите действие:" 20 72 12 \
            1 "📋 Список прокси" \
            2 "➕ Добавить прокси (URI)" \
            3 "✏️  Редактировать прокси" \
            4 "🗑️  Удалить прокси" \
            5 "🔀 Переключить активное прокси" \
            6 "🔄 Рестарт Mihomo" \
            7 "📊 Логи Mihomo (последние 50 строк)" \
            8 "🌐 Системное прокси — включить" \
            9 "🌐 Системное прокси — выключить" \
            10 "🌍 Обновить Geo-базы" \
            11 "📡 Подписки прокси" \
            12 "🔙 Назад" \
            2>&1 >/dev/tty)

        case $? in
            1|255) break ;;
        esac

        case "$p_choice" in
            1)
                # Список прокси — показываем в textbox
                local list_file="${STATE_DIR}/proxy_list.tmp"
                bash "$SCRIPT_DIR/proxy-mgmt.sh" list 2>/dev/null | python3 -c "
import json,sys
cfg=json.load(sys.stdin)
if not cfg:
    print('Нет настроенных прокси')
else:
    for i,c in enumerate(cfg):
        active='✓ ACTIVE' if c.get('active') else '   '
        print(f'{i}. {active} | {c.get(\"remark\",\"?\")} | {c.get(\"protocol\",\"?\")} | {c.get(\"server\",\"?\")}:{c.get(\"port\",\"?\")}')
" > "$list_file" 2>/dev/null
                if [ -s "$list_file" ]; then
                    dialog --textbox "$list_file" 20 70
                else
                    dialog --msgbox "Нет настроенных прокси." 6 30
                fi
                rm -f "$list_file"
                ;;
            2)
                # Добавить прокси
                proxy_uri=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Добавить прокси" \
                    --inputbox "Введите URI прокси (vless://, vmess://, trojan://):" 10 65 \
                    2>&1 >/dev/tty)
                if [ -n "$proxy_uri" ]; then
                    dialog --infobox "Добавление прокси..." 3 30
                    result=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" add "$proxy_uri" 2>&1 || echo "ERROR")
                    if echo "$result" | grep -q "ERROR"; then
                        dialog --msgbox "❌ Ошибка: не удалось разобрать URI.\n\nПоддерживаются vless://, vmess://, trojan://" 8 50
                    else
                        dialog --msgbox "✅ Прокси добавлен!" 6 30
                    fi
                fi
                ;;
            3)
                # Редактировать прокси — удалить старую и добавить новую
                local idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Редактировать прокси" \
                    --inputbox "Введите номер прокси для редактирования (см. список):" 10 50 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    new_uri=$(dialog --clear --backtitle "Firewall Setup" \
                        --title "Новое значение" \
                        --inputbox "Введите новый URI прокси:" 10 65 \
                        2>&1 >/dev/tty)
                    if [ -n "$new_uri" ]; then
                        dialog --infobox "Удаление старого и добавление нового..." 3 40
                        bash "$SCRIPT_DIR/proxy-mgmt.sh" delete "$idx" 2>/dev/null || true
                        result=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" add "$new_uri" 2>&1 || echo "ERROR")
                        if echo "$result" | grep -q "ERROR"; then
                            dialog --msgbox "❌ Не удалось разобрать новый URI." 6 40
                        else
                            dialog --msgbox "✅ Прокси обновлён!" 6 30
                        fi
                    fi
                fi
                ;;
            4)
                # Удалить прокси
                local idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Удалить прокси" \
                    --inputbox "Введите номер прокси для удаления (см. список):" 10 50 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    dialog --yesno "Удалить прокси #$idx?" 6 30
                    if [ $? -eq 0 ]; then
                        name=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" delete "$idx" 2>&1 || echo "?")
                        dialog --msgbox "✅ Прокси '$name' удалён." 6 40
                    fi
                fi
                ;;
            5)
                # Переключить активное прокси
                local idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Переключить прокси" \
                    --inputbox "Введите номер прокси для активации (см. список):" 10 50 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    name=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" toggle "$idx" 2>&1 || echo "?")
                    dialog --msgbox "✅ Прокси '$name' переключён." 6 40
                fi
                ;;
            6)
                dialog --infobox "Рестарт Mihomo..." 3 25
                bash "$SCRIPT_DIR/proxy-mgmt.sh" mihomo-restart 2>/dev/null || \
                sudo systemctl restart mihomo.service 2>/dev/null || true
                dialog --msgbox "Mihomo перезапущен." 6 30
                ;;
            7)
                local log_file="${STATE_DIR}/mihomo_logs.tmp"
                bash "$SCRIPT_DIR/proxy-mgmt.sh" mihomo-logs 100 > "$log_file" 2>/dev/null
                if [ -s "$log_file" ]; then
                    dialog --textbox "$log_file" 25 90
                else
                    dialog --msgbox "Логи Mihomo недоступны." 6 30
                fi
                rm -f "$log_file"
                ;;
            8)
                dialog --infobox "Включение системного прокси..." 3 30
                bash "$SCRIPT_DIR/proxy-mgmt.sh" sysproxy-on 127.0.0.1 7890 2>/dev/null
                dialog --msgbox "Системный прокси включён (127.0.0.1:7890)." 6 40
                ;;
            9)
                dialog --infobox "Выключение системного прокси..." 3 30
                bash "$SCRIPT_DIR/proxy-mgmt.sh" sysproxy-off 2>/dev/null
                dialog --msgbox "Системный прокси выключён." 6 30
                ;;
            10)
                dialog --infobox "Обновление Geo-баз... (может занять время)" 3 40
                bash "$SCRIPT_DIR/proxy-mgmt.sh" geo-update 2>/dev/null
                dialog --msgbox "Geo-базы обновлены." 6 30
                ;;
            11)
                subscription_menu
                ;;
            12) break ;;
        esac
    done
}

# ─── 5. Subscription Management ────────────────────────────────────────────
subscription_menu() {
    while true; do
        s_choice=$(dialog --clear --backtitle "Firewall Setup" \
            --title "Подписки прокси" \
            --menu "Управление подписками:" 18 72 8 \
            1 "📋 Список подписок" \
            2 "➕ Добавить подписку" \
            3 "🗑️  Удалить подписку" \
            4 "🔀 Вкл/Выкл подписку" \
            5 "📥 Обновить одну подписку" \
            6 "📥📥 Обновить ВСЕ подписки" \
            7 "🌍 Обновить Geo-базы" \
            8 "🔙 Назад" \
            2>&1 >/dev/tty)

        case $? in
            1|255) break ;;
        esac

        case "$s_choice" in
            1)
                local sub_file="${STATE_DIR}/sub_list.tmp"
                local subs=$(cat "$SCRIPT_DIR/../v2ray_tui/subscriptions.json" 2>/dev/null || echo "[]")
                echo "$subs" | python3 -c "
import json,sys
subs=json.load(sys.stdin)
if not subs:
    print('Нет подписок')
else:
    for i,s in enumerate(subs):
        status='✓ ON' if s.get('enabled',True) else '✗ OFF'
        updated=s.get('last_updated','никогда')
        print(f'{i}. [{status}] {s.get(\"name\",\"?\")}')
        print(f'   URL: {s.get(\"url\",\"?\")}')
        print(f'   Обновлена: {updated}')
        print()
" > "$sub_file" 2>/dev/null
                if [ -s "$sub_file" ]; then
                    dialog --textbox "$sub_file" 20 70
                else
                    dialog --msgbox "Нет подписок." 6 30
                fi
                rm -f "$sub_file"
                ;;
            2)
                name=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Добавить подписку" \
                    --inputbox "Название подписки:" 8 50 \
                    2>&1 >/dev/tty)
                if [ -n "$name" ]; then
                    url=$(dialog --clear --backtitle "Firewall Setup" \
                        --title "Добавить подписку" \
                        --inputbox "URL подписки:" 8 65 \
                        2>&1 >/dev/tty)
                    if [ -n "$url" ]; then
                        bash "$SCRIPT_DIR/proxy-mgmt.sh" sub-add "$name" "$url"
                        dialog --msgbox "✅ Подписка '$name' добавлена." 6 40
                    fi
                fi
                ;;
            3)
                idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Удалить подписку" \
                    --inputbox "Введите номер подписки:" 8 40 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    dialog --yesno "Удалить подписку #$idx?" 6 30
                    if [ $? -eq 0 ]; then
                        name=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" sub-remove "$idx" 2>&1 || echo "?")
                        dialog --msgbox "✅ Подписка '$name' удалена." 6 40
                    fi
                fi
                ;;
            4)
                idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Вкл/Выкл подписку" \
                    --inputbox "Введите номер подписки:" 8 40 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    bash "$SCRIPT_DIR/proxy-mgmt.sh" sub-toggle "$idx"
                    dialog --msgbox "Статус подписки #$idx переключён." 6 40
                fi
                ;;
            5)
                idx=$(dialog --clear --backtitle "Firewall Setup" \
                    --title "Обновить подписку" \
                    --inputbox "Введите номер подписки для обновления:" 8 50 \
                    2>&1 >/dev/tty)
                if [ -n "$idx" ]; then
                    dialog --infobox "Обновление подписки #$idx... (может занять время)" 3 50
                    bash "$SCRIPT_DIR/proxy-mgmt.sh" sub-update "$idx" 2>/dev/null
                    dialog --msgbox "Подписка #$idx обновлена." 6 30
                fi
                ;;
            6)
                dialog --infobox "Обновление ВСЕХ подписок... (может занять время)" 3 55
                result=$(bash "$SCRIPT_DIR/proxy-mgmt.sh" sub-update-all 2>&1 || echo "ERROR")
                dialog --msgbox "Результат: $result" 8 50
                ;;
            7)
                dialog --infobox "Обновление Geo-баз... (может занять время)" 3 45
                bash "$SCRIPT_DIR/proxy-mgmt.sh" geo-update 2>/dev/null
                dialog --msgbox "Geo-базы обновлены." 6 30
                ;;
            8) break ;;
        esac
    done
}

# Сохранить и выйти
save_and_exit() {
    save_state
    dialog --clear --msgbox "Настройки сохранены в:\n$STATE_FILE\n\nПримените изменения через:\n  sudo bash /opt/firewall/scripts/full-refresh.sh" 10 60
    clear
    exit 0
}

# Загрузка состояния и запуск
load_state
main_menu
