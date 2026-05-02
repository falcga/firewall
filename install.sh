#!/bin/sh
set -eu
fatal(){ printf '%s\n' "$1" >&2; exit 1; }
show_help(){
	printf '%s\n' "sudo ./install.sh [-r|--root|--firewall-root DIR] [-h|--help]" "-r DIR  install/copy target (default FIREWALL_ROOT=/opt/firewall)" "Unset SUBSCRIPTION_URL in env triggers interactive prompt (stdin or /dev/tty)." >&2
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


. "${FW_ROOT}/contrib/install/driver.sh"


main_install



