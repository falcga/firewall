#!/bin/sh
# Firewall stack installer wrapper. Logic: contrib/install/driver.sh
#
# Env: FIREWALL_ROOT=/opt/firewall SUBSCRIPTION_URL=...
#      DRY_RUN=1 SKIP_BINARIES=1 SKIP_SYNC=1 SKIP_SYSTEMD=1 SKIP_NGINX_HELPER=1
#
set -eu
CDPATH=: FW_ROOT=""
FW_ROOT="$(cd "$(dirname "$0")" && pwd)" || {
	echo >&2 dirname
	exit 1
}
FW_ROOT="$(printf '%s' "$FW_ROOT" | sed 's,/$,,')"
export FW_ROOT FIREWALL_ROOT="${FIREWALL_ROOT:-/opt/firewall}"
SCRIPT_DIR="$FW_ROOT"
export SCRIPT_DIR
. "${FW_ROOT}/contrib/install/driver.sh"
main_install
