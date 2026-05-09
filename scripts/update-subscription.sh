#!/usr/bin/env bash
# Перескачивает узлы Mihomo после смены URL в secrets/subscription.url (локально).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/gen-mihomo-config.sh"
"$ROOT/scripts/svc-restart-mihomo.sh"
