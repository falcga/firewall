main_install() {

	log "main_install: starting (FIREWALL_ROOT=$FIREWALL_ROOT, DRY_RUN=${DRY_RUN:-0})"

	export DEBIAN_FRONTEND=noninteractive


	detect_pkg
	log "detected PACKAGETYPE=$PACKAGETYPE"

	test -n "$PACKAGETYPE" || { cat /etc/os-release 2>/dev/null || true; die "unsupported distro"; }
	log "ensure_packages: start"
	ensure_packages
	log "ensure_packages: done"
	log "copy_into_root: start"
	copy_into_root
	log "copy_into_root: done"
	chmod_local
	log "chmod_local: done"
	if test "${SKIP_BINARIES:-0}" = "1"; then log "download_bins: skipped"; else log "download_bins: start"; download_bins; log "download_bins: done"; fi
	write_secret
	log "write_secret: done"
	if test "${SKIP_SYSTEMD:-0}" = "1"; then log "install_systemd: skipped"; else log "install_systemd_snippets: start"; install_systemd_snippets; log "install_systemd_snippets: done"; fi
	if test "${SKIP_SYNC:-0}" = "1"; then log "first_sync_bundle: skipped"; else log "first_sync_bundle: start"; first_sync_bundle; log "first_sync_bundle: done"; fi
	install_firewall_cli
	log "install_firewall_cli: done"

	log "Creating logs directory..."
	_exe mkdir -p "${FIREWALL_ROOT%/}/logs"
	log "logs directory created."

	echo ""
	echo "=== INSTALL COMPLETE ==="
	echo "FIREWALL_ROOT=$FIREWALL_ROOT"
	log "DONE: FIREWALL_ROOT=$FIREWALL_ROOT"
	echo "Full log: $INSTALL_LOG"
	echo "Next: sudo firewall start"
	echo ""
}

