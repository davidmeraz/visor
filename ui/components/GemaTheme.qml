pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Sincronización en vivo con el tema Gema de Hyprland (~/.config/gema/preferences.json).
QtObject {
    id: gemaTheme
    property color accent: "#b5a2ed"
    property int rounding: 16
    property bool blur: true
    property bool animations: true
    property bool darkText: false
    property int gemShape: 7
    property bool synced: false

    // Tokens semánticos de tipografía y superficies.
    readonly property color textColor: darkText ? "#182433" : "#f4f6fa"
    readonly property color mutedColor: darkText ? "#3b4c61" : "#cfd6e4"
    readonly property color subtleColor: darkText ? "#586a80" : "#9aa5ba"
    readonly property color placeholderColor: darkText ? "#687a91" : "#9ba6bc"
    readonly property color textShadow: darkText ? Qt.rgba(1, 1, 1, 0.72) : Qt.rgba(0, 0, 0, 0.62)
    readonly property color accentInk: darkText ? Qt.darker(accent, 1.85) : accent
    readonly property color dangerColor: darkText ? "#c93b52" : "#f38ba8"
    readonly property int animDuration: animations ? 160 : 0
    readonly property int panelRadius: Math.max(10, Math.min(20, rounding + 4))
    readonly property int controlRadius: Math.max(8, Math.min(12, rounding + 1))

    Behavior on accent { ColorAnimation { duration: gemaTheme.animations ? 240 : 0 } }

    readonly property string preferencesPath: Quickshell.env("GEMA_SETTINGS_PATH")
        || ((Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/gema/preferences.json")

    function tintColor(baseColor, alphaMix) {
        const c = Qt.color(baseColor);
        const a = Qt.color(accent);
        return Qt.rgba(
            c.r * (1 - alphaMix) + a.r * alphaMix,
            c.g * (1 - alphaMix) + a.g * alphaMix,
            c.b * (1 - alphaMix) + a.b * alphaMix,
            c.a
        );
    }

    function accentAlpha(alpha) {
        const a = Qt.color(accent);
        return Qt.rgba(a.r, a.g, a.b, alpha);
    }

    function load() {
        try {
            const raw = prefsFile.text();
            if (!raw) return;
            const data = JSON.parse(raw);
            if (typeof data.accent === "string" && /^#[0-9a-fA-F]{6}$/.test(data.accent))
                accent = data.accent.toLowerCase();
            if (typeof data.rounding === "number" && isFinite(data.rounding))
                rounding = Math.max(8, Math.min(28, Math.round(data.rounding)));
            if (typeof data.blur === "boolean")
                blur = data.blur;
            if (typeof data.animations === "boolean")
                animations = data.animations;
            if (typeof data.darkText === "boolean")
                darkText = data.darkText;
            if (typeof data.gemShape === "number")
                gemShape = data.gemShape;
            synced = true;
        } catch (e) {}
    }

    readonly property FileView prefsFile: FileView {
        path: gemaTheme.preferencesPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: gemaTheme.load()
        onFileChanged: {
            reload();
            gemaTheme.load();
        }
    }

    Component.onCompleted: load()
}
