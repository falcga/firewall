#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/sync-zapret-lists-upstream.sh"
"$ROOT/scripts/sync-geodat.sh"
"$ROOT/scripts/build-lists.sh"
"$ROOT/scripts/gen-mihomo-config.sh"
"$ROOT/scripts/svc-restart-mihomo.sh" || echo "WARN: mihomo не перезапустился ($?)" >&2
"$ROOT/scripts/svc-restart-zapret.sh" || echo "WARN: zapret не перезапустился ($?)" >&2
echo OK
