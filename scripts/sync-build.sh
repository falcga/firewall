#!/usr/bin/env bash
# Только текстовые списки Flowseal + build (без тяжёлых .dat).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/sync-zapret-lists-upstream.sh"

# Пробуем Python-версию (устойчива к CRLF)
if [ -x "$ROOT/scripts/build-lists.py" ]; then
  python3 "$ROOT/scripts/build-lists.py" || echo "⚠ build-lists.py failed" >&2
elif [ -x "$ROOT/scripts/build-lists.sh" ]; then
  "$ROOT/scripts/build-lists.sh"
fi
