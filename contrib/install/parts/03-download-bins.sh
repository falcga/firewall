gh_pick(){ python3 "${SCRIPT_DIR}/contrib/pick_github_asset.py" "$@"; }


download_bins() {

	case "$(uname -m)" in aarch64|arm64) T=mihomo-linux-arm64-; S=".gz"; ST="_linux_arm64.tar.gz";;
	x86_64|amd64) T=mihomo-linux-amd64-v; S=".gz"; ST="_linux_amd64.tar.gz";;
	arm*) T=mihomo-linux-armv7-; S=".gz"; ST="_linux_armv6.tar.gz";;
	*) die "unknown-arch-SKIP_BINARIES=1";; esac
	mu="$(gh_pick MetaCubeX mihomo "$T" "$S")" || die pick-mihomo
	test -n "$mu" || die empty-mihomo-url
	hu="$(gh_pick msoap shell2http shell2http "$ST")" || die pick-sh2
	td="$(mktemp -d)"; trap 'rm -rf "$td"' EXIT INT
	log mihomo; Download "$mu" "$td/a.gz" || die "download-mihomo-failed"

	if test -f "$td/a.gz"; then
		gzip -dc "$td/a.gz" >"$td/mihomo" 2>/dev/null ||
		gunzip -c "$td/a.gz" >"$td/mihomo" 2>/dev/null ||
		die gunzip-mihomo
	fi
	_exe install -m0755 "$td/mihomo" /usr/local/bin/mihomo
	log shell2http; Download "$hu" "$td/s.tgz" || die "download-shell2http-failed"

	test -f "$td/s.tgz" && tar xzf "$td/s.tgz" -C "$td" 2>/dev/null || die untar-shell2http


	b=""
	b="$(find "$td" -maxdepth 3 -type f -name shell2http 2>/dev/null | head -n 1)"
	test -n "$b" -a -f "$b" || die "no shell2http in archive"


	_exe install -m0755 "$b" /usr/local/bin/shell2http
}
