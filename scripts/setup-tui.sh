#!/usr/bin/env bash
# Интерактивная настройка по шагам SETUP-RU.txt (порты, IP, установка, списки, Mihomo/Zapret, nginx+shell2http).
# Требование: sudo apt-get install -y dialog
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/firewall-setup-tui"
STATE_FILE="$STATE_DIR/state.conf"
BACKTITLE="Firewall / SETUP-RU"

H() { printf '%s %s\n' "${1:-22}" "${2:-74}"; }

require_dialog() {
	command -v dialog >/dev/null 2>&1 || {
		clear
		printf '%s\n' "Нужен dialog: sudo apt-get update && sudo apt-get install -y dialog" >&2
		exit 1
	}
}

_save_kv() {
	printf '%s=%s\n' "$1" "$(printf '%s' "$2" | sed "s/'/'\\\\''/g; s/^/'/; s/\$/'/")"
}

load_state() {
	mkdir -p "$STATE_DIR"
	chmod 700 "$STATE_DIR" 2>/dev/null || true
	if [[ -f "$STATE_FILE" ]]; then
		# shellcheck source=/dev/null
		source "$STATE_FILE"
	fi
	FIREWALL_ROOT="${FIREWALL_ROOT:-/opt/firewall}"
	SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"
	LAN_HTTP_IP="${LAN_HTTP_IP:-192.168.50.2}"
	LAN_HTTP_PORT="${LAN_HTTP_PORT:-8088}"
	SHELL2HTTP_LISTEN="${SHELL2HTTP_LISTEN:-127.0.0.1:8899}"
	FIREWALL_VPN_ROUTE="${FIREWALL_VPN_ROUTE:-split}"
	HTPASSWD_FILE="${HTPASSWD_FILE:-/etc/nginx/.firewall_dashboard_htpasswd}"
	SKIP_BINARIES="${SKIP_BINARIES:-0}"
	SKIP_SYNC="${SKIP_SYNC:-0}"
	SKIP_SYSTEMD="${SKIP_SYSTEMD:-0}"
	DRY_RUN="${DRY_RUN:-0}"
	NGINX_SITE_NAME="${NGINX_SITE_NAME:-firewall-dashboard}"
	DOMENS_SRC="${DOMENS_SRC:-$REPO_ROOT/domens.txt}"
}

save_state() {
	mkdir -p "$STATE_DIR"
	umask 077
	{
		_save_kv FIREWALL_ROOT "$FIREWALL_ROOT"
		_save_kv SUBSCRIPTION_URL "$SUBSCRIPTION_URL"
		_save_kv LAN_HTTP_IP "$LAN_HTTP_IP"
		_save_kv LAN_HTTP_PORT "$LAN_HTTP_PORT"
		_save_kv SHELL2HTTP_LISTEN "$SHELL2HTTP_LISTEN"
		_save_kv FIREWALL_VPN_ROUTE "$FIREWALL_VPN_ROUTE"
		_save_kv HTPASSWD_FILE "$HTPASSWD_FILE"
		_save_kv SKIP_BINARIES "$SKIP_BINARIES"
		_save_kv SKIP_SYNC "$SKIP_SYNC"
		_save_kv SKIP_SYSTEMD "$SKIP_SYSTEMD"
		_save_kv DRY_RUN "$DRY_RUN"
		_save_kv NGINX_SITE_NAME "$NGINX_SITE_NAME"
		_save_kv DOMENS_SRC "$DOMENS_SRC"
	} >"${STATE_FILE}.new"
	mv -f "${STATE_FILE}.new" "$STATE_FILE"
}

screens_root() {
	local fr="${FIREWALL_ROOT%/}"
	if [[ -d "$fr/scripts" ]] && [[ -f "$fr/scripts/sync-zapret-lists-upstream.sh" ]]; then
		printf '%s\n' "$fr"
	else
		printf '%s\n' "$REPO_ROOT"
	fi
}

msg_ok() {
	local h w
	read -r h w < <(H 12 72)
	dialog --backtitle "$BACKTITLE" --title "${1:-OK}" --msgbox "${2:-}" "$h" "$w" 3>&1 1>&2 2>&3 || true
}

msg_err() {
	local h w
	read -r h w < <(H 14 72)
	dialog --backtitle "$BACKTITLE" --title "${1:-Ошибка}" --msgbox "${2:-}" "$h" "$w" 3>&1 1>&2 2>&3 || true
}

