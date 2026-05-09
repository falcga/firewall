test -z "${SCRIPT_DIR:-}" && {
	echo >&2 "SCRIPT_DIR must be set before loading driver."
	exit 1
}

. "${SCRIPT_DIR}/contrib/install/parts/01-deps.sh"


. "${SCRIPT_DIR}/contrib/install/parts/02-sync-tree.sh"
. "${SCRIPT_DIR}/contrib/install/parts/03-download-bins.sh"
. "${SCRIPT_DIR}/contrib/install/parts/04-services.sh"


. "${SCRIPT_DIR}/contrib/install/parts/05-main.sh"
