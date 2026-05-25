gh_pick(){ python3 "${SCRIPT_DIR}/contrib/pick_github_asset.py" "$@"; }

# Get the latest version tag from a GitHub release (e.g. v1.19.25).
# Uses a lightweight HEAD request to avoid downloading the full asset list.
gh_latest_version(){
	local owner="$1" repo="$2"
	python3 -c "
import json, urllib.request, sys
try:
    r = urllib.request.urlopen('https://api.github.com/repos/$owner/$repo/releases/latest', timeout=30)
    data = json.load(r)
    tag = data.get('tag_name', '')
    # strip leading 'v' if present for cleaner version
    print(tag)
except Exception:
    sys.exit(1)
" 2>/dev/null || {
	# fallback: try extracting from gh_pick result
	local url; url="$(gh_pick "$owner" "$repo" "x" "x" 2>/dev/null)" || return 1
	# extract version like v1.2.3 or 1.2.3 from the url
	printf '%s' "$url" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1
}
}

# Resolve final download URL for a binary with optional mirror override.
# Mirror URL supports template variables:
#   {version}  — latest version tag from GitHub (e.g. v1.19.25)
#   {arch}     — current machine architecture (arm64, amd64, armv7, armv6)
#   {bin}      — binary name (mihomo, shell2http)
#   {suffix}   — file extension suffix (e.g. .gz, .tar.gz)
#
# Usage: bin_url BIN_NAME GH_OWNER GH_REPO TOKEN_IN_NAME SUFFIX
# Order of precedence (first non-empty wins):
#   1. env var:  ${BIN_NAME}_MIRROR_URL_$(uname -m | tr '[:lower:]' '[:upper:]')
#   2. env var:  ${BIN_NAME}_MIRROR_URL   (e.g. MIHOMO_MIRROR_URL)
#   3. github picker
bin_url(){
	local bin="$1" owner="$2" repo="$3" token="$4" suffix="$5"
	local arch_mirror_var; arch_mirror_var="${bin}_MIRROR_URL_$(uname -m | tr '[:lower:]' '[:upper:]')"
	local mirror_var="${bin}_MIRROR_URL"
	local url="" version="" arch=""

	# 1. arch-specific mirror
	eval "url=\"\${$arch_mirror_var:-}\""
	# 2. generic mirror
	test -z "$url" && eval "url=\"\${$mirror_var:-}\""

	# If mirror URL contains template variables — resolve them
	if test -n "$url" && printf '%s' "$url" | grep -qE '\{version\}|\{arch\}|\{bin\}|\{suffix\}'; then
		# get current architecture shorthand
		case "$(uname -m)" in
			aarch64|arm64) arch=arm64 ;;
			x86_64|amd64)  arch=amd64 ;;
			armv7l|armv7)   arch=armv7 ;;
			armv6l|armv6)   arch=armv6 ;;
			*) arch="$(uname -m)" ;;
		esac
		# fetch latest version from GitHub if {version} is in the template
		if printf '%s' "$url" | grep -q '{version}'; then
			version="$(gh_latest_version "$owner" "$repo")" || {
				# fallback: try gh_pick and extract version from URL
				local fallback_url; fallback_url="$(gh_pick "$owner" "$repo" "$token" "$suffix" 2>/dev/null)" || return 1
				version="$(printf '%s' "$fallback_url" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
				test -n "$version" || return 1
			}
		fi
		# substitute templates
		url="$(printf '%s' "$url" \
			| sed "s|{version}|${version}|g" \
			| sed "s|{arch}|${arch}|g" \
			| sed "s|{bin}|${bin,,}|g" \
			| sed "s|{suffix}|${suffix}|g")"
	fi

	# 3. github (if no mirror URL or template resolution failed)
	if test -z "$url"; then
		url="$(gh_pick "$owner" "$repo" "$token" "$suffix")" || return 1
		test -n "$url" || return 1
	fi
	printf '%s' "$url"
}


download_bins() {

	case "$(uname -m)" in aarch64|arm64) T=mihomo-linux-arm64-; S=".gz"; ST="_linux_arm64.tar.gz";;
	x86_64|amd64) T=mihomo-linux-amd64-v; S=".gz"; ST="_linux_amd64.tar.gz";;
	arm*) T=mihomo-linux-armv7-; S=".gz"; ST="_linux_armv6.tar.gz";;
	*) die "unknown-arch-SKIP_BINARIES=1";; esac

	td="$(mktemp -d)"; trap 'rm -rf "$td"' EXIT INT

	# --- mihomo ---
	mu="$(bin_url MIHOMO MetaCubeX mihomo "$T" "$S")" || die pick-mihomo
	test -n "$mu" || die empty-mihomo-url
	log "mihomo url: ${mu}"
	Download "$mu" "$td/a.gz" || die "download-mihomo-failed"

	if test -f "$td/a.gz"; then
		gzip -dc "$td/a.gz" >"$td/mihomo" 2>/dev/null ||
		gunzip -c "$td/a.gz" >"$td/mihomo" 2>/dev/null ||
		die gunzip-mihomo
	fi
	_exe install -m0755 "$td/mihomo" /usr/local/bin/mihomo

	# --- shell2http ---
	hu="$(bin_url SHELL2HTTP msoap shell2http shell2http "$ST")" || die pick-sh2
	test -n "$hu" || die empty-shell2http-url
	log "shell2http url: ${hu}"
	Download "$hu" "$td/s.tgz" || die "download-shell2http-failed"

	test -f "$td/s.tgz" && tar xzf "$td/s.tgz" -C "$td" 2>/dev/null || die untar-shell2http

	b=""
	b="$(find "$td" -maxdepth 3 -type f -name shell2http 2>/dev/null | head -n 1)"
	test -n "$b" -a -f "$b" || die "no shell2http in archive"

	_exe install -m0755 "$b" /usr/local/bin/shell2http
}