show_textfile() {
	local title="$1" file="$2" h w
	read -r h w < <(H 22 82)
	dialog --backtitle "$BACKTITLE" --title "$title" --textbox "$file" "$h" "$w" 3>&1 1>&2 2>&3 || true
}

run_cmd_log() {
	local title="$1" log ec
	log="$(mktemp)"
	shift
	set +e
	"$@" >"$log" 2>&1
	ec=$?
	set -e
	if [[ "$ec" -ne 0 ]]; then
		msg_err "$title (код $ec)" "$(tail -n 90 "$log")"
	else
		msg_ok "$title" "$(tail -n 140 "$log")"
	fi
	rm -f "$log"
}

dlg_input() {
	local title="$1" text="$2" cur="$3" h w out
	read -r h w < <(H 11 74)
	out=$(dialog --backtitle "$BACKTITLE" --title "$title" --inputbox "$text" "$h" "$w" "$cur" \
		3>&1 1>&2 2>&3) || return 1
	printf '%s' "$out"
}

dlg_pass() {
	local title="$1" text="$2" h w out
	read -r h w < <(H 9 60)
	out=$(dialog --backtitle "$BACKTITLE" --title "$title" --passwordbox "$text" "$h" "$w" \
		3>&1 1>&2 2>&3) || return 1
	printf '%s' "$out"
}

apply_skip_flags_chk() {
	local chk="$1" t
	SKIP_BINARIES=0 SKIP_SYNC=0 SKIP_SYSTEMD=0 DRY_RUN=0
	while read -r t; do
		[[ -z "${t:-}" ]] && continue
		case "$t" in b) SKIP_BINARIES=1 ;; s) SKIP_SYNC=1 ;; d) SKIP_SYSTEMD=1 ;; y) DRY_RUN=1 ;; esac
	done <<<"$chk"
}

main_menu_pick() {
	local h mw ch
	read -r h mw < <(H 24 74)
	ch=$(dialog --backtitle "$BACKTITLE" --title "Настройка (SETUP-RU)" \
		--menu "Разделы (↑↓ Enter). Инструкция: ${REPO_ROOT}/SETUP-RU.txt" "$h" "$mw" 16 \
			"1" "[1] Общее — корень установки подписка флаги" \
			"2" "[2] Установка install.sh (-r FIREWALL_ROOT)" \
			"3" "[3] Списки Flowse/geodata/import domens/build" \
			"4" "[4] Mihomo режим VPN + gen-config" \
			"5" "[5] Zapret bol-van подсказки" \
			"6" "[6] Панель порты/IP nginx и shell2http" \
			"7" "[7] Система systemd nginx status" \
			"8" "[8] Справочник SETUP-RU (текстом)" \
			"9" "[9] Стратегии запрета DPI (zapret) — аналог Windows" \
			"A" "[A] Проверка обхода блокировок (detect bypass)" \
			"B" "[B] VPN (WireGuard/OpenVPN) — up/down/status" \
			"0" "[0] Выход" \
		3>&1 1>&2 2>&3) || return 1
	printf '%s' "$ch"
}

