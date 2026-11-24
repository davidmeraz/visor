# Visor 0.1.0

Visor universal nativo para **Wayland / Hyprland** construido con **Quickshell / Qt Quick 6**, **QtMultimedia**, **Gema UI Kit** y motor **Rust**. Permite abrir y navegar imágenes, vídeos, audio, documentos PDF y archivos de texto/código desde una interfaz *Matte Transparent Glassmorphism* sincronizada con tu tema Gema.

## Formatos soportados

- **Imágenes:** `PNG`, `JPG`, `JPEG`, `WEBP`, `GIF`, `BMP`, `ICO`, `SVG`, `TIF`, `TIFF`, `AVIF` — zoom fluido (`Scroll` / `Ctrl++` / `Ctrl+-`), paneo por arrastre, doble clic `Ajustar / 1:1`, rotación `90°`, resolución real y galería por carpeta (`←` / `→`).
- **Vídeos y audio:** `MP4`, `MKV`, `WEBM`, `AVI`, `MOV`, `M4V`, `MP3`, `FLAC`, `WAV`, `OGG`, `OPUS` — reproducción nativa vía `QtMultimedia` (FFmpeg), barra de progreso interactiva, salto `±10s`, velocidad (`0.5×`–`2×`), volumen y silenciado.
- **PDF:** `PDF` — renderizado por página bajo demanda vía `pdftoppm` con caché en `$XDG_CACHE_HOME/gema-visor/pdf-pages/`, precarga de página siguiente, salto directo de página y zoom con `Ctrl+Scroll`.
- **Texto y código:** archivos de código, Markdown, JSON, YAML, TOML, logs y texto plano UTF-8 (hasta 512 KiB) — numeración de líneas, ajuste de línea, búsqueda interna (`Ctrl+F`), zoom de fuente (`Ctrl+Scroll`) y copia rápida.

## Uso y pruebas

```sh
./scripts/run.sh /ruta/al/archivo.pdf
./scripts/check.sh
./scripts/smoke-wayland.sh
```

Para instalar la entrada de escritorio (`visor.desktop`) e integrarlo con el sistema y `Explorer`:

```sh
./scripts/install-desktop.sh
```

## Atajos

- `Ctrl+O`: elegir archivo · `Ctrl+L`: escribir ruta · `Ctrl+I`: panel de detalles y lista de la carpeta.
- `Alt+←` / `Alt+→` (o `←` / `→` en imágenes): archivo anterior / siguiente en la carpeta.
- **Imágenes:** `Scroll` zoom · `R` / `Shift+R` rotar · `0` ajustar · `1` tamaño real `1:1`.
- **Vídeo / Audio:** `Espacio` reproducir/pausar · `J` / `L` retroceder/adelantar 10 s · `M` silenciar.
- **PDF:** `RePág` / `AvPág` cambiar de página · `Ctrl+Scroll` zoom.
- **Texto / Código:** `Ctrl+F` buscar · `Ctrl+Scroll` tamaño de fuente.
