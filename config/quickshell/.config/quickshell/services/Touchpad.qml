// Touchpad swipe gestures, followed while the fingers move (Hyprland only reports a
// gesture once it is over). Runs `libinput debug-events` on the touchpad and turns its
// GESTURE_SWIPE_* lines into signals; `import qs`, then Connections on Touchpad.
//
// Needs read access to the touchpad's /dev/input/event*: the udev rule
// system/etc/udev/rules.d/70-touchpad-uaccess.rules gives it to the user at the seat.
// dx / dy are in millimetres on the pad (from libinput's unaccelerated deltas, see `mm`;
// dy < 0 is up). The accelerated ones are tiny on a touchpad and speed-dependent.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal begin(int fingers)
    signal update(int fingers, real dx, real dy)
    signal end(int fingers, bool cancelled)

    property bool running: proc.running
    // libinput units -> mm on the pad. Measured: with 0.0254 / 0.2968 (1000 dpi and
    // libinput's touchpad slowdown) a full-height swipe read about half the pad's 73 mm.
    readonly property real mm: 0.17

    Process {
        id: proc
        running: true
        // find the touchpad, then line-buffer libinput's output (it is a pipe here)
        command: ["sh", "-c", `
            for d in /dev/input/event*; do
                udevadm info -q property -n "$d" 2>/dev/null | grep -qx 'ID_INPUT_TOUCHPAD=1' && dev=$d && break
            done
            [ -n "$dev" ] || { echo "touchpad: none found" >&2; exit 1; }
            [ -r "$dev" ] || { echo "touchpad: no access to $dev (udev rule not installed?)" >&2; exit 1; }
            exec stdbuf -oL libinput debug-events --device "$dev"`]

        stdout: SplitParser {
            onRead: line => {
                // " event9  GESTURE_SWIPE_UPDATE   12  +0.230s\t3  0.11/-1.10 ( 0.11/-1.10 unaccelerated)"
                // (the count after UPDATE is left out on the first update)
                const m = /GESTURE_SWIPE_(BEGIN|UPDATE|END)\s+(?:\d+\s+)?\+[\d.]+s\s+(\d+)(.*)$/.exec(line);
                if (!m)
                    return;
                const fingers = Number(m[2]);
                if (m[1] === "BEGIN") {
                    root.begin(fingers);
                } else if (m[1] === "END") {
                    root.end(fingers, /cancelled/.test(m[3]));
                } else {
                    const d = /\(\s*(-?[\d.]+)\/\s*(-?[\d.]+) unaccelerated/.exec(m[3]);
                    if (d)
                        root.update(fingers, Number(d[1]) * root.mm, Number(d[2]) * root.mm);
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn(line)
        }
        onExited: retry.restart()
    }

    // Started again if it stops (no access yet, touchpad re-plugged after resume...)
    Timer {
        id: retry
        interval: 5000
        onTriggered: proc.running = true
    }
}
