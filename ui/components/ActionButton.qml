pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

// Botón Matte Transparent Glassmorphism con icono vectorial, estados activo/ghost y tooltip Gema.
Button {
    id: control
    property bool accent: false
    property bool active: false
    property bool ghost: false
    property bool destructive: false
    property string iconName: ""
    property int iconSize: 15
    property string toolTipText: ""
    property int cornerRadius: GemaTheme.controlRadius
    readonly property bool iconOnly: iconName.length > 0 && text.length === 0

    implicitHeight: 34
    horizontalPadding: iconOnly ? 9 : 12
    verticalPadding: 6
    hoverEnabled: true
    font.pixelSize: 12
    font.weight: (control.accent || control.active) ? Font.DemiBold : Font.Medium

    scale: control.down && control.enabled ? 0.965 : 1.0
    Behavior on scale { NumberAnimation { duration: GemaTheme.animations ? 110 : 0; easing.type: Easing.OutCubic } }

    readonly property color resolvedFg: {
        if (!control.enabled) return GemaTheme.subtleColor;
        if (control.destructive) return GemaTheme.dangerColor;
        if (control.accent || control.active) return GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff";
        if (control.ghost && !control.hovered) return GemaTheme.mutedColor;
        return GemaTheme.textColor;
    }

    contentItem: Item {
        id: contentWrap
        readonly property int rowGap: (iconItem.visible && labelItem.visible) ? 6 : 0
        implicitWidth: (iconItem.visible ? iconItem.implicitWidth : 0)
                       + (labelItem.visible ? Math.ceil(labelItem.implicitWidth) : 0)
                       + rowGap
        implicitHeight: Math.max(iconItem.visible ? iconItem.implicitHeight : 0,
                                 labelItem.visible ? Math.ceil(labelItem.implicitHeight) : 0)

        Row {
            id: innerRow
            anchors.centerIn: parent
            spacing: contentWrap.rowGap

            GlassIcon {
                id: iconItem
                visible: control.iconName.length > 0
                name: control.iconName
                size: control.iconSize
                color: control.resolvedFg
                opacity: control.enabled ? 1.0 : 0.42
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                id: labelItem
                visible: control.text.length > 0
                width: contentWrap.width > 0
                       ? Math.min(Math.ceil(implicitWidth), Math.max(0, contentWrap.width - (iconItem.visible ? iconItem.width + contentWrap.rowGap : 0)))
                       : Math.ceil(implicitWidth)
                text: control.text
                textFormat: Text.PlainText
                font: control.font
                color: control.resolvedFg
                opacity: control.enabled ? 1.0 : 0.45
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                style: GemaTheme.darkText ? Text.Normal : Text.Raised
                styleColor: "#48000000"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    background: GlassPanel {
        radius: control.cornerRadius
        reflective: !control.ghost || control.hovered || control.active || control.accent
        topColor: {
            if (!control.enabled) return control.ghost ? "transparent" : "#0cffffff";
            if (control.destructive) return control.down ? "#50f38ba8" : (control.hovered ? "#3cf38ba8" : "#26f38ba8");
            if (control.down) return control.accent || control.active ? GemaTheme.accentAlpha(0.46) : "#30ffffff";
            if (control.accent || control.active) return GemaTheme.accentAlpha(control.hovered ? 0.40 : 0.30);
            if (control.ghost) return control.hovered ? "#22ffffff" : "transparent";
            return control.hovered ? "#26ffffff" : "#15ffffff";
        }
        bottomColor: {
            if (!control.enabled) return control.ghost ? "transparent" : "#08ffffff";
            if (control.destructive) return "#18f38ba8";
            if (control.accent || control.active) return GemaTheme.accentAlpha(0.18);
            if (control.ghost) return control.hovered ? "#12ffffff" : "transparent";
            return control.hovered ? "#16ffffff" : "#0cffffff";
        }
        edgeColor: {
            if (!control.enabled) return control.ghost ? "transparent" : "#20ffffff";
            if (control.destructive) return control.hovered ? "#aaf38ba8" : "#66f38ba8";
            if (control.accent || control.active) return GemaTheme.accentAlpha(0.76);
            if (control.ghost) return control.hovered ? "#38ffffff" : "transparent";
            return control.hovered ? GemaTheme.accentAlpha(0.56) : "#32ffffff";
        }
        highlighted: control.activeFocus || (control.hovered && (control.accent || control.active))
        opacity: control.enabled ? 1.0 : 0.55
    }

    GlassToolTip {
        visible: control.hovered && control.toolTipText.length > 0
        text: control.toolTipText
    }
}
