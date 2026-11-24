#!/usr/bin/env bash
# Instala el lanzador de usuario visor.desktop en ~/.local/share/applications/.
set -euo pipefail
app_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
wrapper_dir="$data_home/visor"
apps_dir="$data_home/applications"
mkdir -p "$wrapper_dir" "$apps_dir"

cat > "$wrapper_dir/run" <<EOF
#!/usr/bin/env bash
exec "$app_root/scripts/run.sh" "\$@"
EOF
chmod +x "$wrapper_dir/run"

cat > "$apps_dir/visor.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Visor
Comment=Visor universal Gema para imágenes, vídeos, audio, PDF y texto
Exec=$wrapper_dir/run %f
Icon=image-x-generic
Terminal=false
Categories=Graphics;AudioVideo;Utility;Viewer;
MimeType=image/png;image/jpeg;image/webp;image/gif;image/bmp;image/svg+xml;image/avif;video/mp4;video/x-matroska;video/webm;video/quicktime;video/x-msvideo;audio/mpeg;audio/flac;audio/wav;audio/ogg;application/pdf;text/plain;text/markdown;
StartupWMClass=dev.gema.visor
EOF

echo "Instalado: $apps_dir/visor.desktop -> $wrapper_dir/run"
