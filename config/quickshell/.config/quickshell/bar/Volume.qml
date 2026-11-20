// Speaker icon whose waves follow the volume; scroll to change it, click for the mixer.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.widgets

BarButton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true

    text: muted ? "\u{F075F}"
        : volume < 0.01 ? "\u{F0581}"
        : volume < 0.34 ? "\u{F057F}"
        : volume < 0.67 ? "\u{F0580}"
        : "\u{F057E}"
    textColor: muted ? Theme.fgOff : Theme.fg
    tooltip: muted ? "Muted" : Math.round(volume * 100) + "%"

    // Needed for sink.audio to be populated
    PwObjectTracker {
        objects: [root.sink]
    }

    onClicked: m => {
        if (m.button === Qt.MiddleButton && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
        else
            Quickshell.execDetached(["pavucontrol"]);
    }
    onWheel: w => {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, volume + w.angleDelta.y / 120 * 0.05));
    }
}
