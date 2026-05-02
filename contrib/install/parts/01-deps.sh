# utils + distro packages
die(){ echo >&2 "$*"; exit 1; }
log(){ echo >&2 "--- $*"; }
if command -v curl >/dev/null 2>&1; then Download(){ curl -fsSL "$1" -o "$2"; }
elif command -v wget >/dev/null 2>&1; then Download(){ wget -q "$1" -O "$2"; }
else die "Need curl or wget"; fi
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


























