// Screen brightness in %, scroll to change. Read from sysfs (sysfs files can't be
// watched, so it is re-read every second; cheap).
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

BarButton {
    id: root

    property string device: ""
    readonly property int percent: max.text() > 0 ? Math.round(cur.text() / max.text() * 100) : 0

    visible: device !== ""
    iconText: false
    text: percent + "%  \u{F00E0}"

    function step(dir) {
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%" + (dir > 0 ? "+" : "-")]);
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

    onWheel: w => {
        step(w.angleDelta.y);
        cur.reload();
    }
}
