# utils + distro packages

# --- logging ---
# Use a temporary log file until FIREWALL_ROOT is created by copy_into_root.
# After tree sync, the log is moved into FIREWALL_ROOT so it survives /tmp cleanup.
INSTALL_LOG="${INSTALL_LOG:-}"
if test -z "$INSTALL_LOG"; then
	INSTALL_LOG=/tmp/firewall-install.$$.log
	_LOG_MOVED=0
else
	_LOG_MOVED=1
fi
# INSTALL_LOG_DIR="$(dirname "$INSTALL_LOG")"
# mkdir -p "$INSTALL_LOG_DIR" 2>/dev/null || true

# current timestamp for log lines
_now(){ date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "???"; }

# write to both stderr and logfile
_llog(){ local ts; ts="$(_now)"; printf '[%s] %s\n' "$ts" "$*" | tee -a "$INSTALL_LOG" >&2; }

# Call after copy_into_root to move the log into FIREWALL_ROOT
_move_log(){
	local final_log="${FIREWALL_ROOT%/}/firewall-install.log"
	_exe mkdir -p "$(dirname "$final_log")" 2>/dev/null || true
	_exe mv "$INSTALL_LOG" "$final_log" 2>/dev/null || true
	INSTALL_LOG="$final_log"
	_LOG_MOVED=1
}

die(){ _llog "FATAL: $*"; echo >&2 "FULL LOG: $INSTALL_LOG"; exit 1; }
log(){ _llog "INFO: $*"; }

# trap any command failure — (DISABLED FOR DEBUGGING) log and show context
# _on_err(){ local rc=$? line=$1; _llog "ERROR: command failed at line $line (exit=$rc)"; }
# trap '_on_err $LINENO' ERR || true

# Download with retry and IPv4 fallback for unreliable networks.
# curl → wget → python urllib (retries with -4 flag).
if command -v curl >/dev/null 2>&1; then
	Download(){
		local url="$1" out="$2"
		# -L = follow redirects (needed for GitLab, SourceForge etc.)
		# Include Accept header for GitLab Generic Package Registry
		curl -fSL --connect-timeout 15 --retry 3 --retry-delay 5 \
			-L -A "firewall-installer" \
			-H "Accept: application/octet-stream" \
			"$url" -o "$out" 2>/dev/null ||
		curl -fSL4 --connect-timeout 15 --retry 3 --retry-delay 5 \
			-L -A "firewall-installer" \
			-H "Accept: application/octet-stream" \
			"$url" -o "$out" 2>/dev/null ||
		{ rm -f "$out"; false; }
	}
elif command -v wget >/dev/null 2>&1; then
	Download(){
		local url="$1" out="$2"
		wget -q --timeout=15 --tries=3 \
			--header="Accept: application/octet-stream" \
			-U "firewall-installer" \
			"$url" -O "$out" 2>/dev/null ||
		wget -q -4 --timeout=15 --tries=3 \
			--header="Accept: application/octet-stream" \
			-U "firewall-installer" \
			"$url" -O "$out" 2>/dev/null ||
		{ rm -f "$out"; false; }
	}
else
	Download(){
		# python urllib as last resort (uses system CA bundle, IPv4 by default)
		local url="$1" out="$2" rc=0
		python3 -c "
import urllib.request, sys
try:
    req = urllib.request.Request('$url', headers={'Accept': 'application/octet-stream', 'User-Agent': 'firewall-installer'})
    r = urllib.request.urlopen(req, timeout=60)
    with open('$out', 'wb') as f: f.write(r.read())
except Exception as e:
    sys.exit(1)
" 2>/dev/null && return 0
		rm -f "$out"
		return 1
	}
fi

_exe(){
	if [ "${DRY_RUN:-0}" = "1" ]; then echo "+ $*"; return 0; fi
	if [ "$(id -u)" = "0" ]; then "$@"; else sudo "$@"; fi
}
PACKAGETYPE=""
detect_pkg(){
	PACKAGETYPE=""
	test -f /etc/os-release || return 0
	. /etc/os-release || return 0

	case "${ID:-}" in
	ubuntu|pop|neon|zorin|elementary|raspbian|tuxedo|osmc|sparky|debian|pureos|kaisen|linuxmint|mendel|parrot|pika) PACKAGETYPE=apt ;;
	fedora|nobara|bazzite|openmandriva|sangoma|alinux|cloudlinux|rocky|almalinux) PACKAGETYPE=dnf ;;
	centos|ol|oracle|rhel)
		X="${VERSION_ID%%.*}"
		case "${X:-x}" in 7) PACKAGETYPE=yum ;; *) PACKAGETYPE=dnf ;; esac ;;
	amzn|amazon*) PACKAGETYPE=yum ;;
	photon|vmwarePhoton*) PACKAGETYPE=tdnf ;;
	arch|archarm|endeavouros|blendos|garuda|archcraft|cachyos) PACKAGETYPE=pacman ;;
	manjaro|manjaro-arm|biglinux) PACKAGETYPE=pacman ;;
	alpine) PACKAGETYPE=apk ;;
	postmarket*) PACKAGETYPE=apk ;;
	opensuse-leap|opensuse-tumbleweed|sles) PACKAGETYPE=zypper ;;
	sle-micro*) PACKAGETYPE=zypper ;;
	openwrt|turrisos|istoreos) PACKAGETYPE=opkg ;;
	esac
	test -f /opt/etc/entware_release && PACKAGETYPE=opkg
}

ensure_packages() {
	case "$PACKAGETYPE" in
	apt)
		_exe apt-get update
		_exe apt-get install -y ca-certificates curl python3 nftables iptables nginx apache2-utils tar gzip xz-utils coreutils
		;;
	dnf) _exe dnf install -y ca-certificates curl python3 nftables iptables nginx httpd-tools tar gzip xz ;;
	yum) _exe yum install -y ca-certificates curl python3 nftables iptables nginx httpd-tools tar gzip xz ;;
	tdnf) _exe tdnf install -y ca-certificates curl python3 nftables iptables nginx httpd-tools tar gzip xz ;;
	pacman) _exe pacman -Sy --needed --noconfirm ca-certificates curl python nftables iptables nginx httpd tar gzip xz ;;
	apk) _exe apk add --no-cache ca-certificates curl python3 nftables iptables nginx apache2-utils openssl tar xz gzip ;;
	zypper) _exe zypper --non-interactive install -y ca-certificates curl python3 nftables iptables nginx apache-utils tar gzip xz ;;
	opkg)
		_exe opkg update
		_exe opkg install ca-bundle curl python3-light python3-asyncio xz-utils tar nftables iptables openssl-util nginx-ssl
		;;
	*) die "unsupported packager=[$PACKAGETYPE]" ;;
	esac
}