ui_general() {
	while true; do
		local h mw ch
		read -r h mw < <(H 26 74)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[1] Общее" --menu "\
FIREWALL_ROOT=$FIREWALL_ROOT
Ветка VPN: FIREWALL_VPN_ROUTE=$FIREWALL_VPN_ROUTE" "$h" "$mw" 11 \
			"a" "Путь FIREWALL_ROOT" \
			"b" "SUBSCRIPTION_URL" \
			"c" "Режим FIREWALL_VPN_ROUTE (split/tunnel)" \
			"d" "Флаги install: SKIP_BINARIES|SYNC|SYSTEMD, DRY_RUN" \
			"e" "Имя сайта nginx (sites-available)" \
			"f" "Путь к domens.txt для импорта" \
			"s" "Сохранить в $STATE_FILE и назад" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			a)
				local v
				v=$(dlg_input FIREWALL_ROOT "Каталог установки (по умолчанию /opt/firewall):" "$FIREWALL_ROOT") || continue
				FIREWALL_ROOT="${v// /}"
				;;
			b)
				local v
				v=$(dlg_input SUBSCRIPTION_URL "HTTPS URL подписки Clash/Mihomo:" "$SUBSCRIPTION_URL") || continue
				SUBSCRIPTION_URL="$v"
				;;
			c)
				local vn
				vn=$(dialog --backtitle "$BACKTITLE" --title FIREWALL_VPN_ROUTE --radiolist \
					"Перед gen-mihomo-config (см. SETUP-RU)" 14 74 4 \
					split "split — выборочно (geodata)" $([[ "$FIREWALL_VPN_ROUTE" != tunnel ]] && echo on || echo off) \
					tunnel "tunnel — весь трафик через VPN" $([[ "$FIREWALL_VPN_ROUTE" = tunnel ]] && echo on || echo off) \
					3>&1 1>&2 2>&3) || continue
				FIREWALL_VPN_ROUTE="${vn//$'\n'/}"
				;;
			d)
				local chk
				chk=$(dialog --backtitle "$BACKTITLE" --title "Флаги install.sh" --checklist "Отметьте [*] что включить" 16 76 6 \
					b "SKIP_BINARIES=1 (не качать бинарники)" $([[ "$SKIP_BINARIES" = 1 ]] && echo on || echo off) \
					s "SKIP_SYNC=1 (без первого sync)" $([[ "$SKIP_SYNC" = 1 ]] && echo on || echo off) \
					d "SKIP_SYSTEMD=1 (не писать unit-файлы)" $([[ "$SKIP_SYSTEMD" = 1 ]] && echo on || echo off) \
					y "DRY_RUN=1 (только печать команд)" $([[ "$DRY_RUN" = 1 ]] && echo on || echo off) \
					3>&1 1>&2 2>&3) || continue
				apply_skip_flags_chk "$chk"
				;;
			e)
				local v
				v=$(dlg_input NGINX_SITE_NAME "Имя файла в sites-available (без .conf):" "$NGINX_SITE_NAME") || continue
				NGINX_SITE_NAME="${v// /}"
				;;
			f)
				local v
				v=$(dlg_input domens "Путь к domens.txt:" "$DOMENS_SRC") || continue
				DOMENS_SRC="$v"
				;;
			s)
				save_state
				msg_ok Сохранено "Записано в $STATE_FILE"
				break
				;;
			0) save_state; break ;;
		esac
		save_state
	done
}

ui_install_preview() {
	cat <<-EOF
	Команда установки (нужен sudo):
	  SUBSCRIPTION_URL=… SKIP_BINARIES=$SKIP_BINARIES SKIP_SYNC=$SKIP_SYNC SKIP_SYSTEMD=$SKIP_SYSTEMD DRY_RUN=$DRY_RUN
	  sh $REPO_ROOT/install.sh -r $FIREWALL_ROOT

	Исходники install.sh: $REPO_ROOT
	EOF
}

ui_install_run() {
	save_state
	local tmp
	tmp="$(mktemp)"
	ui_install_preview >"$tmp"
	if ! dialog --backtitle "$BACKTITLE" --title "Запуск install.sh" --yesno "$(cat "$tmp")

Продолжить установку?" 24 74 3>&1 1>&2 2>&3; then rm -f "$tmp"; return 0; fi
	rm -f "$tmp"
	run_cmd_log install.sh sudo env SUBSCRIPTION_URL="$SUBSCRIPTION_URL" SKIP_BINARIES="$SKIP_BINARIES" SKIP_SYNC="$SKIP_SYNC" SKIP_SYSTEMD="$SKIP_SYSTEMD" DRY_RUN="$DRY_RUN" \
		sh "$REPO_ROOT/install.sh" -r "$FIREWALL_ROOT"
}

ui_lists_menu() {
	local root scr h mw ch
	root="$(screens_root)"
	scr="$root/scripts"
	while true; do
		read -r h mw < <(H 24 76)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[3] Списки" --menu "\
Корень: $root

Память Pi: полный цикл может быть тяжёлым во время нагрузки." "$h" "$mw" 10 \
				"z" "sync-zapret-lists-upstream.sh" \
				"g" "sync-geodat.sh" \
				"b" "build-lists.sh" \
				"i" "import-domens (DOMENS_SRC → каталог)" \
				"n" "Полная цепочка z+g+b без import" \
				"e" "Сменить рабочий корень FIREWALL_ROOT в разделе [1]" \
				"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			z)
				run_cmd_log sync-zapret sudo bash "$scr/sync-zapret-lists-upstream.sh"
				;;
			g)
				run_cmd_log sync-geodat sudo bash "$scr/sync-geodat.sh"
				;;
			b)
				run_cmd_log build-lists sudo bash "$scr/build-lists.sh"
				;;
			i)
				run_cmd_log import-domens sudo bash -lc "set -e; fr=\"$root\"; src=\"$DOMENS_SRC\"; [[ -f \"\$src\" ]] || exit 4; mkdir -p \"\$fr/catalog/user\"; cp -f \"\$src\" \"\$fr/catalog/user/import-domens.txt\"; bash \"\$fr/scripts/import-domens-to-catalog.sh\" \"\$fr/catalog/user/import-domens.txt\"; bash \"\$fr/scripts/build-lists.sh\""
				;;
			n)
				run_cmd_log "sync-geodat+build" bash -lc "set -e; sudo bash '$scr/sync-zapret-lists-upstream.sh'; sudo bash '$scr/sync-geodat.sh'; sudo bash '$scr/build-lists.sh'"
				;;
			e) msg_ok FIREWALL_ROOT "Откройте пункт [1] Общее (и запустите сохранённый корень здесь)." ;;
			0) break ;;
		esac
	done
}

