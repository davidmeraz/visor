import QtQuick

// Luz sobre agua de Gema UI Kit: velos y ondas suaves.
Canvas {
    id: reflection
    property real cornerRadius: 16
    property real strength: 1
    contextType: "2d"
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onCornerRadiusChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onPaint: {
        if (width <= 2 || height <= 2) return;
        const ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.beginPath();
        const radius = Math.min(cornerRadius, (width - 2) / 2, (height - 2) / 2);
        ctx.roundedRect(1, 1, width - 2, height - 2, radius, radius);
        ctx.clip();
        ctx.globalAlpha = strength;

        const sheen = ctx.createRadialGradient(width * 0.16, 0, 0,
                                               width * 0.16, 0, width * 0.85);
        sheen.addColorStop(0, "#16ffffff");
        sheen.addColorStop(0.45, "#07ffffff");
        sheen.addColorStop(1, "#00ffffff");
        ctx.fillStyle = sheen;
        ctx.fillRect(0, 0, width, height);

        const light = ctx.createLinearGradient(0, 0, width, 0);
        light.addColorStop(0, "#00ffffff");
        light.addColorStop(0.18, "#24ffffff");
        light.addColorStop(0.5, "#08ffffff");
        light.addColorStop(0.8, "#1cffffff");
        light.addColorStop(1, "#00ffffff");
        ctx.strokeStyle = light;
        const band = Math.min(height * 0.14, 65);
        for (let i = 0; i < 3; ++i) {
            const offset = i * 8;
            ctx.beginPath();
            ctx.moveTo(-width * 0.08, band * 0.45 + offset);
            ctx.bezierCurveTo(width * 0.18, -band * 0.2 + offset,
                              width * 0.31, band * 1.25 + offset,
                              width * 0.57, band * 0.6 + offset);
            ctx.bezierCurveTo(width * 0.78, -band * 0.15 + offset,
                              width * 0.95, band * 0.8 + offset,
                              width * 1.08, band * 0.3 + offset);
            ctx.globalAlpha = strength * 0.18;
            ctx.lineWidth = 9 - i * 2;
            ctx.stroke();
            ctx.globalAlpha = strength * (0.85 - i * 0.2);
            ctx.lineWidth = 1.1;
            ctx.stroke();
        }
    }
}
