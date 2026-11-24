pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// Reproductor nativo de vídeo y audio con QtMultimedia y barra de transporte glassmorphism.
Item {
    id: root
    property string filePath: ""
    property string fileName: ""
    property bool audioOnly: false
    property real playbackSpeed: 1.0
    readonly property var speedSteps: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
    readonly property int durationMs: Math.max(0, player.duration)
    readonly property int positionMs: Math.max(0, player.position)

    function toFileUrl(p) {
        if (!p) return "";
        return "file://" + p.split("/").map(seg => encodeURIComponent(seg)).join("/");
    }
    function formatMs(ms) {
        if (!ms || ms <= 0) return "00:00";
        const total = Math.floor(ms / 1000);
        const hrs = Math.floor(total / 3600);
        const mins = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        const pad = n => (n < 10 ? "0" : "") + n;
        return hrs > 0 ? (hrs + ":" + pad(mins) + ":" + pad(secs)) : (pad(mins) + ":" + pad(secs));
    }
    function togglePlay() {
        if (player.playbackState === MediaPlayer.PlayingState) player.pause();
        else player.play();
    }
    function seekRelative(deltaMs) {
        if (root.durationMs <= 0) return;
        const target = Math.max(0, Math.min(root.durationMs, player.position + deltaMs));
        player.setPosition(target);
    }
    function toggleMute() {
        audioOut.muted = !audioOut.muted;
    }
    function cycleSpeed() {
        let idx = 2;
        for (let i = 0; i < speedSteps.length; ++i) {
            if (Math.abs(speedSteps[i] - playbackSpeed) < 0.05) { idx = i; break; }
        }
        playbackSpeed = speedSteps[(idx + 1) % speedSteps.length];
        player.playbackRate = playbackSpeed;
    }
    function stopMedia() {
        player.stop();
    }

    onFilePathChanged: {
        player.stop();
        playbackSpeed = 1.0;
        player.playbackRate = 1.0;
        if (filePath.length > 0) {
            player.source = toFileUrl(filePath);
            player.play();
        } else {
            player.source = "";
        }
    }

    AudioOutput {
        id: audioOut
        volume: 0.85
        muted: false
    }

    MediaPlayer {
        id: player
        audioOutput: audioOut
        videoOutput: videoOut
    }

    // Escenario de vídeo o tarjeta de audio.
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: transportBar.top
        anchors.bottomMargin: 10
        clip: true

        Rectangle {
            visible: !root.audioOnly
            anchors.fill: parent
            radius: 12
            color: "#c806080f"
            border.width: 1
            border.color: "#22ffffff"
        }

        VideoOutput {
            id: videoOut
            visible: !root.audioOnly
            anchors.fill: parent
            anchors.margins: 2
            fillMode: VideoOutput.PreserveAspectFit
        }

        // Vista elegante para archivos de audio (MP3, FLAC, WAV, OGG...).
        ColumnLayout {
            visible: root.audioOnly
            anchors.centerIn: parent
            spacing: 16
            width: Math.min(420, parent.width - 40)

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 112
                implicitHeight: 112

                Rectangle {
                    anchors.centerIn: parent
                    width: root.playing ? 112 : 98
                    height: width
                    radius: width / 2
                    color: GemaTheme.accentAlpha(root.playing ? 0.22 : 0.10)
                    Behavior on width { NumberAnimation { duration: GemaTheme.animations ? 260 : 0; easing.type: Easing.OutCubic } }
                }

                GlassPanel {
                    anchors.centerIn: parent
                    width: 86
                    height: 86
                    radius: 43
                    topColor: GemaTheme.accentAlpha(0.32)
                    bottomColor: GemaTheme.accentAlpha(0.14)
                    edgeColor: GemaTheme.accentAlpha(0.75)

                    GlassIcon {
                        anchors.centerIn: parent
                        name: "music"
                        size: 36
                        color: "#ffffff"
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.fileName
                textFormat: Text.PlainText
                color: GemaTheme.textColor
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideMiddle
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.playing ? "Reproduciendo audio" : "En pausa"
                textFormat: Text.PlainText
                color: GemaTheme.accent
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        // Error de reproducción si el códec o archivo falla.
        GlassPanel {
            visible: player.error !== MediaPlayer.NoError
            anchors.centerIn: parent
            implicitWidth: Math.min(440, parent.width - 40)
            implicitHeight: errCol.implicitHeight + 28
            radius: 14
            topColor: "#de18141e"
            bottomColor: "#ea100e17"
            edgeColor: "#70f38ba8"

            ColumnLayout {
                id: errCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: "No se pudo reproducir el archivo multimedia"
                    color: GemaTheme.dangerColor
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: player.errorString || "Formato o códec no soportado."
                    textFormat: Text.PlainText
                    color: GemaTheme.mutedColor
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Clic sobre el vídeo para pausar / reanudar.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlay()
        }

        // Botón central translúcido cuando el vídeo está pausado.
        Rectangle {
            visible: !root.audioOnly && !root.playing && player.error === MediaPlayer.NoError && root.filePath.length > 0
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 32
            color: "#b40b0f18"
            border.width: 1
            border.color: GemaTheme.accentAlpha(0.75)

            GlassIcon {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 2
                name: "play"
                size: 26
                color: "#ffffff"
            }
        }
    }

    // Barra inferior de transporte y línea de tiempo.
    GlassPanel {
        id: transportBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        implicitHeight: 74
        radius: 14
        topColor: "#cc141a26"
        bottomColor: "#dc0e121c"
        edgeColor: "#38ffffff"

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 6

            // Línea de tiempo interactiva (scrubber).
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    Layout.preferredWidth: 52
                    text: root.formatMs(root.positionMs)
                    textFormat: Text.PlainText
                    color: GemaTheme.mutedColor
                    font.family: "monospace"
                    font.pixelSize: 11
                }

                Item {
                    id: seekTrack
                    Layout.fillWidth: true
                    implicitHeight: 18

                    readonly property real progress: root.durationMs > 0
                        ? Math.max(0, Math.min(1, root.positionMs / root.durationMs))
                        : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: seekMouse.containsMouse || seekMouse.pressed ? 6 : 4
                        radius: height / 2
                        color: "#2cffffff"
                        Behavior on height { NumberAnimation { duration: GemaTheme.animDuration } }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.round(parent.width * seekTrack.progress)
                            radius: parent.radius
                            color: GemaTheme.accent
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(seekTrack.width * seekTrack.progress) - width / 2
                        width: seekMouse.containsMouse || seekMouse.pressed ? 14 : 10
                        height: width
                        radius: width / 2
                        color: "#ffffff"
                        border.width: 2
                        border.color: GemaTheme.accent
                        visible: root.durationMs > 0
                        Behavior on width { NumberAnimation { duration: GemaTheme.animDuration } }
                    }

                    MouseArea {
                        id: seekMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.durationMs > 0
                        function jumpTo(mx) {
                            const frac = Math.max(0, Math.min(1, mx / Math.max(1, seekTrack.width)));
                            player.setPosition(Math.round(frac * root.durationMs));
                        }
                        onPressed: (mouse) => jumpTo(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) jumpTo(mouse.x); }
                    }
                }

                Text {
                    Layout.preferredWidth: 52
                    horizontalAlignment: Text.AlignRight
                    text: root.formatMs(root.durationMs)
                    textFormat: Text.PlainText
                    color: GemaTheme.subtleColor
                    font.family: "monospace"
                    font.pixelSize: 11
                }
            }

            // Controles de reproducción, velocidad y volumen.
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                ActionButton {
                    iconName: "skip-back"
                    iconSize: 13
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 32
                    cornerRadius: 8
                    toolTipText: "Retroceder 10 s (J)"
                    onClicked: root.seekRelative(-10000)
                }

                ActionButton {
                    iconName: root.playing ? "pause" : "play"
                    iconSize: 15
                    accent: true
                    implicitWidth: 36
                    implicitHeight: 32
                    cornerRadius: 9
                    toolTipText: root.playing ? "Pausar (Espacio)" : "Reproducir (Espacio)"
                    onClicked: root.togglePlay()
                }

                ActionButton {
                    iconName: "skip-forward"
                    iconSize: 13
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 32
                    cornerRadius: 8
                    toolTipText: "Adelantar 10 s (L)"
                    onClicked: root.seekRelative(10000)
                }

                Item { Layout.fillWidth: true }

                ActionButton {
                    text: root.playbackSpeed.toFixed(root.playbackSpeed % 1 === 0 ? 1 : 2) + "×"
                    ghost: Math.abs(root.playbackSpeed - 1.0) < 0.05
                    active: Math.abs(root.playbackSpeed - 1.0) >= 0.05
                    implicitHeight: 28
                    horizontalPadding: 9
                    cornerRadius: 8
                    toolTipText: "Cambiar velocidad de reproducción"
                    onClicked: root.cycleSpeed()
                }

                ActionButton {
                    iconName: (audioOut.muted || audioOut.volume <= 0.01) ? "volume-x" : "volume-2"
                    iconSize: 15
                    ghost: true
                    implicitWidth: 32
                    implicitHeight: 32
                    cornerRadius: 8
                    toolTipText: audioOut.muted ? "Activar sonido (M)" : "Silenciar (M)"
                    onClicked: root.toggleMute()
                }

                // Control compacto de volumen.
                Item {
                    id: volTrack
                    implicitWidth: 84
                    implicitHeight: 20

                    readonly property real level: audioOut.muted ? 0 : audioOut.volume

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 4
                        radius: 2
                        color: "#2cffffff"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.round(parent.width * volTrack.level)
                            radius: 2
                            color: GemaTheme.accent
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(volTrack.width * volTrack.level) - width / 2
                        width: 11
                        height: 11
                        radius: 5.5
                        color: "#ffffff"
                        border.width: 2
                        border.color: GemaTheme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        function setVol(mx) {
                            const v = Math.max(0, Math.min(1, mx / Math.max(1, volTrack.width)));
                            audioOut.muted = false;
                            audioOut.volume = v;
                        }
                        onPressed: (mouse) => setVol(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) setVol(mouse.x); }
                    }
                }
            }
        }
    }
}