ui_mihomo() {
	local root scr h mw ch
	root="$(screens_root)"
	scr="$root/scripts"
	while true; do
		read -r h mw < <(H 20 74)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[4] Mihomo" --menu "\
FIREWALL_VPN_ROUTE=$FIREWALL_VPN_ROUTE
Корень: $root
Бинарь: $(command -v mihomo 2>/dev/null || echo '?')" "$h" "$mw" 6 \
			"g" "gen-mihomo-config.sh (перегенерация конфига)" \
			"n" "Сменить split/tunnel (→ раздел Общее) краткая подсказка" \
			"r" "systemctl restart mihomo.service" \
			"u" "systemctl status mihomo.service" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			g)
				run_cmd_log gen-mihomo sudo env FIREWALL_VPN_ROUTE="$FIREWALL_VPN_ROUTE" bash "$scr/gen-mihomo-config.sh"
				;;
			n)
				msg_ok split/tunnel "split — по геодате; tunnel — полный VPN (SETUP-RU). Меню [1] → пункт c."
				;;
			r)
				run_cmd_log "restart mihomo" sudo systemctl restart mihomo.service
				;;
			u)
				run_cmd_log status-mihomo systemctl status mihomo.service --no-pager
				;;
			0) break ;;
		esac
	done
}

ui_zapret() {
	local root note h mw ch
	root="$(screens_root)"
	note="$REPO_ROOT/contrib/zapret-bolvan-note.txt"
	local genlst
	genlst=""
	if [[ -d "$root/state/generated" ]]; then
		genlst=$(ls "$root/state/generated"/zapret-*.txt 2>/dev/null | head -n 5 | xargs -r basename | tr '\n' ' ')
	fi

	while true; do
		read -r h mw < <(H 22 76)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[5] Zapret" --menu "\
bol-van/zapret + примечание в contrib/. Сгенерённые: ${genlst:-— нет файлов z*}" "$h" "$mw" 6 \
				"n" "Показать contrib/zapret-bolvan-note.txt" \
				"r" "Запуск svc-restart-zapret.sh (если установлен systemd zapret)" \
				"L" "ls -la state/generated" \
				"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			n)
				[[ -f "$note" ]] && show_textfile note "$note" || msg_err Файл "Нет $note"
				;;
			r)
				if [[ -x "$root/scripts/svc-restart-zapret.sh" ]]; then
					run_cmd_log zapret-restart sudo bash "$root/scripts/svc-restart-zapret.sh"
				else
					msg_err Скрипт "Нет $root/scripts/svc-restart-zapret.sh — настрой Zapret как в официальной инструкции."
				fi
				;;
			L)
				run_cmd_log "ls generated" ls -la "$root/state/generated" 2>/dev/null || msg_err Dir "Нет каталога $root/state/generated"
				;;
			0) break ;;
		esac
	done
}

gen_nginx_conf() {
	local root fr listen proxy passfile out
	fr="${FIREWALL_ROOT%/}"
	root="$REPO_ROOT"
	listen="${LAN_HTTP_IP}:${LAN_HTTP_PORT}"
	proxy="http://${SHELL2HTTP_LISTEN}/"
	out="$fr/state/generated/$NGINX_SITE_NAME.generated.conf"
	mkdir -p "$fr/state/generated" 2>/dev/null || true
	if [[ ! -f "$root/contrib/nginx-dashboard.conf.example" ]]; then
		echo "нет шаблона contrib/nginx-dashboard.conf.example" >&2
		return 1
	fi
	sed \
		-e "s|listen .*;|listen ${listen};|" \
		-e "s|root .*firewall/srv;|root ${fr}/srv;|" \
		-e "s|proxy_pass http://127\.0\.0\.1:8899/|proxy_pass ${proxy}|" \
		-e "s|auth_basic_user_file .*|auth_basic_user_file ${HTPASSWD_FILE};|" \
		"$root/contrib/nginx-dashboard.conf.example" >"$out"
	printf '%s\n' "$out"
}

