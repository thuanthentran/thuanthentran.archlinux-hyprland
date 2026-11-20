// Thin Wi-Fi signal icon: a dot and three arcs, lit up to the signal level (0..1),
// the rest faint. Drawn instead of a Nerd Font glyph so the strokes stay hairline-thin.
import QtQuick

Canvas {
    id: root

    property real level: 0
    property color color: "white"
    readonly property int lit: level <= 0 ? 0 : Math.max(1, Math.min(3, Math.ceil(level * 3)))

    implicitWidth: 18
    implicitHeight: 14
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onLitChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const cx = width / 2, cy = height - 1.5;
        const dim = Qt.rgba(color.r, color.g, color.b, 0.28);

        ctx.beginPath();
        ctx.arc(cx, cy, 1.5, 0, 2 * Math.PI);
        ctx.fillStyle = color;
        ctx.fill();

        ctx.lineWidth = 1.5;
        ctx.lineCap = "round";
        const step = (height - 3) / 3;
        for (let i = 1; i <= 3; i++) {
            ctx.beginPath();
            ctx.arc(cx, cy, step * i + 1, Math.PI * 1.25, Math.PI * 1.75);
            ctx.strokeStyle = i <= lit ? color : dim;
            ctx.stroke();
        }
    }
}
