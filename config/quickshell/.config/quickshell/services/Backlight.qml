// Screen backlight, shared by the bar slider and the OSD. `import qs`, then
// Backlight.level (0..1), .set(v), .step(+1 / -1), .refresh().
// sysfs can't be watched, so it is re-read every second; brightness keys call
// `qs ipc call osd brightness`, which refreshes at once and shows the OSD.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string device: ""
    readonly property bool available: device !== ""
    readonly property real level: maxFile.text() > 0 ? curFile.text() / maxFile.text() : 0
    property real pending: -1          // value being dragged to, until sysfs catches up
    readonly property real shown: pending >= 0 ? pending : level

    function refresh() {
        curFile.reload();
    }
    function step(dir) {
        Quickshell.execDetached(["brightnessctl", "-e4", "-n2", "set", "5%" + (dir > 0 ? "+" : "-")]);
        settle.restart();
    }
    // Dragging fires many values; send at most one brightnessctl call per 60 ms
    function set(v) {
        pending = Math.max(0.01, Math.min(1, v));
        apply.restart();
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }
    FileView {
        id: curFile
        path: root.device ? "/sys/class/backlight/" + root.device + "/brightness" : ""
    }
    FileView {
        id: maxFile
        path: root.device ? "/sys/class/backlight/" + root.device + "/max_brightness" : ""
    }
    Timer {
        running: root.available
        repeat: true
        interval: 1000
        onTriggered: curFile.reload()
    }
    Timer {
        id: apply
        interval: 60
        onTriggered: {
            Quickshell.execDetached(["brightnessctl", "-n2", "set", Math.round(root.pending * 100) + "%"]);
            settle.restart();
        }
    }
    Timer {
        id: settle
        interval: 150
        onTriggered: {
            curFile.reload();
            if (!apply.running)
                root.pending = -1;
        }
    }
}
