// Audio spectrum from cava (12 bars, 0..1), running only while something plays.
// `import qs`, then Cava.values. If cava exits while music plays (e.g. `pkill cava`
// after editing cava.conf) it is started again a second later.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int bars: 12
    property var values: Array(bars).fill(0)
    readonly property bool wanted: Players.active?.isPlaying ?? false

    onWantedChanged: {
        proc.running = wanted;
        if (!wanted)
            values = Array(bars).fill(0);
    }
    Component.onCompleted: proc.running = wanted

    Process {
        id: proc
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 100);
                if (v.length === root.bars)
                    root.values = v;
            }
        }
        onExited: if (root.wanted) restart.start()
    }
    Timer {
        id: restart
        interval: 1000
        onTriggered: if (root.wanted) proc.running = true
    }
}
