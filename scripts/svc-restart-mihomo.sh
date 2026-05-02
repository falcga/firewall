#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib.sh"

MIHOMO_SERVICE="${MIHOMO_SERVICE:-mihomo.service}"

"$ROOT/scripts/gen-mihomo-config.sh" >/dev/null
systemctl restart "$MIHOMO_SERVICE"
