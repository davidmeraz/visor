pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Visor de texto y código con numeración de líneas, ajuste de línea, búsqueda y zoom de fuente.
Item {
    id: root
    property string content: ""
    property string extension: ""
    property int lineCount: 0
    property bool truncated: false
    property bool wordWrap: false
    property int fontSize: 13
    property bool copied: false
    property real wheelAccum: 0
    property int matchIndex: -1
    property var matchOffsets: []

    readonly property var linesModel: root.content.length > 0 ? root.content.split("\n") : []

    function focusSearch() {
        searchBar.visible = true;
        findInput.forceActiveFocus();
        findInput.selectAll();
    }
    function zoomFont(delta) {
        fontSize = Math.max(10, Math.min(26, fontSize + delta));
    }
    function resetFont() {
        fontSize = 13;
    }
    function recomputeMatches() {
        const q = findInput.text.toLowerCase();
        if (!q || !root.content) {
            matchOffsets = [];
            matchIndex = -1;
            return;
        }
        const hay = root.content.toLowerCase();
        const hits = [];
        let pos = 0;
        while (hits.length < 500) {
            const idx = hay.indexOf(q, pos);
            if (idx < 0) break;
            hits.push(idx);
            pos = idx + Math.max(1, q.length);
        }
        matchOffsets = hits;
        matchIndex = hits.length > 0 ? 0 : -1;
        if (matchIndex >= 0) selectCurrentMatch();
    }
    function selectCurrentMatch() {
        if (matchIndex < 0 || matchIndex >= matchOffsets.length) return;
        const start = matchOffsets[matchIndex];
        const end = start + findInput.text.length;
        codeEditor.select(start, end);
        const rect = codeEditor.positionToRectangle(start);
        const targetY = Math.max(0, Math.min(codeFlick.contentHeight - codeFlick.height, rect.y - codeFlick.height * 0.35));
        codeFlick.contentY = targetY;
    }
    function nextMatch() {
        if (matchOffsets.length === 0) return;
        matchIndex = (matchIndex + 1) % matchOffsets.length;
        selectCurrentMatch();
    }
    function prevMatch() {
        if (matchOffsets.length === 0) return;
        matchIndex = (matchIndex - 1 + matchOffsets.length) % matchOffsets.length;
        selectCurrentMatch();
    }
    function copyAll() {
        const prevStart = codeEditor.selectionStart;
        const prevEnd = codeEditor.selectionEnd;
        codeEditor.selectAll();
        codeEditor.copy();
        codeEditor.select(prevStart, prevEnd);
        copied = true;
        copiedTimer.restart();
    }

    onContentChanged: {
        codeFlick.contentX = 0;
        codeFlick.contentY = 0;
        recomputeMatches();
    }

    Timer { id: copiedTimer; interval: 1800; onTriggered: root.copied = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        // Barra superior contextual de código/texto.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                implicitWidth: langMeta.implicitWidth + 16
                implicitHeight: 26
                radius: 8
                color: GemaTheme.accentAlpha(0.18)
                border.width: 1
                border.color: GemaTheme.accentAlpha(0.38)
                Text {
                    id: langMeta
                    anchors.centerIn: parent
                    text: (root.extension ? root.extension + "  ·  " : "") + root.lineCount + (root.lineCount === 1 ? " línea" : " líneas")
                    textFormat: Text.PlainText
                    color: GemaTheme.accent
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                visible: root.truncated
                implicitWidth: truncLabel.implicitWidth + 14
                implicitHeight: 26
                radius: 8
                color: "#28f1ce70"
                border.width: 1
                border.color: "#66f1ce70"
                Text {
                    id: truncLabel
                    anchors.centerIn: parent
                    text: "Vista parcial (primeros 512 KiB)"
                    color: "#f1ce70"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            // Buscador interno (Ctrl+F).
            GlassPanel {
                id: searchBar
                visible: false
                implicitWidth: 230
                implicitHeight: 30
                radius: 9
                highlighted: findInput.activeFocus
                topColor: "#1a0b0f1a"
                bottomColor: "#22080c15"
                edgeColor: findInput.activeFocus ? GemaTheme.accentAlpha(0.75) : "#32ffffff"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 4
                    spacing: 4
                    GlassIcon { name: "search"; size: 13; color: GemaTheme.subtleColor }
                    TextField {
                        id: findInput
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 0
                        placeholderText: "Buscar en archivo…"
                        placeholderTextColor: GemaTheme.placeholderColor
                        color: GemaTheme.textColor
                        selectionColor: GemaTheme.accentAlpha(0.45)
                        selectedTextColor: "#ffffff"
                        font.pixelSize: 12
                        leftPadding: 0
                        rightPadding: 0
                        verticalAlignment: Text.AlignVCenter
                        background: null
                        onTextChanged: root.recomputeMatches()
                        onAccepted: root.nextMatch()
                        Keys.onEscapePressed: { findInput.clear(); searchBar.visible = false; }
                    }
                    Text {
                        visible: findInput.text.length > 0
                        text: root.matchOffsets.length > 0 ? ((root.matchIndex + 1) + "/" + root.matchOffsets.length) : "0"
                        color: root.matchOffsets.length > 0 ? GemaTheme.accent : GemaTheme.dangerColor
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                    ActionButton {
                        iconName: "chevron-up"
                        iconSize: 12
                        ghost: true
                        implicitWidth: 22
                        implicitHeight: 22
                        cornerRadius: 6
                        enabled: root.matchOffsets.length > 0
                        onClicked: root.prevMatch()
                    }
                    ActionButton {
                        iconName: "chevron-down"
                        iconSize: 12
                        ghost: true
                        implicitWidth: 22
                        implicitHeight: 22
                        cornerRadius: 6
                        enabled: root.matchOffsets.length > 0
                        onClicked: root.nextMatch()
                    }
                    ActionButton {
                        iconName: "x"
                        iconSize: 12
                        ghost: true
                        implicitWidth: 22
                        implicitHeight: 22
                        cornerRadius: 6
                        onClicked: { findInput.clear(); searchBar.visible = false; }
                    }
                }
            }

            ActionButton {
                iconName: "search"
                iconSize: 14
                ghost: !searchBar.visible
                active: searchBar.visible
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Buscar texto (Ctrl+F)"
                onClicked: {
                    if (searchBar.visible) { findInput.clear(); searchBar.visible = false; }
                    else root.focusSearch();
                }
            }

            ActionButton {
                iconName: "wrap"
                iconSize: 14
                ghost: !root.wordWrap
                active: root.wordWrap
                implicitWidth: 30
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: root.wordWrap ? "Desactivar ajuste de línea" : "Ajustar líneas largas"
                onClicked: root.wordWrap = !root.wordWrap
            }

            ActionButton {
                iconName: "zoom-out"
                iconSize: 13
                ghost: true
                implicitWidth: 28
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Reducir texto (Ctrl+-)"
                onClicked: root.zoomFont(-1)
            }

            Text {
                text: root.fontSize + "px"
                color: GemaTheme.mutedColor
                font.pixelSize: 11
                font.family: "monospace"
            }

            ActionButton {
                iconName: "zoom-in"
                iconSize: 13
                ghost: true
                implicitWidth: 28
                implicitHeight: 30
                cornerRadius: 8
                toolTipText: "Aumentar texto (Ctrl++)"
                onClicked: root.zoomFont(1)
            }

            ActionButton {
                iconName: root.copied ? "check" : "copy"
                text: root.copied ? "Copiado" : "Copiar"
                accent: root.copied
                implicitHeight: 30
                horizontalPadding: 10
                cornerRadius: 8
                toolTipText: "Copiar todo el contenido"
                onClicked: root.copyAll()
            }
        }

        // Lienzo de texto con canal de números de línea.
        GlassPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 12
            topColor: GemaTheme.darkText ? "#22ffffff" : "#1c0a0d17"
            bottomColor: GemaTheme.darkText ? "#14ffffff" : "#26070a12"
            edgeColor: "#2effffff"
            clip: true

            Flickable {
                id: codeFlick
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: root.wordWrap ? width : Math.max(width, gutterCol.width + codeEditor.implicitWidth + 32)
                contentHeight: Math.max(height, codeEditor.implicitHeight + 24)
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
                            root.zoomFont(dy > 0 ? 1 : -1);
                            return;
                        }
                        root.wheelAccum += dy;
                        if (Math.abs(root.wheelAccum) >= 70) {
                            const up = root.wheelAccum > 0;
                            root.wheelAccum = 0;
                            root.zoomFont(up ? 1 : -1);
                        }
                    }
                }

                // Canal de numeración de líneas (visible cuando no hay wordWrap).
                Rectangle {
                    id: gutterCol
                    visible: !root.wordWrap && root.linesModel.length <= 4000
                    x: 0
                    y: 0
                    width: visible ? Math.max(44, String(root.lineCount).length * 9 + 22) : 0
                    height: Math.max(codeFlick.height, codeEditor.implicitHeight + 24)
                    color: GemaTheme.darkText ? "#10000000" : "#1805070e"

                    Text {
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        horizontalAlignment: Text.AlignRight
                        color: GemaTheme.subtleColor
                        opacity: 0.65
                        font.family: "JetBrainsMono Nerd Font, Adwaita Mono, monospace"
                        font.pixelSize: root.fontSize
                        textFormat: Text.PlainText
                        text: {
                            if (!gutterCol.visible) return "";
                            const total = Math.max(1, root.linesModel.length);
                            let out = "";
                            for (let i = 1; i <= total; ++i) {
                                out += i;
                                if (i < total) out += "\n";
                            }
                            return out;
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        width: 1
                        color: "#1effffff"
                    }
                }

                TextEdit {
                    id: codeEditor
                    x: gutterCol.width + 12
                    y: 10
                    width: root.wordWrap ? Math.max(120, codeFlick.width - gutterCol.width - 24) : Math.max(codeFlick.width - gutterCol.width - 24, implicitWidth)
                    readOnly: true
                    selectByMouse: true
                    textFormat: TextEdit.PlainText
                    wrapMode: root.wordWrap ? TextEdit.WrapAtWordBoundaryOrAnywhere : TextEdit.NoWrap
                    text: root.content
                    color: GemaTheme.textColor
                    selectionColor: GemaTheme.accentAlpha(0.45)
                    selectedTextColor: "#ffffff"
                    font.family: "JetBrainsMono Nerd Font, Adwaita Mono, monospace"
                    font.pixelSize: root.fontSize
                }
            }
        }
    }
}
