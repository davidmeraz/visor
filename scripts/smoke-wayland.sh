#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/files" "$tmp/config"
printf 'línea uno\nlínea dos\n' > "$tmp/files/01_nota.txt"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><rect width="64" height="64" fill="#5ce1e6"/></svg>' > "$tmp/files/02_demo.svg"
log="$tmp/log"
if ! VISOR_FILE_PATH="$tmp/files/01_nota.txt" XDG_CONFIG_HOME="$tmp/config" GEMA_SETTINGS_PATH="$tmp/config/preferences.json" \
    timeout --foreground 25s qs --no-color -p "$root/smoke-ui.qml" >"$log" 2>&1; then
    cat "$log" >&2
    echo 'Smoke Wayland Visor: qs falló o agotó el tiempo.' >&2
    exit 1
fi
if ! grep -q 'VISOR_SMOKE_OK' "$log" || grep -q 'SMOKE_ERROR' "$log"; then
    cat "$log" >&2
    echo 'Smoke Wayland Visor: faltó marcador de éxito.' >&2
    exit 1
fi
echo 'Smoke Wayland Visor: UI y navegación verificadas.'