gen_shell2http_unit() {
	local fr tmpl out
	fr="${FIREWALL_ROOT%/}"
	tmpl="$REPO_ROOT/contrib/shell2http.service.example"
	out="$fr/state/generated/firewall-shell2http.generated.service"
	mkdir -p "$fr/state/generated" 2>/dev/null || true
	sed \
		-e "s|^Environment=FIREWALL_ROOT=.*|Environment=FIREWALL_ROOT=${fr}|" \
		-e "s|^Environment=SHELL2HTTP_LISTEN=.*|Environment=SHELL2HTTP_LISTEN=${SHELL2HTTP_LISTEN}|" \
		-e "s|^Environment=SHELL2HTTP_BIN=.*|Environment=SHELL2HTTP_BIN=/usr/local/bin/shell2http|" \
		"$tmpl" >"$out"
	printf '%s\n' "$out"
}

ui_panel() {
	local h mw ch path
	while true; do
		read -r h mw < <(H 28 78)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[6] Панель (nginx + shell2http)" --menu "\
Браузер: http://${LAN_HTTP_IP}:${LAN_HTTP_PORT}/dashboard/
API loopback: ${SHELL2HTTP_LISTEN}
htpasswd: $HTPASSWD_FILE" "$h" "$mw" 12 \
			"l" "LAN IP (listen nginx)" \
			"p" "HTTP порт nginx (например 8088)" \
			"a" "SHELL2HTTP_LISTEN (127.0.0.1:8899)" \
			"h" "Файл htpasswd (auth_basic_user_file)" \
			"g" "Сгенерировать nginx .conf в state/generated" \
			"u" "Сгенерировать unit firewall-shell2http в state/generated" \
			"I" "Установить unit в /etc/systemd/system (sudo)" \
			"N" "Установить nginx site + nginx -t + reload (sudo)" \
			"w" "Создать htpasswd (через sudo htpasswd)" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			l)
				local v
				v=$(dlg_input listen "IP интерфейса LAN (пример 192.168.50.2):" "$LAN_HTTP_IP") || continue
				LAN_HTTP_IP="$v"
				;;
			p)
				local v
				v=$(dlg_input port "Порт HTTP для дашборда:" "$LAN_HTTP_PORT") || continue
				LAN_HTTP_PORT="${v// /}"
				;;
			a)
				local v
				v=$(dlg_input shell2http "HOST:PORT для shell2http:" "$SHELL2HTTP_LISTEN") || continue
				SHELL2HTTP_LISTEN="$v"
				;;
			h)
				local v
				v=$(dlg_input htpasswd "Путь к файлу паролей:" "$HTPASSWD_FILE") || continue
				HTPASSWD_FILE="$v"
				;;
			g)
				save_state
				if path=$(gen_nginx_conf); then
					msg_ok nginx "Конфиг: $path

Проверьте listen и paths, затем пункт N для копирования в sites-available."
				else
					msg_err nginx "Не удалось сгенерировать (см. FIREWALL_ROOT и шаблон)."
				fi
				;;
			u)
				save_state
				if path=$(gen_shell2http_unit); then
					msg_ok unit "Файл: $path

