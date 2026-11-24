#!/usr/bin/env bash
set -euo pipefail
backend_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$backend_dir"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$backend_dir/target}"
bin="$CARGO_TARGET_DIR/release/visor-backend"
if [[ ! -x "$bin" || Cargo.toml -nt "$bin" || Cargo.lock -nt "$bin" ]] || [[ -n "$(find src -type f -newer "$bin" -print -quit)" ]]; then
    if ! command -v cargo >/dev/null 2>&1; then
        echo '{"version":2,"type":"error","data":{"message":"Instala cargo para compilar el motor Rust."}}'
        exit 1
    fi
    if ! cargo build --release --quiet --locked >&2; then
        echo '{"version":2,"type":"error","data":{"message":"No se pudo compilar el motor Rust."}}'
        exit 1
    fi
fi
exec "$bin"
