#!/bin/sh
# Удалённая установка: git clone → install.sh (-r FIREWALL_ROOT).
# Вызывается через curl/wget однострочником — см. README.md.
#
# Обязательно:
#   SUBSCRIPTION_URL  — HTTPS URL подписки Clash/Mihomo
#   FIREWALL_REPO_URL — clone URL (.git HTTPS или SSH)
#
# Полезное:
#   FIREWALL_CLONE=/tmp/fw        каталог clone (переиспользуется если это git-репа)
#   FIREWALL_ROOT=/opt/firewall   каталог установки (--root install.sh)
#   FIREWALL_BRANCH=main          ветка (пусто = ветка по умолчанию у remote)
#   SKIP_BINARIES=1 SKIP_SYNC=1 SKIP_SYSTEMD=1 DRY_RUN=1  — см. ./install.sh -h

set -eu

die() {
	printf '%s\n' "$*" >&2
	exit 1
}

[ -n "${SUBSCRIPTION_URL:-}" ] ||
	die 'Задайте SUBSCRIPTION_URL (URL подписки вида https://...)'

[ -n "${FIREWALL_REPO_URL:-}" ] ||
	die 'Задайте FIREWALL_REPO_URL (например https://github.com/you/firewall.git)'

CLONE="${FIREWALL_CLONE:-/tmp/fw}"
ROOT="${FIREWALL_ROOT:-/opt/firewall}"
BRANCH="${FIREWALL_BRANCH-}"

command -v git >/dev/null 2>&1 || die 'Установите git: apt-get install -y git'

if [ -d "$CLONE/.git" ]; then
	printf '%s\n' "--- remote-install: reuse clone $CLONE" >&2
	git -C "$CLONE" remote set-url origin "$FIREWALL_REPO_URL"
	if [ -n "$BRANCH" ]; then
		git -C "$CLONE" fetch --depth 1 origin "$BRANCH" \
			|| git -C "$CLONE" fetch origin "$BRANCH"
		git -C "$CLONE" checkout -B "$BRANCH" FETCH_HEAD \
			|| git -C "$CLONE" reset --hard FETCH_HEAD \
			|| die "Не удалось перейти на $BRANCH после fetch"
	else
		git -C "$CLONE" fetch --depth 1 origin || git -C "$CLONE" fetch origin
		git -C "$CLONE" pull --ff-only 2>/dev/null || git -C "$CLONE" merge --ff-only FETCH_HEAD || true
	fi
else
	[ ! -e "$CLONE" ] || die "$CLONE уже существует и не является git clone — удалите каталог или задайте другой FIREWALL_CLONE"
	parent=$(dirname "$CLONE")
	[ -d "$parent" ] || mkdir -p "$parent"
	if [ -n "$BRANCH" ]; then
		git clone --depth 1 -b "$BRANCH" "$FIREWALL_REPO_URL" "$CLONE"
	else
		git clone --depth 1 "$FIREWALL_REPO_URL" "$CLONE"
	fi
fi

[ -x "$CLONE/install.sh" ] || chmod +x "$CLONE/install.sh" 2>/dev/null || true
[ -f "$CLONE/install.sh" ] || die "Нет install.sh в $CLONE после clone"

export SUBSCRIPTION_URL
export SKIP_BINARIES="${SKIP_BINARIES:-0}"
export SKIP_SYNC="${SKIP_SYNC:-0}"
export SKIP_SYSTEMD="${SKIP_SYSTEMD:-0}"
export DRY_RUN="${DRY_RUN:-0}"

exec /bin/sh "$CLONE/install.sh" -r "$ROOT"
