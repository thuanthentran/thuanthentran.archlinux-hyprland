// Screen brightness: icon (scroll to change, % in the tooltip); expanded adds a slider.
// Read from sysfs (sysfs files can't be watched, so it is re-read every second; cheap).
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

BarButton {
    id: root

    property string device: ""
    readonly property real level: max.text() > 0 ? cur.text() / max.text() : 0
    property real pending: -1      // value being dragged to, shown until sysfs catches up

    function step(dir) {
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%" + (dir > 0 ? "+" : "-")]);
        refresh.restart();
    }

    visible: device !== ""
    text: "\u{F00E0}"
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    tooltip: BarState.expanded ? "" : Math.round(level * 100) + "%"

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: BarState.expanded

        BarSlider {
            anchors.verticalCenter: parent.verticalCenter
            value: root.pending >= 0 ? root.pending : root.level
            onMoved: v => {
                root.pending = Math.max(0.01, v);
                apply.restart();
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: Math.round((root.pending >= 0 ? root.pending : root.level) * 100) + "%"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }
    FileView {
        id: cur
        path: root.device ? "/sys/class/backlight/" + root.device + "/brightness" : ""
    }
    FileView {
        id: max
        path: root.device ? "/sys/class/backlight/" + root.device + "/max_brightness" : ""
    }
    Timer {
        running: root.device !== ""
        repeat: true
        interval: 1000
        onTriggered: cur.reload()
    }
    // Dragging fires many values; send at most one brightnessctl call per 60 ms
    Timer {
        id: apply
        interval: 60
        onTriggered: {
            Quickshell.execDetached(["brightnessctl", "-n2", "set", Math.round(root.pending * 100) + "%"]);
            refresh.restart();
        }
    }
    Timer {
        id: refresh
        interval: 150
        onTriggered: {
            cur.reload();
            if (!apply.running)
                root.pending = -1;
        }
    }

    onClicked: if (!BarState.expanded) BarState.expanded = true
    onWheel: w => step(w.angleDelta.y)
}
