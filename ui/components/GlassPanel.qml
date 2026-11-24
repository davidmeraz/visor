import QtQuick

// Cristal facetado Gema UI Kit sincronizado con el tema Gema de Hyprland.
Rectangle {
    id: panel
    property color topColor: "#14ffffff"
    property color bottomColor: "#14080c14"
    property color edgeColor: "#32ffffff"
    property bool highlighted: false
    property bool reflective: true
    readonly property color effectiveTopColor: GemaTheme.synced ? GemaTheme.tintColor(topColor, 0.14) : topColor
    readonly property color effectiveBottomColor: GemaTheme.synced ? GemaTheme.tintColor(bottomColor, 0.10) : bottomColor
    readonly property color effectiveEdgeColor: GemaTheme.synced ? GemaTheme.tintColor(edgeColor, 0.34) : edgeColor
    readonly property color highlightBorderColor: GemaTheme.synced ? GemaTheme.accentAlpha(0.78) : "#96ffffff"

    radius: GemaTheme.panelRadius
    border.width: 1
    border.color: highlighted ? highlightBorderColor : effectiveEdgeColor
    Behavior on border.color { ColorAnimation { duration: GemaTheme.animDuration } }
    Behavior on topColor { ColorAnimation { duration: GemaTheme.animDuration } }
    Behavior on bottomColor { ColorAnimation { duration: GemaTheme.animDuration } }
    gradient: Gradient {
        GradientStop { position: 0; color: panel.effectiveTopColor }
        GradientStop { position: 1; color: panel.effectiveBottomColor }
    }

    // Bisel interior sutil de cristal.
    Rectangle {
        visible: panel.reflective
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, panel.radius - 1)
        color: "transparent"
        border.width: 1
        border.color: panel.highlighted
                      ? (GemaTheme.synced ? GemaTheme.accentAlpha(0.22) : "#26ffffff")
                      : (GemaTheme.synced ? GemaTheme.accentAlpha(0.10) : "#14ffffff")
    }

    // Destello especular fino en el borde superior.
    Rectangle {
        visible: panel.reflective
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: panel.radius
        anchors.rightMargin: panel.radius
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#00ffffff" }
            GradientStop { position: 0.28; color: GemaTheme.synced ? GemaTheme.accentAlpha(0.55) : "#58ffffff" }
            GradientStop { position: 0.68; color: "#28ffffff" }
            GradientStop { position: 1; color: "#00ffffff" }
        }
    }
}
