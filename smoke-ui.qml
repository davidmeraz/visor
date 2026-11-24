//@ pragma AppId dev.gema.visor
import QtQuick
import Quickshell
import Quickshell.Io
import "ui"

ShellRoot {
    id: root
    property int phase: 0
    property int ticks: 0
    VisorBridge { id: bridge }
    VisorWindow {
        id: window
        bridge: bridge
    }
    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            ++root.ticks;
            if (root.ticks > 120) {
                console.error("SMOKE_ERROR: timeout en fase " + root.phase);
                Qt.quit();
                return;
            }
            if (bridge.error) {
                console.error("SMOKE_ERROR: " + bridge.error);
                Qt.quit();
                return;
            }
            if (!bridge.ready || bridge.loading) return;
            if (root.phase === 0) {
                if (bridge.kind !== "text" || bridge.lineCount !== 2 || !bridge.canNext) {
                    console.error("SMOKE_ERROR: apertura inicial texto o hermanos");
                    Qt.quit();
                    return;
                }
                root.phase = 1;
                bridge.nextFile();
            } else if (root.phase === 1) {
                if (bridge.kind !== "image" || !bridge.canPrev) {
                    console.error("SMOKE_ERROR: navegación a imagen hermana");
                    Qt.quit();
                    return;
                }
                console.log("VISOR_SMOKE_OK");
                Qt.quit();
            }
        }
    }
}
