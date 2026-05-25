main_install() {

	log "main_install: starting (FIREWALL_ROOT=$FIREWALL_ROOT, DRY_RUN=${DRY_RUN:-0})"

	export DEBIAN_FRONTEND=noninteractive

	detect_pkg
	log "detected PACKAGETYPE=$PACKAGETYPE"

	test -n "$PACKAGETYPE" || { cat /etc/os-release 2>/dev/null || true; die "unsupported distro"; }

	ensure_packages
	copy_into_root
	chmod_local
	if test "${SKIP_BINARIES:-0}" = "1"; then log "download_bins: skipped"; else download_bins; fi
	write_secret
	if test "${SKIP_SYSTEMD:-0}" = "1"; then log "install_systemd: skipped"; else install_systemd_snippets; fi
	if test "${SKIP_SYNC:-0}" = "1"; then log "first_sync_bundle: skipped"; else first_sync_bundle; fi
	install_firewall_cli

	_exe mkdir -p "${FIREWALL_ROOT%/}/logs"

	echo ""
	echo "=== INSTALL COMPLETE ==="
	echo "FIREWALL_ROOT=$FIREWALL_ROOT"
	echo "Full log: $INSTALL_LOG"
	echo "Next: sudo firewall start"
	echo ""
}