Пункт I копирует в /etc/systemd/system/"
				else
					msg_err unit "Ошибка генерации."
				fi
				;;
			I)
				save_state
				path="$(gen_shell2http_unit)" || continue
				run_cmd_log "install unit" sudo install -m0644 "$path" /etc/systemd/system/firewall-shell2http.service
				run_cmd_log daemon-reload sudo systemctl daemon-reload
				;;
			N)
				save_state
				path="$(gen_nginx_conf)" || continue
				run_cmd_log "nginx site" bash -lc "set -e; sudo install -m0644 '$path' '/etc/nginx/sites-available/${NGINX_SITE_NAME}.conf'; sudo ln -sf '/etc/nginx/sites-available/${NGINX_SITE_NAME}.conf' '/etc/nginx/sites-enabled/${NGINX_SITE_NAME}.conf'; sudo nginx -t; sudo systemctl reload nginx"
				;;
			w)
				local u p1 p2 log ec
				u=$(dlg_input login "Имя пользователя BasicAuth:" "admin") || continue
				p1=$(dlg_pass пароль "Пароль:") || continue
				p2=$(dlg_pass пароль "Повтор пароля:") || continue
				if [[ "$p1" != "$p2" ]]; then
					msg_err Пароль "Не совпадают"
					continue
				fi
				save_state
				log="$(mktemp)"
				set +e
				if sudo test -f "$HTPASSWD_FILE"; then
					printf '%s\n' "$p1" | sudo htpasswd -i "$HTPASSWD_FILE" "$u" >"$log" 2>&1
				else
					printf '%s\n' "$p1" | sudo htpasswd -ci "$HTPASSWD_FILE" "$u" >"$log" 2>&1
				fi
				ec=$?
				set -e
				p1= p2=
				if [[ "$ec" -ne 0 ]]; then
					msg_err htpasswd "Код $ec: $(cat "$log")"
				else
					msg_ok htpasswd "Запись $HTPASSWD_FILE обновлена (пароль в лог не пишется)."
				fi
				rm -f "$log"
				;;
			0) break ;;
		esac
	done
	save_state
}

ui_system() {
	local h mw ch
	while true; do
		read -r h mw < <(H 22 76)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[7] Система" --menu "Статусы и перезапуски" "$h" "$mw" 9 \
			"a" "status mihomo + firewall-shell2http + nginx" \
			"m" "restart mihomo" \
			"s" "restart firewall-shell2http" \
			"n" "nginx -t" \
			"d" "daemon-reload" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			a)
				local st
				st="$(mktemp)"
				{
					systemctl status mihomo.service --no-pager || true
					echo ""
					systemctl status firewall-shell2http.service --no-pager || true
					echo ""
					systemctl status nginx.service --no-pager || true
				} >"$st" 2>&1
				show_textfile "systemctl status" "$st"
				rm -f "$st"
				;;
			m)
				run_cmd_log restart-mihomo sudo systemctl restart mihomo.service
				;;
			s)
				run_cmd_log restart-sh2http sudo systemctl restart firewall-shell2http.service
				;;
			n)
				run_cmd_log "nginx -t" sudo nginx -t
				;;
			d)
				run_cmd_log daemon-reload sudo systemctl daemon-reload
				;;
			0) break ;;
		esac
	done
}

ui_setup_readme() {
	[[ -f "$REPO_ROOT/SETUP-RU.txt" ]] && show_textfile "SETUP-RU.txt" "$REPO_ROOT/SETUP-RU.txt" ||
		msg_err Файл "Нет $REPO_ROOT/SETUP-RU.txt"
}

