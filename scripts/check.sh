#!/usr/bin/env bash
# Validación QML, pruebas Rust e intercambio IPC de Visor.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$app_root"
qmllint="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"
command -v "$qmllint" >/dev/null || { echo 'Falta qmllint de Qt 6; define QMLLINT con su ruta.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Falta python3.' >&2; exit 1; }
"$qmllint" -i ui/components/qmldir shell.qml ui/*.qml ui/components/*.qml
cargo test --locked --manifest-path backend/Cargo.toml
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
printf 'hola visor\nsegunda línea\n' > "$tmp/nota.txt"
response="$(printf '{"version":2,"type":"app.check"}\n{"version":2,"type":"viewer.open","data":{"path":"%s"}}\n{"type":"app.check"}\n' "$tmp/nota.txt" | "$app_root/backend/run-backend.sh")"
python3 -c 'import json, sys
lines = sys.argv[1].rstrip("\n").split("\n")
assert len(lines) == 4, lines
ready, checked, opened, err = map(json.loads, lines)
assert ready["version"] == 2 and ready["type"] == "app.ready" and ready["data"]["name"] == "Visor"
assert checked["type"] == "app.checked" and checked["data"]["ok"] is True
assert opened["type"] == "viewer.opened" and opened["data"]["kind"] == "text" and opened["data"]["lineCount"] == 2
assert err["type"] == "error"
' "$response"
echo "Visor: QML, pruebas Rust e IPC verificados."
