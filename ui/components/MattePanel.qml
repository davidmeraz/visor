import QtQuick

// Vidrio esmerilado translúcido de Gema UI Kit con reflejos de agua y bisel luminoso.
GlassPanel {
    id: matte
    property bool overlay: false
    property bool waterReflection: true
    reflective: true
    topColor: overlay ? "#e2171c28" : "#16ffffff"
    bottomColor: overlay ? "#ee10141e" : "#0effffff"
    edgeColor: overlay ? (GemaTheme.synced ? GemaTheme.accentAlpha(0.48) : "#56ffffff") : "#44ffffff"
    radius: overlay ? 14 : GemaTheme.panelRadius

    WaterReflection {
        anchors.fill: parent
        visible: matte.waterReflection && !matte.overlay
        cornerRadius: matte.radius
        strength: 0.72
    }
}