ui_strategies() {
	local root scr h mw ch
	root="$(screens_root)"
	scr="$root/scripts"
	local strat_script="$REPO_ROOT/scripts/apply-zapret-strategies.sh"

	while true; do
		read -r h mw < <(H 26 76)

		# Загружаем текущие стратегии
		local current_strats=""
		if [[ -f "$root/state/generated/zapret-strategies.conf" ]]; then
			current_strats="$(cat "$root/state/generated/zapret-strategies.conf")"
		fi
		local desync_mode="soft"
		if [[ -f "$root/state/generated/zapret-desync-mode.txt" ]]; then
			desync_mode="$(cat "$root/state/generated/zapret-desync-mode.txt")"
		fi

		local strats_menu
		if [[ -n "$current_strats" ]]; then
			strats_menu="Стратегии: $current_strats | desync: $desync_mode"
		else
			strats_menu="Стратегии не заданы | desync: $desync_mode"
		fi

		ch=$(dialog --backtitle "$BACKTITLE" --title "[9] Стратегии запрета DPI" --menu "\
$strats_menu

Аналог zapret для Windows (QUIC, TCP-seg, MD5 и др.)
Можно комбинировать несколько стратегий через запятую.
Сгенерирует параметры для nfqws/tpws." "$h" "$mw" 10 \
			"s" "Выбрать стратегии (checklist — несколько сразу)" \
			"d" "Режим desync (soft|hard|fake|disorder|dataseq|block)" \
			"g" "Сгенерировать конфиг (параметры nfqws)" \
			"a" "Применить стратегии (если zapret установлен)" \
			"l" "Справка: доступные стратегии" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			s)
				if [[ ! -x "$strat_script" ]]; then
					msg_err "Скрипт" "$strat_script не найден или не исполняемый"
					continue
				fi
				# Собираем checklist из всех доступных стратегий
				local all_strats=("quic" "tcp-seg" "md5" "host-fake" "fake-http" "fake-tls" "split" "badseq" "disorder" "dataseq" "block")
				local chk_cmd=("dialog" "--backtitle" "$BACKTITLE" "--title" "Стратегии запрета" "--checklist" "Выберите стратегии (пробел — выбрать/снять):" "18" "56" "11")

				for s in "${all_strats[@]}"; do
					local state="off"
					# Проверяем, выбрана ли стратегия
					if echo "$current_strats" | grep -q "$s"; then
						state="on"
					fi
					chk_cmd+=("$s" "Стратегия $s" "$state")
				done

				local chk_result
				chk_result="$("${chk_cmd[@]}" 3>&1 1>&2 2>&3)" || continue
				# dialog возвращает строки через пробел
				local strat_list
				strat_list="$(echo "$chk_result" | tr ' ' ',' | sed 's/,,*/,/g; s/^,//; s/,$//')"
				if [[ -n "$strat_list" ]]; then
					save_state
					run_cmd_log "Установка стратегий" sudo bash "$strat_script" --set "$strat_list"
				else
					msg_ok "Стратегии" "Ничего не выбрано"
				fi
				;;
			d)
				local dm
				dm=$(dialog --backtitle "$BACKTITLE" --title "Режим desync" --radiolist \
					"Выберите режим десинхронизации DPI" 16 46 7 \
					soft "Мягкий (дефолт)" $([[ "$desync_mode" == "soft" ]] && echo on || echo off) \
					hard "Жёсткий" $([[ "$desync_mode" == "hard" ]] && echo on || echo off) \
					fake "Фейковый ответ" $([[ "$desync_mode" == "fake" ]] && echo on || echo off) \
					disorder "Перестановка disorder2" $([[ "$desync_mode" == "disorder" ]] && echo on || echo off) \
					dataseq "Последовательность данных" $([[ "$desync_mode" == "dataseq" ]] && echo on || echo off) \
					block "Блокировка" $([[ "$desync_mode" == "block" ]] && echo on || echo off) \
					3>&1 1>&2 2>&3) || continue
				save_state
				if [[ -x "$strat_script" ]]; then
					run_cmd_log "Установка desync" sudo bash "$strat_script" --desync "$dm"
				else
					mkdir -p "$root/state/generated"
					printf '%s' "$dm" > "$root/state/generated/zapret-desync-mode.txt"
					msg_ok "Desync" "Режим сохранён: $dm (скрипт $strat_script не найден)"
				fi
				;;
			g)
				if [[ -x "$strat_script" ]]; then
					run_cmd_log "Генерация конфига" sudo bash "$strat_script" --apply
				else
					msg_err "Скрипт" "$strat_script не найден"
				fi
				;;
			a)
				if [[ -x "$strat_script" ]]; then
					run_cmd_log "Применение стратегий" sudo bash "$strat_script" --apply
				else
					msg_err "Скрипт" "$strat_script не найден"
				fi
				;;
			l)
				if [[ -x "$strat_script" ]]; then
					local help_out
					help_out="$(mktemp)"
					bash "$strat_script" --list >"$help_out" 2>&1
					show_textfile "Стратегии — справка" "$help_out"
					rm -f "$help_out"
				else
					msg_err "Скрипт" "$strat_script не найден"
				fi
				;;
			0) break ;;
		esac
	done
}

ui_detect_bypass() {
	local root h mw ch
	root="$(screens_root)"
	local detect_script="$REPO_ROOT/scripts/detect-bypass.sh"

	while true; do
		read -r h mw < <(H 20 74)
		ch=$(dialog --backtitle "$BACKTITLE" --title "[A] Проверка обхода блокировок" --menu "\
Проверка, работают ли меры обхода (zapret, Mihomo, VPN)
Детектирование доступности заблокированных сайтов" "$h" "$mw" 7 \
			"q" "Быстрая проверка (только заблокированные сайты)" \
			"f" "Полная проверка (механизмы + DNS + traceroute)" \
			"d" "Только DNS" \
			"m" "Детектирование механизмов обхода" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			q)
				if [[ -x "$detect_script" ]]; then
					run_cmd_log "Быстрая проверка" sudo bash "$detect_script" --quick
				else
					msg_err "Скрипт" "$detect_script не найден"
				fi
				;;
			f)
				if [[ -x "$detect_script" ]]; then
					run_cmd_log "Полная проверка" sudo bash "$detect_script" --full --verbose
				else
					msg_err "Скрипт" "$detect_script не найден"
				fi
				;;
			d)
				if [[ -x "$detect_script" ]]; then
					run_cmd_log "DNS проверка" sudo bash "$detect_script" --dns-only
				else
					msg_err "Скрипт" "$detect_script не найден"
				fi
				;;
			m)
				if [[ -x "$detect_script" ]]; then
					run_cmd_log "Механизмы" sudo bash "$detect_script" --full 2>&1 | head -n 30 || true
				else
					msg_err "Скрипт" "$detect_script не найден"
				fi
				;;
			0) break ;;
		esac
	done
}

