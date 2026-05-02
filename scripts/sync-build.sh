#!/usr/bin/env bash
# Только текстовые списки Flowseal + build (без тяжёлых .dat).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/sync-zapret-lists-upstream.sh"
"$ROOT/scripts/build-lists.sh"
