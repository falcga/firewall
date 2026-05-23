#!/bin/bash
# Firewall stack installer wrapper. Logic: contrib/install/driver.sh
#
# Env: FIREWALL_ROOT=/opt/firewall SUBSCRIPTION_URL=...
#      DRY_RUN=1 SKIP_BINARIES=1 SKIP_SYNC=1 SKIP_SYSTEMD=1 SKIP_NGINX_HELPER=1
#      INSTALL_LOG=/var/log/firewall-install.log (default)
#

# For debugging - disable set -e and enable set -x
# set -eo pipefail
set -x

CDPATH=: FW_ROOT=""
FW_ROOT="$(cd "$(dirname "$0")" && pwd)" || {
	echo >&2 dirname
	exit 1
}
FW_ROOT="$(printf '%s' "$FW_ROOT" | sed 's,/$,,')"
export FW_ROOT FIREWALL_ROOT="${FIREWALL_ROOT:-/opt/firewall}"
SCRIPT_DIR="$FW_ROOT"
export SCRIPT_DIR

# --- log everything ---
INSTALL_LOG="${INSTALL_LOG:-${FW_ROOT}/firewall-install.log}"

echo "=== firewall install started $(date -Iseconds 2>/dev/null || date) ===" >&2
echo "FIREWALL_ROOT=$FIREWALL_ROOT" >&2
echo "log: $INSTALL_LOG" >&2
echo "" >&2

. "${FW_ROOT}/contrib/install/driver.sh"
main_install
