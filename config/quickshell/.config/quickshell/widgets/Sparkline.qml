// Small area graph of values in 0..1, newest on the right; the x axis is always
// `length` samples wide, so a short history fills in from the right.
// Light style: no box, a hairline baseline, a smooth thin line, a fill that fades out
// downwards and a dot on the latest value.
import QtQuick

Canvas {
    id: root

    property var values: []
    property int length: 60
    property color color: "white"

    implicitWidth: 80
    implicitHeight: 22
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const pad = 2;                      // room for the line and dot at the top
        const h = height - pad;

        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.12);
        ctx.fillRect(0, height - 1, width, 1);

        const n = values.length;
        if (n < 2)
            return;
        const step = (width - pad) / (length - 1);
        const x0 = width - pad - (n - 1) * step;
        const pts = values.map((v, i) => [x0 + i * step, pad + (1 - Math.max(0, Math.min(1, v))) * (h - 1)]);

        // Smooth curve through the midpoints between samples
        function trace() {
            ctx.moveTo(pts[0][0], pts[0][1]);
            for (let i = 1; i < n - 1; i++) {
                const mx = (pts[i][0] + pts[i + 1][0]) / 2;
                const my = (pts[i][1] + pts[i + 1][1]) / 2;
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], mx, my);
            }
            ctx.lineTo(pts[n - 1][0], pts[n - 1][1]);
        }

        const grad = ctx.createLinearGradient(0, pad, 0, height);
        grad.addColorStop(0, Qt.rgba(color.r, color.g, color.b, 0.28));
        grad.addColorStop(1, Qt.rgba(color.r, color.g, color.b, 0));
        ctx.beginPath();
        trace();
        ctx.lineTo(pts[n - 1][0], height);
        ctx.lineTo(pts[0][0], height);
        ctx.closePath();
        ctx.fillStyle = grad;
        ctx.fill();

        ctx.beginPath();
        trace();
        ctx.lineWidth = 1.1;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.strokeStyle = color;
        ctx.stroke();

        const last = pts[n - 1];
        ctx.beginPath();
        ctx.arc(last[0], last[1], 1.8, 0, 2 * Math.PI);
        ctx.fillStyle = color;
        ctx.fill();
    }
}
