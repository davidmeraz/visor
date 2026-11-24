pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Barra de desplazamiento fina y translúcida estilo Gema.
ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    visible: bar.size > 0 && bar.size < 0.999
    hoverEnabled: true
    padding: 2

    contentItem: Rectangle {
        implicitWidth: bar.hovered || bar.pressed ? 6 : 4
        implicitHeight: bar.hovered || bar.pressed ? 6 : 4
        radius: 3
        color: bar.pressed
               ? GemaTheme.accentAlpha(0.75)
               : bar.hovered
                 ? GemaTheme.accentAlpha(0.52)
                 : (GemaTheme.darkText ? "#40263d50" : "#38ffffff")
        opacity: bar.active || bar.hovered || bar.pressed ? 0.95 : 0.35
        Behavior on color { ColorAnimation { duration: GemaTheme.animDuration } }
        Behavior on opacity { NumberAnimation { duration: GemaTheme.animDuration } }
        Behavior on implicitWidth { NumberAnimation { duration: GemaTheme.animDuration } }
    }

    background: Item {}
}
