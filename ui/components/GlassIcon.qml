pragma ComponentBehavior: Bound
import QtQuick

// Iconografía vectorial unificada (trazo limpio 24x24) para Visor + GemaTheme.
Item {
    id: root
    property string name: ""
    property color color: GemaTheme.textColor
    property int size: 16
    property real strokeWidth: 1.8

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    function hexChannel(v) {
        const n = Math.round(Math.max(0, Math.min(1, v)) * 255);
        const h = n.toString(16);
        return h.length < 2 ? "0" + h : h;
    }

    function hexColor(c) {
        return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b);
    }

    function bodyFor(iconName) {
        switch (iconName) {
        case "eye":
            return '<path d="M2.1 12.3a1 1 0 0 1 0-.6A10.7 10.7 0 0 1 21.9 11.7a1 1 0 0 1 0 .6A10.7 10.7 0 0 1 2.1 12.3"/><circle cx="12" cy="12" r="3"/>';
        case "chevron-left":
            return '<path d="m15 18-6-6 6-6"/>';
        case "chevron-right":
            return '<path d="m9 18 6-6-6-6"/>';
        case "chevron-up":
            return '<path d="m18 15-6-6-6 6"/>';
        case "chevron-down":
            return '<path d="m6 9 6 6 6-6"/>';
        case "folder-open":
            return '<path d="m6 14 1.5-2.9A2 2 0 0 1 9.24 10H20a2 2 0 0 1 1.94 2.5l-1.54 6a2 2 0 0 1-1.95 1.5H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H18a2 2 0 0 1 2 2v2"/>';
        case "image":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.1-3.1a2 2 0 0 0-2.8 0L6 21"/>';
        case "film":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><path d="M7 3v18"/><path d="M3 7.5h4"/><path d="M3 12h18"/><path d="M3 16.5h4"/><path d="M17 3v18"/><path d="M17 7.5h4"/><path d="M17 16.5h4"/>';
        case "music":
            return '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>';
        case "file-text":
            return '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/>';
        case "code":
            return '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>';
        case "file":
            return '<path d="M15 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7Z"/><path d="M14 2v4a2 2 0 0 0 2 2h4"/>';
        case "play":
            return '<polygon points="7.5 4.8 19.5 12 7.5 19.2 7.5 4.8" fill="currentColor"/>';
        case "pause":
            return '<rect x="6" y="4.5" width="4" height="15" rx="1" fill="currentColor"/><rect x="14" y="4.5" width="4" height="15" rx="1" fill="currentColor"/>';
        case "skip-back":
            return '<polygon points="19 20 9 12 19 4 19 20"/><line x1="5" x2="5" y1="19" y2="5"/>';
        case "skip-forward":
            return '<polygon points="5 4 15 12 5 20 5 4"/><line x1="19" x2="19" y1="5" y2="19"/>';
        case "volume-2":
            return '<path d="M11 5 6 9H2v6h4l5 4z"/><path d="M15.5 8.5a5 5 0 0 1 0 7"/><path d="M19.1 5a10 10 0 0 1 0 14"/>';
        case "volume-x":
            return '<path d="M11 5 6 9H2v6h4l5 4z"/><line x1="22" x2="16" y1="9" y2="15"/><line x1="16" x2="22" y1="9" y2="15"/>';
        case "zoom-in":
            return '<circle cx="11" cy="11" r="7.5"/><line x1="20.5" x2="16.4" y1="20.5" y2="16.4"/><line x1="11" x2="11" y1="8" y2="14"/><line x1="8" x2="14" y1="11" y2="11"/>';
        case "zoom-out":
            return '<circle cx="11" cy="11" r="7.5"/><line x1="20.5" x2="16.4" y1="20.5" y2="16.4"/><line x1="8" x2="14" y1="11" y2="11"/>';
        case "fit":
            return '<path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/>';
        case "rotate-cw":
            return '<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>';
        case "rotate-ccw":
            return '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>';
        case "external-link":
            return '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>';
        case "copy":
            return '<rect width="13" height="13" x="9" y="9" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/>';
        case "check":
            return '<path d="M20 6 9 17l-5-5"/>';
        case "search":
            return '<circle cx="11" cy="11" r="7.5"/><path d="m20.5 20.5-4.1-4.1"/>';
        case "x":
            return '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>';
        case "wrap":
            return '<line x1="3" x2="21" y1="6" y2="6"/><path d="M3 12h15a3 3 0 1 1 0 6h-4"/><polyline points="16 16 14 18 16 20"/><line x1="3" x2="10" y1="18" y2="18"/>';
        case "info":
            return '<circle cx="12" cy="12" r="9.5"/><path d="M12 16v-4"/><circle cx="12" cy="8.2" r="0.6" fill="currentColor"/>';
        case "edit":
            return '<path d="M21.17 6.81a1 1 0 0 0-3.98-3.98L3.84 16.17a2 2 0 0 0-.5.83l-1.32 4.35a.5.5 0 0 0 .62.62l4.35-1.32a2 2 0 0 0 .83-.5z"/><path d="m15 5 4 4"/>';
        case "sidebar":
            return '<rect width="18" height="18" x="3" y="3" rx="2.5"/><path d="M15 3v18"/>';
        default:
            return "";
        }
    }

    readonly property string svgBody: bodyFor(name)
    readonly property string strokeHex: hexColor(color)

    Image {
        anchors.fill: parent
        visible: root.svgBody.length > 0
        opacity: root.color.a
        smooth: true
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(Math.max(24, root.size * 2), Math.max(24, root.size * 2))
        source: root.svgBody.length > 0
                ? "data:image/svg+xml;utf8," + encodeURIComponent(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" color="'
                      + root.strokeHex + '" fill="none" stroke="'
                      + root.strokeHex + '" stroke-width="' + root.strokeWidth
                      + '" stroke-linecap="round" stroke-linejoin="round">'
                      + root.svgBody + '</svg>')
                : ""
    }
}
