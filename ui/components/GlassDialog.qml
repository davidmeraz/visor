pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Diálogo modal in-window Matte Transparent Glassmorphism de Gema UI Kit.
Item {
    id: control
    property string title: ""
    property real dialogWidth: 420
    property bool closeOnBackdrop: true
    property Item contentItem: null
    property Item footer: null
    signal opened()
    signal closed()

    anchors.fill: parent
    z: 600
    visible: false
    focus: visible

    function open() {
        visible = true;
        forceActiveFocus();
        opened();
    }

    function close() {
        if (!visible) return;
        visible = false;
        closed();
    }

    onContentItemChanged: {
        if (control.contentItem) {
            control.contentItem.parent = contentSlot;
            control.contentItem.x = 0;
            control.contentItem.y = 0;
            control.contentItem.width = Qt.binding(() => contentSlot.width);
        }
    }

    onFooterChanged: {
        if (control.footer) {
            control.footer.parent = footerSlot;
            control.footer.x = 0;
            control.footer.y = 0;
            control.footer.width = Qt.binding(() => footerSlot.width);
        }
    }

    Keys.onEscapePressed: (event) => {
        control.close();
        event.accepted = true;
    }

    // Fondo modal atenuado.
    Rectangle {
        anchors.fill: parent
        radius: GemaTheme.rounding
        color: "#66060910"

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: if (control.closeOnBackdrop) control.close()
        }
    }

    // Sombra suave bajo la tarjeta del diálogo.
    Rectangle {
        x: dialogPanel.x - 8
        y: dialogPanel.y + 8
        width: dialogPanel.width + 16
        height: dialogPanel.height + 12
        radius: 20
        color: "#6804060c"
    }

    MattePanel {
        id: dialogPanel
        overlay: true
        radius: 16
        anchors.centerIn: parent
        width: Math.min(control.dialogWidth, Math.max(280, control.width - 36))
        height: Math.min(dialogCol.implicitHeight, Math.max(200, control.height - 36))

        // Intercepta clics internos para que no cierren el diálogo.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
        }

        ColumnLayout {
            id: dialogCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: 0

            // Cabecera con título y botón cerrar.
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 14
                Layout.topMargin: 16
                Layout.bottomMargin: 12
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: control.title
                    textFormat: Text.PlainText
                    color: GemaTheme.textColor
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                ActionButton {
                    iconName: "x"
                    iconSize: 14
                    ghost: true
                    implicitWidth: 30
                    implicitHeight: 30
                    cornerRadius: 8
                    toolTipText: "Cerrar (Esc)"
                    onClicked: control.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                implicitHeight: 1
                color: "#1effffff"
            }

            Item {
                id: contentSlot
                Layout.fillWidth: true
                Layout.leftMargin: 22
                Layout.rightMargin: 22
                Layout.topMargin: 14
                Layout.bottomMargin: 6
                implicitHeight: control.contentItem ? control.contentItem.implicitHeight : 0
            }

            Item {
                id: footerSlot
                Layout.fillWidth: true
                implicitHeight: control.footer ? control.footer.implicitHeight : 16
            }
        }
    }
}
