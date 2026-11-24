#!/usr/bin/env bash
# Lanzador de Visor (Gema UI Kit) en Quickshell con soporte de ruta o URI file://.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# -ge 1 && -n "${1:-}" ]]; then
    raw="$1"
    if [[ "$raw" == file://* ]]; then
        raw="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1][7:]))' "$raw")"
    fi
    if [[ "$raw" != /* ]]; then
        raw="$(realpath -m -- "$raw")"
    fi
    export VISOR_FILE_PATH="$raw"
    shift
fi
exec qs --path "$app_root/shell.qml" "$@"
