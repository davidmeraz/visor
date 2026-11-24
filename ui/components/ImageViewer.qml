pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Visor interactivo de imágenes con zoom fluido, paneo, rotación y barra HUD de cristal.
Item {
    id: root
    property string filePath: ""
    property bool fitMode: true
    property real zoomScale: 1.0
    property int rotationDeg: 0
    property real panX: 0
    property real panY: 0
    property real wheelAccum: 0

    readonly property int naturalWidth: img.implicitWidth
    readonly property int naturalHeight: img.implicitHeight
    readonly property bool rotatedQuarter: Math.abs(rotationDeg % 180) === 90
    readonly property real baseW: rotatedQuarter ? naturalHeight : naturalWidth
    readonly property real baseH: rotatedQuarter ? naturalWidth : naturalHeight
    readonly property real fitScale: {
        if (baseW <= 0 || baseH <= 0 || viewport.width <= 32 || viewport.height <= 32) return 1.0;
        const availW = Math.max(1, viewport.width - 36);
        const availH = Math.max(1, viewport.height - 92);
        return Math.min(1.0, Math.min(availW / baseW, availH / baseH));
    }
    readonly property real effectiveScale: fitMode ? fitScale : zoomScale
    readonly property int zoomPercent: Math.max(1, Math.round(effectiveScale * 100))

    function toFileUrl(p) {
        if (!p) return "";
        return "file://" + p.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }
    function resetView() {
        fitMode = true;
        zoomScale = 1.0;
        rotationDeg = 0;
        panX = 0;
        panY = 0;
    }
    function setFit() {
        fitMode = true;
        panX = 0;
        panY = 0;
    }
    function setActualSize() {
        fitMode = false;
        zoomScale = 1.0;
        panX = 0;
        panY = 0;
    }
    function zoomBy(factor) {
        const cur = effectiveScale;
        const next = Math.max(0.12, Math.min(8.0, cur * factor));
        fitMode = false;
        zoomScale = next;
    }
    function rotateRight() {
        rotationDeg = (rotationDeg + 90) % 360;
        panX = 0;
        panY = 0;
    }
    function rotateLeft() {
        rotationDeg = (rotationDeg + 270) % 360;
        panX = 0;
        panY = 0;
    }

    onFilePathChanged: resetView()

    // Área principal del lienzo.
    Item {
        id: viewport
        anchors.fill: parent
        clip: true

        // Fondo sutil detrás de imágenes transparentes cuando se visualizan.
        Rectangle {
            visible: img.status === Image.Ready
            anchors.centerIn: imageBox
            width: Math.max(1, (root.rotatedQuarter ? imageBox.height : imageBox.width) + 2)
            height: Math.max(1, (root.rotatedQuarter ? imageBox.width : imageBox.height) + 2)
            radius: 8
            color: GemaTheme.darkText ? "#22ffffff" : "#2e080b12"
            border.width: 1
            border.color: "#28ffffff"
        }

        Item {
            id: imageBox
            x: Math.round((viewport.width - width) / 2 + root.panX)
            y: Math.round((viewport.height - 44 - height) / 2 + root.panY)
            width: Math.max(1, Math.round(root.naturalWidth * root.effectiveScale))
            height: Math.max(1, Math.round(root.naturalHeight * root.effectiveScale))
            rotation: root.rotationDeg
            Behavior on rotation { NumberAnimation { duration: GemaTheme.animations ? 160 : 0; easing.type: Easing.OutCubic } }

            Image {
                id: img
                anchors.fill: parent
                source: root.filePath ? root.toFileUrl(root.filePath) : ""
                asynchronous: true
                cache: true
                autoTransform: true
                smooth: true
                mipmap: true
                fillMode: Image.PreserveAspectFit
            }
        }

        // Indicador de carga o error.
        ColumnLayout {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            spacing: 10
            GlassPanel {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 50
                implicitHeight: 50
                radius: 25
                topColor: GemaTheme.accentAlpha(0.18)
                bottomColor: "#140a0e18"
                edgeColor: GemaTheme.accentAlpha(0.42)
                GlassIcon {
                    anchors.centerIn: parent
                    name: "image"
                    size: 22
                    color: img.status === Image.Error ? GemaTheme.dangerColor : GemaTheme.accent
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: img.status === Image.Error ? "No se pudo decodificar la imagen." : "Cargando imagen…"
                textFormat: Text.PlainText
                color: img.status === Image.Error ? GemaTheme.dangerColor : GemaTheme.mutedColor
                font.pixelSize: 13
            }
        }

        // Arrastre para paneo y doble clic para alternar Ajustar / 100%.
        MouseArea {
            anchors.fill: parent
            property real lastX: 0
            property real lastY: 0
            property bool dragging: false
            cursorShape: dragging ? Qt.ClosedHandCursor : (root.fitMode ? Qt.ArrowCursor : Qt.OpenHandCursor)
            onPressed: (mouse) => {
                lastX = mouse.x;
                lastY = mouse.y;
                dragging = true;
            }
            onPositionChanged: (mouse) => {
                if (!dragging) return;
                root.panX += mouse.x - lastX;
                root.panY += mouse.y - lastY;
                lastX = mouse.x;
                lastY = mouse.y;
            }
            onReleased: dragging = false
            onDoubleClicked: {
                if (root.fitMode) root.setActualSize();
                else root.setFit();
            }
        }

        WheelHandler {
            onWheel: (event) => {
                const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                if (dy === 0) return;
                event.accepted = true;
                if (Math.abs(dy) >= 120) {
                    root.wheelAccum = 0;
                    root.zoomBy(dy > 0 ? 1.18 : 1 / 1.18);
                    return;
                }
                root.wheelAccum += dy;
                if (Math.abs(root.wheelAccum) >= 60) {
                    const up = root.wheelAccum > 0;
                    root.wheelAccum = 0;
                    root.zoomBy(up ? 1.15 : 1 / 1.15);
                }
            }
        }
    }

    // Barra flotante HUD de controles de imagen.
    GlassPanel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        implicitHeight: 40
        implicitWidth: hudRow.implicitWidth + 16
        radius: 13
        topColor: "#cc141a26"
        bottomColor: "#dc0e121c"
        edgeColor: "#3cffffff"

        RowLayout {
            id: hudRow
            anchors.centerIn: parent
            spacing: 4

            ActionButton {
                iconName: "zoom-out"
                iconSize: 14
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Alejar (Ctrl+-)"
                onClicked: root.zoomBy(1 / 1.25)
            }

            Text {
                Layout.preferredWidth: 46
                horizontalAlignment: Text.AlignHCenter
                text: root.zoomPercent + "%"
                textFormat: Text.PlainText
                color: GemaTheme.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            ActionButton {
                iconName: "zoom-in"
                iconSize: 14
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Acercar (Ctrl++)"
                onClicked: root.zoomBy(1.25)
            }

            Rectangle { implicitWidth: 1; implicitHeight: 18; color: "#28ffffff" }

            ActionButton {
                iconName: "fit"
                iconSize: 13
                text: "Ajustar"
                active: root.fitMode
                ghost: !root.fitMode
                implicitHeight: 28
                horizontalPadding: 9
                cornerRadius: 8
                toolTipText: "Ajustar a la ventana (0)"
                onClicked: root.setFit()
            }

            ActionButton {
                text: "1:1"
                active: !root.fitMode && Math.abs(root.zoomScale - 1.0) < 0.02
                ghost: root.fitMode || Math.abs(root.zoomScale - 1.0) >= 0.02
                implicitHeight: 28
                horizontalPadding: 9
                cornerRadius: 8
                toolTipText: "Tamaño real 100% (1)"
                onClicked: root.setActualSize()
            }

            Rectangle { implicitWidth: 1; implicitHeight: 18; color: "#28ffffff" }

            ActionButton {
                iconName: "rotate-ccw"
                iconSize: 14
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Rotar a la izquierda (Shift+R)"
                onClicked: root.rotateLeft()
            }

            ActionButton {
                iconName: "rotate-cw"
                iconSize: 14
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Rotar a la derecha (R)"
                onClicked: root.rotateRight()
            }

            Rectangle {
                visible: root.naturalWidth > 0 && root.naturalHeight > 0
                implicitWidth: 1
                implicitHeight: 18
                color: "#28ffffff"
            }

            Text {
                visible: root.naturalWidth > 0 && root.naturalHeight > 0
                text: root.naturalWidth + " × " + root.naturalHeight + " px"
                textFormat: Text.PlainText
                color: GemaTheme.mutedColor
                font.pixelSize: 11
                leftPadding: 4
                rightPadding: 4
            }
        }
    }
}
