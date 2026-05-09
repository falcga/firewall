# copy repo into FIREWALL_ROOT excluding .git
copy_into_root() {
	fr="${FIREWALL_ROOT%/}/"
	ds="$SCRIPT_DIR"
	_exe mkdir -p "$fr"
	if command -v rsync >/dev/null 2>&1; then
		_exe rsync -a "${ds%/}/" "$fr" --exclude /.git \
			--exclude '*.Zone.Identifier' --exclude '*.Identifier'
	elif command -v tar >/dev/null 2>&1; then

		_exe sh -c "cd \"${ds%/}\" && tar cf - ./ --exclude=./.git \
			--exclude=./*.Zone.Identifier | tar -C \"${fr%/}\" -xf -"
	else die rsync-or-tar-missing; fi
}

chmod_local() {
	fr="${FIREWALL_ROOT%/}"

	_exe chmod +x "${fr%/}/contrib/pick_github_asset.py" "${fr%/}/contrib/shell2http-launcher.sh" "${fr%/}/install.sh" 2>/dev/null || true
	_exe find "${fr%/}/scripts" "${fr%/}/contrib" "${fr%/}/contrib/install/parts" -maxdepth 1 -type f -name '*.sh' -exec chmod +x '{}' '+'


}

























