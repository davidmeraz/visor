//@ pragma AppId dev.gema.visor
import Quickshell
import "ui"

// Punto de entrada Gema UI Kit para Visor: conecta VisorBridge con VisorWindow.
ShellRoot {
    VisorBridge { id: visorBridge }

    VisorWindow {
        bridge: visorBridge
        onClosed: Qt.quit()
    }
}
