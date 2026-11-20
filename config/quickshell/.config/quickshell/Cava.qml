// Audio spectrum from cava (12 bars, 0..1), running only while something plays.
// `import qs`, then Cava.values.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bars: 12
    property var values: Array(bars).fill(0)
    readonly property bool running: Players.active?.isPlaying ?? false

    onRunningChanged: if (!running) values = Array(bars).fill(0)

    Process {
        running: root.running
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 100);
                if (v.length === root.bars)
                    root.values = v;
            }
        }
    }
}
