# Visor · Gema UI Kit App

Visor universal nativo para **Hyprland / Wayland** (imágenes, vídeos, audio, PDF y código/texto) construido con el stack **Gema UI Kit**:

- **Estilo visual:** Matte Transparent Glassmorphism (`MattePanel`, `GlassPanel`, `WaterReflection`, `ActionButton`, `GlassIcon`, `GlassDialog`, `GemaTheme`) en `ui/components/`, con desenfoque real del compositor (`BackgroundEffect.blurRegion`).
- **Frontend:** Quickshell + QtQuick 6 QML + `QtMultimedia` (`shell.qml`, `ui/VisorWindow.qml`, `ui/VisorBridge.qml`, visores dedicados en `ui/components/`).
- **Motor Backend:** Rust (`backend/src/main.rs`) conectado por `stdin`/`stdout` mediante JSON-Lines v2 (`{"version": 2, "type": "...", "data": {...}}`), con renderizado PDF asíncrono vía `pdftoppm` y caché en disco.
- **Probar aplicación:** `./scripts/check.sh`
- **Iniciar aplicación:** `./scripts/run.sh [ruta/al/archivo]`
