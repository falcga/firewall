write_secret() {
	sk="${FIREWALL_ROOT%/}/secrets/subscription.url"
	_exe mkdir -p "${FIREWALL_ROOT%/}/secrets"
	if ! _exe test -f "$sk"; then
		if [ -n "${SUBSCRIPTION_URL:-}" ]; then
			printf '%s\n' "$SUBSCRIPTION_URL" | _exe tee "$sk" >/dev/null
		elif _exe test -f "${SCRIPT_DIR}/contrib/subscription.url.example"; then
			_exe cp "${SCRIPT_DIR}/contrib/subscription.url.example" "$sk"

		else printf 'https://CHANGE_ME\n' | _exe tee "$sk" >/dev/null; fi
	fi
	_exe chmod 600 "$sk" 2>/dev/null || true
}


install_systemd_snippets() {


	command -v systemctl >/dev/null 2>&1 || { log "no systemctl"; return 0; }




	FR="${FIREWALL_ROOT%/}"


	test -f "$FR/contrib/shell2http.service.example" || return 0


	_exe sed "s|^Environment=FIREWALL_ROOT=.*|Environment=FIREWALL_ROOT=${FR}|" \
		"$FR/contrib/shell2http.service.example" \
		| _exe tee /etc/systemd/system/firewall-shell2http.service >/dev/null


	_exe tee /etc/systemd/system/mihomo.service >/dev/null << UNIT
[Unit]
Description=Mihomo (Clash Meta) gateway




After=network-online.target




[Service]
Type=simple
User=root
WorkingDirectory=${FR}/state/mihomo




ExecStart=/usr/local/bin/mihomo -d ${FR}/state/mihomo -f config.yaml
Restart=on-failure
[Install]
WantedBy=multi-user.target
UNIT
	_exe systemctl daemon-reload >/dev/null 2>&1 || true
}


first_sync_bundle() {


	fr="${FIREWALL_ROOT%/}"






	_exe "${fr}/scripts/sync-zapret-lists-upstream.sh"
	_exe "${fr}/scripts/sync-geodat.sh"
	_exe "${fr}/scripts/build-lists.sh"
	if _exe grep -Eq '^https?://' "${fr}/secrets/subscription.url" 2>/dev/null; then
		_exe "${fr}/scripts/gen-mihomo-config.sh" || log gen-mihomo-failed
	fi
}
