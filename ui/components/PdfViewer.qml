pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Visor de documentos PDF con renderizado bajo demanda (pdftoppm), caché y zoom fluido.
Item {
    id: root
    property string filePath: ""
    property int pageCount: 0
    property int currentPage: 1
    property var renderedPages: ({})
    property string pageError: ""
    property bool fitWidth: true
    property real zoomFactor: 1.0
    property real wheelAccum: 0

    signal requestPage(int page, int dpi, bool reset)

    readonly property int renderDpi: zoomFactor > 1.35 ? 210 : 150
    readonly property string currentKey: currentPage + "@" + renderDpi
    readonly property string currentImagePath: (renderedPages && renderedPages[currentKey])
        ? renderedPages[currentKey]
        : ((renderedPages && renderedPages[currentPage + "@150"]) ? renderedPages[currentPage + "@150"] : "")
    readonly property int zoomPercent: Math.round(zoomFactor * 100)

    function toFileUrl(p) {
        if (!p) return "";
        return "file://" + p.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }
    function loadCurrentAndPrefetch(resetQueue) {
        if (!filePath || pageCount <= 0) return;
        const p = Math.max(1, Math.min(pageCount, currentPage));
        currentPage = p;
        const key = p + "@" + renderDpi;
        if (!renderedPages || !renderedPages[key]) {
            requestPage(p, renderDpi, resetQueue);
        }
        if (p + 1 <= pageCount) {
            const nextKey = (p + 1) + "@" + renderDpi;
            if (!renderedPages || !renderedPages[nextKey]) {
                requestPage(p + 1, renderDpi, false);
            }
        }
    }
    function goToPage(page) {
        if (pageCount <= 0) return;
        const clamped = Math.max(1, Math.min(pageCount, page));
        if (clamped !== currentPage) {
            currentPage = clamped;
            pdfFlick.contentY = 0;
            loadCurrentAndPrefetch(true);
        }
    }
    function nextPage() { goToPage(currentPage + 1); }
    function prevPage() { goToPage(currentPage - 1); }
    function zoomBy(delta) {
        fitWidth = false;
        zoomFactor = Math.max(0.5, Math.min(2.6, Math.round((zoomFactor + delta) * 100) / 100));
        loadCurrentAndPrefetch(false);
    }
    function resetZoom() {
        fitWidth = true;
        zoomFactor = 1.0;
        loadCurrentAndPrefetch(false);
    }

    onFilePathChanged: {
        currentPage = 1;
        fitWidth = true;
        zoomFactor = 1.0;
        pdfFlick.contentX = 0;
        pdfFlick.contentY = 0;
        if (filePath && pageCount > 0) loadCurrentAndPrefetch(true);
    }
    onPageCountChanged: {
        if (filePath && pageCount > 0) {
            currentPage = 1;
            loadCurrentAndPrefetch(true);
        }
    }

    Flickable {
        id: pdfFlick
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: pdfBar.top
        anchors.bottomMargin: 10
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: Math.max(width, pageCard.width + 32)
        contentHeight: Math.max(height, pageCard.height + 32)
        ScrollBar.vertical: GlassScrollBar {}
        ScrollBar.horizontal: GlassScrollBar {}

        WheelHandler {
            acceptedModifiers: Qt.ControlModifier
            onWheel: (event) => {
                const dy = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                if (dy === 0) return;
                event.accepted = true;
                if (Math.abs(dy) >= 120) {
                    root.wheelAccum = 0;
                    root.zoomBy(dy > 0 ? 0.15 : -0.15);
                    return;
                }
                root.wheelAccum += dy;
                if (Math.abs(root.wheelAccum) >= 70) {
                    const up = root.wheelAccum > 0;
                    root.wheelAccum = 0;
                    root.zoomBy(up ? 0.15 : -0.15);
                }
            }
        }

        // Tarjeta de página PDF con sombra elegante.
        Item {
            id: pageCard
            readonly property real aspect: (pageImg.implicitWidth > 0 && pageImg.implicitHeight > 0)
                ? (pageImg.implicitHeight / pageImg.implicitWidth)
                : 1.414
            readonly property real fitTargetW: {
                const maxW = Math.max(240, pdfFlick.width - 48);
                const maxH = Math.max(240, pdfFlick.height - 32);
                const byHeight = maxH / aspect;
                return Math.min(maxW, Math.max(byHeight, Math.min(maxW, 860)));
            }
            width: Math.round(fitTargetW * root.zoomFactor)
            height: Math.round(width * aspect)
            x: Math.round(Math.max(16, (pdfFlick.contentWidth - width) / 2))
            y: Math.round(Math.max(16, (pdfFlick.contentHeight - height) / 2))

            Rectangle {
                visible: pageImg.status === Image.Ready
                x: -4
                y: 5
                width: parent.width + 8
                height: parent.height + 6
                radius: 10
                color: "#5504060c"
            }

            Rectangle {
                anchors.fill: parent
                radius: 8
                color: pageImg.status === Image.Ready ? "#ffffff" : "#18ffffff"
                border.width: 1
                border.color: "#38ffffff"
                clip: true

                Image {
                    id: pageImg
                    anchors.fill: parent
                    source: root.currentImagePath ? root.toFileUrl(root.currentImagePath) : ""
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    fillMode: Image.PreserveAspectFit
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: pageImg.status !== Image.Ready
                    spacing: 10
                    GlassPanel {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 48
                        implicitHeight: 48
                        radius: 24
                        topColor: GemaTheme.accentAlpha(0.18)
                        bottomColor: "#140a0e18"
                        edgeColor: GemaTheme.accentAlpha(0.45)
                        GlassIcon {
                            anchors.centerIn: parent
                            name: "file-text"
                            size: 22
                            color: root.pageError ? GemaTheme.dangerColor : GemaTheme.accent
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.pageError
                              ? root.pageError
                              : (root.pageCount <= 0
                                 ? "No se detectaron páginas en este PDF."
                                 : "Renderizando página " + root.currentPage + "…")
                        textFormat: Text.PlainText
                        color: root.pageError ? GemaTheme.dangerColor : GemaTheme.mutedColor
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    // Barra inferior de navegación de páginas y zoom.
    GlassPanel {
        id: pdfBar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        implicitHeight: 40
        implicitWidth: pdfRow.implicitWidth + 16
        radius: 13
        topColor: "#cc141a26"
        bottomColor: "#dc0e121c"
        edgeColor: "#3cffffff"

        RowLayout {
            id: pdfRow
            anchors.centerIn: parent
            spacing: 5

            ActionButton {
                iconName: "chevron-left"
                iconSize: 15
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                enabled: root.currentPage > 1
                toolTipText: "Página anterior (RePág)"
                onClicked: root.prevPage()
            }

            Text {
                text: "Página"
                color: GemaTheme.subtleColor
                font.pixelSize: 12
            }

            TextField {
                id: pageInput
                implicitWidth: 44
                implicitHeight: 26
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: String(root.currentPage)
                color: GemaTheme.textColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
                selectByMouse: true
                inputMethodHints: Qt.ImhDigitsOnly
                background: GlassPanel {
                    radius: 7
                    reflective: false
                    highlighted: pageInput.activeFocus
                    topColor: "#240a0e18"
                    bottomColor: "#2c080b14"
                    edgeColor: pageInput.activeFocus ? GemaTheme.accentAlpha(0.75) : "#34ffffff"
                }
                onAccepted: {
                    const n = parseInt(pageInput.text, 10);
                    if (isFinite(n) && n >= 1) root.goToPage(n);
                    else pageInput.text = String(root.currentPage);
                    pageInput.focus = false;
                }
            }

            Text {
                text: "/ " + Math.max(1, root.pageCount)
                textFormat: Text.PlainText
                color: GemaTheme.mutedColor
                font.pixelSize: 12
            }

            ActionButton {
                iconName: "chevron-right"
                iconSize: 15
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                enabled: root.currentPage < root.pageCount
                toolTipText: "Página siguiente (AvPág)"
                onClicked: root.nextPage()
            }

            Rectangle { implicitWidth: 1; implicitHeight: 18; color: "#28ffffff" }

            ActionButton {
                iconName: "zoom-out"
                iconSize: 14
                ghost: true
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Alejar (Ctrl+-)"
                onClicked: root.zoomBy(-0.15)
            }

            Text {
                Layout.preferredWidth: 44
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
                onClicked: root.zoomBy(0.15)
            }

            ActionButton {
                iconName: "fit"
                iconSize: 13
                text: "Ajustar"
                active: root.fitWidth
                ghost: !root.fitWidth
                implicitHeight: 28
                horizontalPadding: 9
                cornerRadius: 8
                toolTipText: "Restablecer zoom (Ctrl+0)"
                onClicked: root.resetZoom()
            }
        }
    }
}
