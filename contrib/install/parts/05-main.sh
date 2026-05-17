main_install() {


	export DEBIAN_FRONTEND=noninteractive


	detect_pkg


	test -n "$PACKAGETYPE" || { cat /etc/os-release 2>/dev/null || true; die "unsupported distro"; }
	ensure_packages
	copy_into_root
	chmod_local
	test "${SKIP_BINARIES:-0}" = "1" || download_bins
	write_secret
	test "${SKIP_SYSTEMD:-0}" = "1" || install_systemd_snippets
	test "${SKIP_SYNC:-0}" = "1" || first_sync_bundle
	install_firewall_cli
	echo "DONE: FIREWALL_ROOT=$FIREWALL_ROOT docs=SETUP-RU.txt dashboard=contrib/nginx-dashboard.conf.example"
}