ui_vpn() {
	local root h mw ch
	root="$(screens_root)"
	local vpn_up_script="$REPO_ROOT/scripts/vpn-up.sh"
	local vpn_down_script="$REPO_ROOT/scripts/vpn-down.sh"
	local vpn_status_script="$REPO_ROOT/scripts/vpn-status.sh"

	while true; do
		read -r h mw < <(H 22 76)

		# Получаем статус VPN
		local vpn_status_text=""
		if [[ -x "$vpn_status_script" ]]; then
			vpn_status_text="$(sudo bash "$vpn_status_script" 2>/dev/null | head -n 3 | tr '\n' ' ' || echo "статус недоступен")"
		fi

		ch=$(dialog --backtitle "$BACKTITLE" --title "[B] VPN (WireGuard/OpenVPN)" --menu "\
Текущий статус: ${vpn_status_text:-проверьте статус}

Управление VPN-соединениями через WireGuard или OpenVPN
WireGuard предпочтительнее (выше скорость, ниже latency)." "$h" "$mw" 8 \
			"u" "Поднять VPN (up)" \
			"d" "Опустить VPN (down)" \
			"s" "Статус VPN" \
			"p" "Выбрать протокол (wireguard/openvpn)" \
			"c" "Указать путь к конфигу" \
			"0" "Назад" \
			3>&1 1>&2 2>&3) || break
		case "$ch" in
			u)
				if [[ -x "$vpn_up_script" ]]; then
					run_cmd_log "VPN UP" sudo bash "$vpn_up_script"
				else
					msg_err "Скрипт" "$vpn_up_script не найден"
				fi
				;;
			d)
				if [[ -x "$vpn_down_script" ]]; then
					run_cmd_log "VPN DOWN" sudo bash "$vpn_down_script"
				else
					msg_err "Скрипт" "$vpn_down_script не найден"
				fi
				;;
			s)
				if [[ -x "$vpn_status_script" ]]; then
					run_cmd_log "VPN статус" sudo bash "$vpn_status_script" --proto all
				else
					msg_err "Скрипт" "$vpn_status_script не найден"
				fi
				;;
			p)
				local proto
				proto=$(dialog --backtitle "$BACKTITLE" --title "Протокол VPN" --radiolist \
					"Выберите протокол" 12 46 2 \
					wireguard "WireGuard (предпочтительно)" on \
					openvpn "OpenVPN" off \
					3>&1 1>&2 2>&3) || continue
				save_state
				# Сохраняем в state-файл
				mkdir -p "$root/state/generated"
				printf '%s' "$proto" > "$root/state/generated/vpn-proto.txt"
				msg_ok "VPN" "Протокол изменён на: $proto"
				;;
			c)
				local cfg
				cfg=$(dlg_input "VPN конфиг" "Полный путь к конфигу WireGuard/OpenVPN:" "${VPN_CONFIG:-}") || continue
				if [[ -f "$cfg" ]]; then
					mkdir -p "$root/state/generated"
					printf '%s' "$cfg" > "$root/state/generated/vpn-config.txt"
					msg_ok "VPN" "Конфиг: $cfg"
				else
					msg_err "Файл" "Файл $cfg не найден"
				fi
				;;
			0) break ;;
		esac
	done
}

main() {
	require_dialog
	load_state

	while true; do
		local pick
		pick="$(main_menu_pick)" || break
		case "$pick" in
			0) exit 0 ;;
			1) ui_general ;;
			2) ui_install_run ;;
			3) ui_lists_menu ;;
			4) ui_mihomo ;;
			5) ui_zapret ;;
			6) ui_panel ;;
			7) ui_system ;;
			8) ui_setup_readme ;;
			9) ui_strategies ;;
			A|a) ui_detect_bypass ;;
			B|b) ui_vpn ;;
			*)
				msg_err Меню "Неизвестный пункт: $pick"
				;;
		esac
	done
}

main "$@"
