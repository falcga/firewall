#!/bin/bash
# Firewall stack installer wrapper. Logic: contrib/install/driver.sh
#
# Env: FIREWALL_ROOT=/opt/firewall SUBSCRIPTION_URL=...
#      DRY_RUN=1 SKIP_BINARIES=1 SKIP_SYNC=1 SKIP_SYSTEMD=1 SKIP_NGINX_HELPER=1
#      INSTALL_LOG=/var/log/firewall-install.log (default)
#
set -eo pipefail
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
INSTALL_LOG="${INSTALL_LOG:-/var/log/firewall-install.log}"
INSTALL_LOG_DIR="$(dirname "$INSTALL_LOG")"
mkdir -p "$INSTALL_LOG_DIR" 2>/dev/null || true

# Redirect stdout+stderr to both console and log file
exec > >(tee -a "$INSTALL_LOG") 2>&1
echo "=== firewall install started $(date -Iseconds 2>/dev/null || date) ==="
echo "FIREWALL_ROOT=$FIREWALL_ROOT"
echo "log: $INSTALL_LOG"
echo ""

. "${FW_ROOT}/contrib/install/driver.sh"
main_install
