import QtQuick
import Quickshell
import Quickshell.Io

// Puente IPC JSON-Lines v2 sobre stdin/stdout para Visor (motor Rust).
QtObject {
    id: bridge
    property bool ready: false
    property bool loading: false
    property string appName: "Visor"
    property string appVersion: "0.1.0"
    property string error: ""
    property string filePath: ""
    property string fileName: ""
    property string parentPath: ""
    property string extension: ""
    property string kind: ""
    property double fileSize: 0
    property double mtime: 0
    property string permissions: ""
    property var siblings: []
    property int siblingIndex: -1
    property string textContent: ""
    property int lineCount: 0
    property bool truncated: false
    property int pageCount: 0
    property string pdfTitle: ""
    property string pdfAuthor: ""
    property string pageSize: ""
    property bool pdfAvailable: true
    property var pdfPages: ({})
    property string pdfError: ""
    property int pdfGeneration: 0

    readonly property bool hasFile: filePath.length > 0
    readonly property bool canPrev: ready && !loading && siblingIndex > 0
    readonly property bool canNext: ready && !loading && siblingIndex >= 0 && siblingIndex < siblings.length - 1
    readonly property string initialEnvPath: Quickshell.env("VISOR_FILE_PATH") || ""

    signal fileOpened()
    signal statusNotice(string message)

    function openFile(targetPath) {
        if (!ready || !targetPath) return;
        loading = true;
        error = "";
        pdfError = "";
        backend.write(JSON.stringify({version: 2, type: "viewer.open", data: {path: targetPath}}) + "\n");
    }

    function prevFile() {
        if (!canPrev) return;
        const item = siblings[siblingIndex - 1];
        if (item && item.path) openFile(item.path);
    }

    function nextFile() {
        if (!canNext) return;
        const item = siblings[siblingIndex + 1];
        if (item && item.path) openFile(item.path);
    }

    function requestPdfPage(page, dpi, resetQueue) {
        if (!ready || kind !== "pdf" || !filePath || page < 1) return;
        if (resetQueue) pdfGeneration += 1;
        else if (pdfGeneration === 0) pdfGeneration = 1;
        pdfError = "";
        backend.write(JSON.stringify({
            version: 2,
            type: "pdf.renderPage",
            data: {
                generation: pdfGeneration,
                path: filePath,
                page: page,
                dpi: dpi || 150,
                reset: Boolean(resetQueue)
            }
        }) + "\n");
    }

    function openExternal(targetPath) {
        const p = targetPath || filePath;
        if (!ready || !p) return;
        backend.write(JSON.stringify({version: 2, type: "viewer.openExternal", data: {path: p}}) + "\n");
    }

    function receive(line) {
        let event;
        try {
            event = JSON.parse(line);
            if (event.version !== 2 || !event.data || typeof event.type !== "string")
                throw new Error("Formato incompatible");
        } catch (e) {
            loading = false;
            error = "Error IPC: " + e.message;
            return;
        }
        const data = event.data;
        if (event.type === "app.ready") {
            ready = true;
            appName = data.name || "Visor";
            appVersion = data.version || "0.1.0";
            if (initialEnvPath.length > 0) openFile(initialEnvPath);
        } else if (event.type === "viewer.opened") {
            const changedFile = filePath !== data.path;
            filePath = data.path || "";
            fileName = data.name || "";
            parentPath = data.parent || "";
            extension = data.extension || "";
            kind = data.kind || "unsupported";
            fileSize = data.size || 0;
            mtime = data.mtime || 0;
            permissions = data.permissions || "";
            siblings = data.siblings || [];
            siblingIndex = typeof data.siblingIndex === "number" ? data.siblingIndex : -1;
            textContent = data.textContent || "";
            lineCount = data.lineCount || 0;
            truncated = Boolean(data.truncated);
            pageCount = data.pageCount || 0;
            pdfTitle = data.pdfTitle || "";
            pdfAuthor = data.pdfAuthor || "";
            pageSize = data.pageSize || "";
            pdfAvailable = data.pdfAvailable !== false;
            if (changedFile) {
                pdfPages = ({});
                pdfGeneration += 1;
            }
            pdfError = "";
            error = "";
            loading = false;
            fileOpened();
        } else if (event.type === "pdf.pageRendered") {
            if (data.path === filePath && typeof data.imagePath === "string" && data.imagePath.length > 0) {
                const key = data.page + "@" + data.dpi;
                const next = Object.assign({}, pdfPages);
                next[key] = data.imagePath;
                pdfPages = next;
            }
        } else if (event.type === "pdf.pageError") {
            if (data.path === filePath) {
                pdfError = data.message || "Error al renderizar página PDF.";
            }
        } else if (event.type === "pdf.pageQueued") {
            // Confirmación silenciosa.
        } else if (event.type === "viewer.externalOpened") {
            statusNotice("Abierto en aplicación externa");
        } else if (event.type === "error") {
            loading = false;
            error = data.message || "No se pudo abrir el archivo.";
        }
    }

    readonly property Process backend: Process {
        command: [Quickshell.shellDir + "/backend/run-backend.sh"]
        workingDirectory: Quickshell.shellDir
        stdinEnabled: true
        running: true
        stdout: SplitParser { onRead: data => bridge.receive(data) }
        stderr: SplitParser { onRead: data => console.warn("Visor backend: " + data) }
        onExited: (exitCode, exitStatus) => {
            bridge.ready = false;
            bridge.loading = false;
            bridge.error = "Motor desconectado (" + exitCode + ").";
        }
    }
}
