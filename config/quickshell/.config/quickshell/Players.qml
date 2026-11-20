// The MPRIS player the bar shows: the one playing, else the last one that played,
// else the first. `import qs`, then Players.active / .length / .position.
//
// Firefox (YouTube) reports length and position only some of the time; in between it
// drops the length and says the position is 0. So the last real length is kept per
// track and the position is estimated from the last real one plus the time played since.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var all: Mpris.players.values
    property var last: null
    readonly property var active: all.find(p => p.isPlaying) ?? (all.includes(last) ? last : all[0] ?? null)

    readonly property string track: active ? active.trackTitle + "\n" + (active.metadata["xesam:url"] ?? "") : ""
    property real length: 0           // seconds, 0 = unknown
    property real basePos: 0          // last trusted position...
    property real baseTime: 0         // ...and when it was taken (ms)
    property real now: Date.now()
    readonly property real position: {
        const p = basePos + (active?.isPlaying ? (now - baseTime) / 1000 * (active.rate || 1) : 0);
        return length > 0 ? Math.min(p, length) : p;
    }

    onActiveChanged: if (active?.isPlaying) last = active
    onTrackChanged: {
        length = 0;
        sync();
    }

    function time(s) {
        s = Math.max(0, Math.floor(s));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        return (h > 0 ? h + ":" + String(m).padStart(2, "0") : m) + ":" + String(sec).padStart(2, "0");
    }

    // Take the player's numbers when they look real
    function sync() {
        now = Date.now();
        const p = active;
        if (!p)
            return;
        if (p.lengthSupported && p.length > 0) {
            length = p.length;
            if (p.positionSupported)
                setBase(p.position);
        } else if (length === 0) {
            setBase(p.positionSupported ? p.position : 0);
        }
    }
    function setBase(pos) {
        basePos = pos;
        baseTime = Date.now();
    }
    function seek(pos) {
        if (active?.canSeek) {
            active.position = pos;
            setBase(pos);
        }
    }

    // Freeze / resume the estimate on play-pause
    Connections {
        target: root.active
        function onIsPlayingChanged() {
            root.setBase(root.position);
            root.sync();
        }
    }

    // MPRIS doesn't push position updates; ask for a fresh value while playing
    Timer {
        running: root.active?.isPlaying ?? false
        repeat: true
        interval: 1000
        onTriggered: {
            root.active.positionChanged();
            root.sync();
        }
    }
}
