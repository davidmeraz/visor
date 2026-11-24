pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "components"

FloatingWindow {
    id: window
    required property VisorBridge bridge
    title: window.bridge.fileName ? (window.bridge.fileName + " — Visor") : "Visor"
    implicitWidth: 1080
    implicitHeight: 720
    minimumSize: Qt.size(520, 400)
    color: "transparent"
    visible: true

    property bool editingPath: false
    property bool detailsOpen: false
    property string statusMessage: ""
    readonly property bool textInputFocused: pathInput.activeFocus || welcomePathInput.activeFocus

    Timer { id: statusTimer; interval: 2800; onTriggered: window.statusMessage = "" }
    TextEdit { id: clipboardHelper; visible: false }

    function showStatus(msg) {
        window.statusMessage = msg;
        statusTimer.restart();
    }
    function copyText(str, notice) {
        if (!str) return;
        clipboardHelper.text = str;
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        window.showStatus(notice || "Copiado al portapapeles");
    }
    function kindIcon(kind) {
        if (kind === "image") return "image";
        if (kind === "video") return "film";
        if (kind === "audio") return "music";
        if (kind === "pdf") return "file-text";
        if (kind === "text") return "code";
        return "file";
    }
    function kindLabel(kind, ext) {
        const suffix = ext ? (" " + ext) : "";
        if (kind === "image") return "Imagen" + suffix;
        if (kind === "video") return "Vídeo" + suffix;
        if (kind === "audio") return "Audio" + suffix;
        if (kind === "pdf") return "Documento PDF";
        if (kind === "text") return ext ? ("Texto / " + ext) : "Texto";
        return "Archivo" + suffix;
    }
    function sizeText(bytes) {
        if (!bytes || bytes < 1024) return Math.floor(bytes || 0) + " B";
        let value = bytes / 1024;
        const units = ["KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (value >= 1024 && i < units.length - 1) { value /= 1024; ++i; }
        return value.toFixed(1) + " " + units[i];
    }
    function dateText(epochSec) {
        if (!epochSec || epochSec <= 0) return "—";
        const d = new Date(epochSec * 1000);
        const p = n => (n < 10 ? "0" : "") + n;
        return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes());
    }
    function urlToLocalPath(fileUrl) {
        let s = String(fileUrl || "");
        if (s.startsWith("file://")) s = decodeURIComponent(s.slice(7));
        return s;
    }
    function startEditPath() {
        pathInput.text = window.bridge.filePath;
        window.editingPath = true;
        pathInput.forceActiveFocus();
        pathInput.selectAll();
    }

    component MetaRow: ColumnLayout {
        id: rowItem
        property string label: ""
        property string value: ""
        property bool divider: true
        Layout.fillWidth: true
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 6
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            spacing: 8
            Text {
                Layout.preferredWidth: 78
                text: rowItem.label
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                font.pixelSize: 11
                font.weight: Font.Medium
            }
            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: rowItem.value
                textFormat: Text.PlainText
                color: GemaTheme.textColor
                font.pixelSize: 11
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }
        }
        Rectangle {
            visible: rowItem.divider
            Layout.fillWidth: true
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            implicitHeight: 1
            color: "#18ffffff"
        }
    }

    FileDialog {
        id: filePicker
        title: "Abrir archivo en Visor"
        nameFilters: [
            "Todos los archivos compatibles (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.avif *.mp4 *.mkv *.webm *.mov *.avi *.mp3 *.flac *.wav *.ogg *.pdf *.txt *.md *.rs *.qml *.js *.ts *.py *.json *.toml *.yaml *.yml *.sh *.html *.css)",
            "Imágenes (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.tif *.tiff *.avif)",
            "Vídeos y audio (*.mp4 *.mkv *.webm *.mov *.avi *.m4v *.mp3 *.flac *.wav *.ogg *.opus)",
            "Documentos PDF (*.pdf)",
            "Todos los archivos (*)"
        ]
        onAccepted: {
            const p = window.urlToLocalPath(filePicker.selectedFile);
            if (p.length > 0) window.bridge.openFile(p);
        }
    }

    BackgroundEffect.blurRegion: Region { item: GemaTheme.blur ? surface : null; radius: surface.radius }

    MattePanel {
        id: surface
        anchors.fill: parent
        anchors.margins: 1
        radius: GemaTheme.rounding
        topColor: "#18ffffff"
        bottomColor: "#0effffff"
        edgeColor: "#46ffffff"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 14
        anchors.bottomMargin: 12
        spacing: 10

        // === BARRA SUPERIOR UNIFICADA ===
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Identidad de la app.
            RowLayout {
                spacing: 8
                GlassPanel {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: GemaTheme.controlRadius
                    topColor: GemaTheme.accentAlpha(0.28)
                    bottomColor: GemaTheme.accentAlpha(0.12)
                    edgeColor: GemaTheme.accentAlpha(0.62)
                    GlassIcon {
                        anchors.centerIn: parent
                        name: "eye"
                        size: 16
                        color: GemaTheme.darkText ? GemaTheme.accentInk : "#ffffff"
                    }
                }
                Text {
                    visible: window.width >= 680
                    text: "Visor"
                    color: GemaTheme.textColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    font.letterSpacing: -0.2
                    style: GemaTheme.darkText ? Text.Normal : Text.Raised
                    styleColor: "#50000000"
                }
                Rectangle {
                    visible: window.width >= 960
                    implicitWidth: verLbl.implicitWidth + 12
                    implicitHeight: 20
                    radius: 10
                    color: GemaTheme.accentAlpha(0.16)
                    border.width: 1
                    border.color: GemaTheme.accentAlpha(0.32)
                    Text {
                        id: verLbl
                        anchors.centerIn: parent
                        text: "v" + window.bridge.appVersion
                        color: GemaTheme.accent
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
            }

            Rectangle {
                visible: window.width >= 680
                implicitWidth: 1
                implicitHeight: 20
                color: "#24ffffff"
            }

            // Navegación entre archivos de la misma carpeta.
            RowLayout {
                visible: window.bridge.hasFile
                spacing: 4
                ActionButton {
                    iconName: "chevron-left"
                    iconSize: 15
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.canPrev
                    toolTipText: "Archivo anterior (Alt+←)"
                    onClicked: window.bridge.prevFile()
                }
                ActionButton {
                    iconName: "chevron-right"
                    iconSize: 15
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 34
                    enabled: window.bridge.canNext
                    toolTipText: "Archivo siguiente (Alt+→)"
                    onClicked: window.bridge.nextFile()
                }
            }

            // Cápsula del archivo actual / editor de ruta inline.
            GlassPanel {
                Layout.fillWidth: true
                Layout.minimumWidth: 140
                implicitHeight: 36
                radius: GemaTheme.controlRadius
                highlighted: window.editingPath
                topColor: window.editingPath ? "#20ffffff" : (GemaTheme.darkText ? "#22ffffff" : "#180b0f1a")
                bottomColor: GemaTheme.darkText ? "#14ffffff" : "#1e080c15"
                edgeColor: window.editingPath ? GemaTheme.accentAlpha(0.75) : "#30ffffff"

                TextField {
                    id: pathInput
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    visible: window.editingPath
                    selectByMouse: true
                    placeholderText: "Ruta absoluta del archivo…"
                    placeholderTextColor: GemaTheme.placeholderColor
                    color: GemaTheme.textColor
                    selectionColor: GemaTheme.accentAlpha(0.45)
                    selectedTextColor: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    background: null
                    onAccepted: {
                        const target = pathInput.text.trim();
                        window.editingPath = false;
                        if (target.length > 0) window.bridge.openFile(target);
                    }
                    onActiveFocusChanged: if (!pathInput.activeFocus && window.editingPath) window.editingPath = false
                    Keys.onEscapePressed: window.editingPath = false
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    spacing: 8
                    visible: !window.editingPath

                    GlassIcon {
                        name: window.bridge.hasFile ? window.kindIcon(window.bridge.kind) : "folder-open"
                        size: 14
                        color: GemaTheme.accent
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: window.bridge.hasFile ? window.bridge.fileName : "Ningún archivo abierto (Ctrl+O o Ctrl+L)"
                        textFormat: Text.PlainText
                        color: window.bridge.hasFile ? GemaTheme.textColor : GemaTheme.placeholderColor
                        font.pixelSize: 13
                        font.weight: window.bridge.hasFile ? Font.DemiBold : Font.Normal
                        elide: Text.ElideMiddle
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.IBeamCursor
                            onClicked: window.startEditPath()
                        }
                    }

                    Rectangle {
                        visible: window.bridge.hasFile && window.bridge.extension.length > 0
                        implicitWidth: extTag.implicitWidth + 12
                        implicitHeight: 20
                        radius: 6
                        color: GemaTheme.accentAlpha(0.20)
                        border.width: 1
                        border.color: GemaTheme.accentAlpha(0.42)
                        Text {
                            id: extTag
                            anchors.centerIn: parent
                            text: window.bridge.extension
                            textFormat: Text.PlainText
                            color: GemaTheme.accent
                            font.family: "monospace"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }

                    Text {
                        visible: window.bridge.hasFile && window.bridge.siblings.length > 1 && window.bridge.siblingIndex >= 0 && window.width >= 780
                        text: (window.bridge.siblingIndex + 1) + " / " + window.bridge.siblings.length
                        textFormat: Text.PlainText
                        color: GemaTheme.subtleColor
                        font.pixelSize: 11
                        font.family: "monospace"
                    }

                    ActionButton {
                        iconName: "edit"
                        iconSize: 13
                        ghost: true
                        implicitWidth: 28
                        implicitHeight: 28
                        cornerRadius: 7
                        toolTipText: "Escribir ruta manualmente (Ctrl+L)"
                        onClicked: window.startEditPath()
                    }
                }
            }

            // Acciones rápidas derecha.
            ActionButton {
                iconName: "folder-open"
                text: window.width >= 760 ? "Abrir" : ""
                implicitHeight: 34
                toolTipText: "Abrir archivo (Ctrl+O)"
                onClicked: filePicker.open()
            }

            ActionButton {
                visible: window.bridge.hasFile
                iconName: "external-link"
                ghost: true
                implicitWidth: 34
                implicitHeight: 34
                toolTipText: "Abrir con aplicación externa"
                onClicked: window.bridge.openExternal(window.bridge.filePath)
            }

            ActionButton {
                visible: window.bridge.hasFile
                iconName: "sidebar"
                active: window.detailsOpen
                ghost: !window.detailsOpen
                implicitWidth: 34
                implicitHeight: 34
                toolTipText: window.detailsOpen ? "Ocultar detalles (Ctrl+I)" : "Detalles y lista de carpeta (Ctrl+I)"
                onClicked: window.detailsOpen = !window.detailsOpen
            }
        }

        // === ÁREA PRINCIPAL: VISOR ACTIVO + PANEL LATERAL DE DETALLES ===
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            // Escenario principal.
            GlassPanel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                topColor: GemaTheme.darkText ? "#1effffff" : "#140c101b"
                bottomColor: GemaTheme.darkText ? "#12ffffff" : "#20080b14"
                edgeColor: "#32ffffff"
                clip: true

                // Pantalla de bienvenida cuando no se ha abierto ningún archivo.
                Item {
                    anchors.fill: parent
                    visible: !window.bridge.hasFile && !window.bridge.loading

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(480, parent.width - 48)
                        spacing: 16

                        GlassPanel {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 72
                            implicitHeight: 72
                            radius: 20
                            topColor: GemaTheme.accentAlpha(0.28)
                            bottomColor: GemaTheme.accentAlpha(0.10)
                            edgeColor: GemaTheme.accentAlpha(0.65)
                            GlassIcon {
                                anchors.centerIn: parent
                                name: "eye"
                                size: 32
                                color: "#ffffff"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Visor universal Gema"
                                color: GemaTheme.textColor
                                font.pixelSize: 22
                                font.weight: Font.Bold
                            }
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: "Abre imágenes, vídeos, audio, documentos PDF y archivos de código o texto."
                                color: GemaTheme.mutedColor
                                font.pixelSize: 13
                                wrapMode: Text.Wrap
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8
                            Repeater {
                                model: [
                                    { icon: "image", label: "Imágenes" },
                                    { icon: "film", label: "Vídeos" },
                                    { icon: "file-text", label: "PDF" },
                                    { icon: "code", label: "Código" }
                                ]
                                delegate: GlassPanel {
                                    id: fmtPill
                                    required property var modelData
                                    implicitWidth: pillRow.implicitWidth + 18
                                    implicitHeight: 30
                                    radius: 9
                                    reflective: false
                                    topColor: "#16ffffff"
                                    bottomColor: "#0cffffff"
                                    edgeColor: "#28ffffff"
                                    RowLayout {
                                        id: pillRow
                                        anchors.centerIn: parent
                                        spacing: 6
                                        GlassIcon { name: fmtPill.modelData.icon; size: 13; color: GemaTheme.accent }
                                        Text { text: fmtPill.modelData.label; color: GemaTheme.mutedColor; font.pixelSize: 11; font.weight: Font.Medium }
                                    }
                                }
                            }
                        }

                        // Entrada rápida de ruta + botón Abrir archivo.
                        GlassPanel {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            radius: 11
                            highlighted: welcomePathInput.activeFocus
                            topColor: "#1a0b0f1a"
                            bottomColor: "#22080c15"
                            edgeColor: welcomePathInput.activeFocus ? GemaTheme.accentAlpha(0.75) : "#32ffffff"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 6
                                spacing: 8
                                TextField {
                                    id: welcomePathInput
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    placeholderText: "Pega una ruta absoluta y pulsa Enter…"
                                    placeholderTextColor: GemaTheme.placeholderColor
                                    color: GemaTheme.textColor
                                    selectionColor: GemaTheme.accentAlpha(0.45)
                                    selectedTextColor: "#ffffff"
                                    font.pixelSize: 13
                                    leftPadding: 0
                                    rightPadding: 0
                                    verticalAlignment: Text.AlignVCenter
                                    background: null
                                    onAccepted: {
                                        const t = welcomePathInput.text.trim();
                                        if (t.length > 0) window.bridge.openFile(t);
                                    }
                                }
                                ActionButton {
                                    iconName: "folder-open"
                                    text: "Elegir archivo"
                                    accent: true
                                    implicitHeight: 30
                                    cornerRadius: 8
                                    onClicked: filePicker.open()
                                }
                            }
                        }
                    }
                }

                // Visor de Imágenes.
                ImageViewer {
                    id: imageViewer
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: window.bridge.hasFile && window.bridge.kind === "image"
                    filePath: visible ? window.bridge.filePath : ""
                }

                // Visor de Vídeos y Audio.
                VideoViewer {
                    id: videoViewer
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: window.bridge.hasFile && (window.bridge.kind === "video" || window.bridge.kind === "audio")
                    filePath: visible ? window.bridge.filePath : ""
                    fileName: window.bridge.fileName
                    audioOnly: window.bridge.kind === "audio"
                }

                // Visor de Documentos PDF.
                PdfViewer {
                    id: pdfViewer
                    anchors.fill: parent
                    anchors.margins: 10
                    visible: window.bridge.hasFile && window.bridge.kind === "pdf"
                    filePath: visible ? window.bridge.filePath : ""
                    pageCount: window.bridge.pageCount
                    renderedPages: window.bridge.pdfPages
                    pageError: window.bridge.pdfError
                    onRequestPage: (page, dpi, resetQueue) => window.bridge.requestPdfPage(page, dpi, resetQueue)
                }

                // Visor de Texto y Código.
                TextViewer {
                    id: textViewer
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: window.bridge.hasFile && window.bridge.kind === "text"
                    content: visible ? window.bridge.textContent : ""
                    extension: window.bridge.extension
                    lineCount: window.bridge.lineCount
                    truncated: window.bridge.truncated
                }

                // Vista para archivos binarios no soportados directamente.
                Item {
                    anchors.fill: parent
                    visible: window.bridge.hasFile && window.bridge.kind === "unsupported"
                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 12
                        GlassPanel {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 64
                            implicitHeight: 64
                            radius: 18
                            topColor: "#1cffffff"
                            bottomColor: "#140a0e18"
                            edgeColor: "#38ffffff"
                            GlassIcon { anchors.centerIn: parent; name: "file"; size: 28; color: GemaTheme.mutedColor }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: window.bridge.fileName
                            textFormat: Text.PlainText
                            color: GemaTheme.textColor
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Formato binario sin vista previa integrada (" + window.sizeText(window.bridge.fileSize) + ")"
                            textFormat: Text.PlainText
                            color: GemaTheme.subtleColor
                            font.pixelSize: 12
                        }
                        ActionButton {
                            Layout.alignment: Qt.AlignHCenter
                            iconName: "external-link"
                            text: "Abrir con aplicación externa"
                            accent: true
                            onClicked: window.bridge.openExternal(window.bridge.filePath)
                        }
                    }
                }
            }

            // Panel lateral derecho colapsable: Metadatos + Archivos hermanos en la carpeta.
            GlassPanel {
                Layout.preferredWidth: 272
                Layout.fillHeight: true
                visible: window.detailsOpen && window.bridge.hasFile
                topColor: GemaTheme.darkText ? "#22ffffff" : "#14ffffff"
                bottomColor: GemaTheme.darkText ? "#14ffffff" : "#180a0e18"
                edgeColor: "#32ffffff"
                clip: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "DETALLES"
                        color: GemaTheme.subtleColor
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.4
                        leftPadding: 4
                    }

                    GlassPanel {
                        Layout.fillWidth: true
                        implicitHeight: detailsCol.implicitHeight + 4
                        radius: 11
                        reflective: false
                        topColor: "#160a0e18"
                        bottomColor: "#1e080b14"
                        edgeColor: "#26ffffff"

                        ColumnLayout {
                            id: detailsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 2
                            spacing: 0

                            MetaRow { label: "Tipo"; value: window.kindLabel(window.bridge.kind, window.bridge.extension) }
                            MetaRow { label: "Tamaño"; value: window.sizeText(window.bridge.fileSize) }
                            MetaRow {
                                visible: window.bridge.kind === "image" && imageViewer.naturalWidth > 0
                                label: "Resolución"
                                value: imageViewer.naturalWidth + " × " + imageViewer.naturalHeight + " px"
                            }
                            MetaRow {
                                visible: (window.bridge.kind === "video" || window.bridge.kind === "audio") && videoViewer.durationMs > 0
                                label: "Duración"
                                value: videoViewer.formatMs(videoViewer.durationMs)
                            }
                            MetaRow {
                                visible: window.bridge.kind === "pdf" && window.bridge.pageCount > 0
                                label: "Páginas"
                                value: String(window.bridge.pageCount)
                            }
                            MetaRow {
                                visible: window.bridge.kind === "pdf" && window.bridge.pdfTitle.length > 0
                                label: "Título"
                                value: window.bridge.pdfTitle
                            }
                            MetaRow {
                                visible: window.bridge.kind === "text"
                                label: "Líneas"
                                value: String(window.bridge.lineCount)
                            }
                            MetaRow { label: "Modificado"; value: window.dateText(window.bridge.mtime) }
                            MetaRow { label: "Permisos"; value: window.bridge.permissions || "—" }
                            MetaRow { label: "Carpeta"; value: window.bridge.parentPath || "/"; divider: false }
                        }
                    }

                    ActionButton {
                        Layout.fillWidth: true
                        iconName: "copy"
                        text: "Copiar ruta"
                        implicitHeight: 30
                        onClicked: window.copyText(window.bridge.filePath, "Ruta copiada")
                    }

                    Text {
                        visible: window.bridge.siblings.length > 0
                        text: "EN ESTA CARPETA (" + window.bridge.siblings.length + ")"
                        color: GemaTheme.subtleColor
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1.2
                        leftPadding: 4
                    }

                    ListView {
                        id: siblingList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 2
                        model: window.bridge.siblings
                        ScrollBar.vertical: GlassScrollBar {}

                        delegate: Rectangle {
                            id: sibRow
                            required property var modelData
                            required property int index
                            readonly property bool isCurrent: sibRow.modelData.path === window.bridge.filePath
                            width: siblingList.width
                            height: 32
                            radius: 8
                            color: sibRow.isCurrent
                                   ? GemaTheme.accentAlpha(0.24)
                                   : (sibMouse.containsMouse ? "#1affffff" : "transparent")
                            border.width: sibRow.isCurrent ? 1 : 0
                            border.color: GemaTheme.accentAlpha(0.45)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                GlassIcon {
                                    name: window.kindIcon(sibRow.modelData.kind)
                                    size: 13
                                    color: sibRow.isCurrent ? GemaTheme.accent : GemaTheme.mutedColor
                                }
                                Text {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: sibRow.modelData.name
                                    textFormat: Text.PlainText
                                    color: sibRow.isCurrent ? GemaTheme.textColor : GemaTheme.mutedColor
                                    font.pixelSize: 12
                                    font.weight: sibRow.isCurrent ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideMiddle
                                }
                            }

                            MouseArea {
                                id: sibMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.bridge.openFile(sibRow.modelData.path)
                            }
                        }
                    }
                }
            }
        }

        // === BARRA DE ESTADO INFERIOR ===
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 8

            Rectangle {
                implicitWidth: 7
                implicitHeight: 7
                radius: 3.5
                color: window.bridge.error
                       ? GemaTheme.dangerColor
                       : (window.statusMessage || window.bridge.loading)
                         ? GemaTheme.accent
                         : GemaTheme.accentAlpha(0.55)
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: {
                    if (window.bridge.error) return window.bridge.error;
                    if (window.statusMessage) return window.statusMessage;
                    if (window.bridge.loading) return "Cargando archivo…";
                    if (!window.bridge.hasFile) return "Listo · Abre un archivo para visualizarlo";
                    let parts = [window.kindLabel(window.bridge.kind, window.bridge.extension), window.sizeText(window.bridge.fileSize)];
                    if (window.bridge.kind === "image" && imageViewer.naturalWidth > 0)
                        parts.push(imageViewer.naturalWidth + "×" + imageViewer.naturalHeight);
                    else if (window.bridge.kind === "pdf" && window.bridge.pageCount > 0)
                        parts.push("Página " + pdfViewer.currentPage + " de " + window.bridge.pageCount);
                    else if (window.bridge.kind === "text")
                        parts.push(window.bridge.lineCount + " líneas");
                    parts.push(window.dateText(window.bridge.mtime));
                    return parts.join("  ·  ");
                }
                textFormat: Text.PlainText
                color: window.bridge.error ? GemaTheme.dangerColor : GemaTheme.mutedColor
                elide: Text.ElideRight
                font.pixelSize: 12
            }

            Text {
                visible: window.width >= 780
                text: {
                    if (window.bridge.kind === "image") return "Scroll zoom  ·  R rotar  ·  ←/→ galería  ·  Ctrl+I detalles";
                    if (window.bridge.kind === "video" || window.bridge.kind === "audio") return "Espacio reproducir  ·  J/L ±10s  ·  M silenciar  ·  Alt+←/→ archivos";
                    if (window.bridge.kind === "pdf") return "RePág/AvPág páginas  ·  Ctrl+Scroll zoom  ·  Alt+←/→ archivos";
                    if (window.bridge.kind === "text") return "Ctrl+F buscar  ·  Ctrl+Scroll tamaño  ·  Alt+←/→ archivos";
                    return "Ctrl+O abrir  ·  Ctrl+L ruta";
                }
                textFormat: Text.PlainText
                color: GemaTheme.subtleColor
                opacity: 0.72
                font.pixelSize: 11
            }
        }
    }

    Connections {
        target: window.bridge
        function onStatusNotice(msg) { window.showStatus(msg); }
        function onFileOpened() {
            window.editingPath = false;
            if (window.bridge.kind !== "video" && window.bridge.kind !== "audio") {
                videoViewer.stopMedia();
            }
        }
    }

    // === ATAJOS DE TECLADO ===
    Shortcut { sequence: "Ctrl+O"; onActivated: filePicker.open() }
    Shortcut { sequence: "Ctrl+L"; onActivated: window.startEditPath() }
    Shortcut { sequence: "Ctrl+I"; enabled: window.bridge.hasFile; onActivated: window.detailsOpen = !window.detailsOpen }
    Shortcut { sequence: "Alt+Left"; enabled: window.bridge.canPrev; onActivated: window.bridge.prevFile() }
    Shortcut { sequence: "Alt+Right"; enabled: window.bridge.canNext; onActivated: window.bridge.nextFile() }
    Shortcut { sequence: "Left"; enabled: !window.textInputFocused && window.bridge.kind === "image" && window.bridge.canPrev; onActivated: window.bridge.prevFile() }
    Shortcut { sequence: "Right"; enabled: !window.textInputFocused && window.bridge.kind === "image" && window.bridge.canNext; onActivated: window.bridge.nextFile() }
    Shortcut { sequence: "PgUp"; enabled: window.bridge.kind === "pdf"; onActivated: pdfViewer.prevPage() }
    Shortcut { sequence: "PgDown"; enabled: window.bridge.kind === "pdf"; onActivated: pdfViewer.nextPage() }
    Shortcut { sequence: "Space"; enabled: !window.textInputFocused && (window.bridge.kind === "video" || window.bridge.kind === "audio"); onActivated: videoViewer.togglePlay() }
    Shortcut { sequence: "M"; enabled: !window.textInputFocused && (window.bridge.kind === "video" || window.bridge.kind === "audio"); onActivated: videoViewer.toggleMute() }
    Shortcut { sequence: "J"; enabled: !window.textInputFocused && (window.bridge.kind === "video" || window.bridge.kind === "audio"); onActivated: videoViewer.seekRelative(-10000) }
    Shortcut { sequence: "L"; enabled: !window.textInputFocused && (window.bridge.kind === "video" || window.bridge.kind === "audio"); onActivated: videoViewer.seekRelative(10000) }
    Shortcut { sequence: "R"; enabled: !window.textInputFocused && window.bridge.kind === "image"; onActivated: imageViewer.rotateRight() }
    Shortcut { sequence: "Shift+R"; enabled: !window.textInputFocused && window.bridge.kind === "image"; onActivated: imageViewer.rotateLeft() }
    Shortcut { sequence: "0"; enabled: !window.textInputFocused && window.bridge.kind === "image"; onActivated: imageViewer.setFit() }
    Shortcut { sequence: "1"; enabled: !window.textInputFocused && window.bridge.kind === "image"; onActivated: imageViewer.setActualSize() }
    Shortcut { sequence: "Ctrl+F"; enabled: window.bridge.kind === "text"; onActivated: textViewer.focusSearch() }
    Shortcut {
        sequence: "Ctrl++"
        onActivated: {
            if (window.bridge.kind === "image") imageViewer.zoomBy(1.25);
            else if (window.bridge.kind === "pdf") pdfViewer.zoomBy(0.15);
            else if (window.bridge.kind === "text") textViewer.zoomFont(1);
        }
    }
    Shortcut {
        sequence: "Ctrl+="
        onActivated: {
            if (window.bridge.kind === "image") imageViewer.zoomBy(1.25);
            else if (window.bridge.kind === "pdf") pdfViewer.zoomBy(0.15);
            else if (window.bridge.kind === "text") textViewer.zoomFont(1);
        }
    }
    Shortcut {
        sequence: "Ctrl+-"
        onActivated: {
            if (window.bridge.kind === "image") imageViewer.zoomBy(1 / 1.25);
            else if (window.bridge.kind === "pdf") pdfViewer.zoomBy(-0.15);
            else if (window.bridge.kind === "text") textViewer.zoomFont(-1);
        }
    }
    Shortcut {
        sequence: "Ctrl+0"
        onActivated: {
            if (window.bridge.kind === "image") imageViewer.setFit();
            else if (window.bridge.kind === "pdf") pdfViewer.resetZoom();
            else if (window.bridge.kind === "text") textViewer.resetFont();
        }
    }
}
