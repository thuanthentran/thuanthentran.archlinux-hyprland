// Speaker icon whose waves follow the volume. Scroll to change it, middle click mutes.
// Collapsed: click opens the quick settings. Expanded: a slider + %, click opens the mixer.
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

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    text: muted ? "\u{F075F}"
        : volume < 0.01 ? "\u{F0581}"
        : volume < 0.34 ? "\u{F057F}"
        : volume < 0.67 ? "\u{F0580}"
        : "\u{F057E}"
    textColor: muted ? Theme.fgOff : Theme.fg
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    tooltip: BarState.expanded ? "" : muted ? "Muted" : Math.round(volume * 100) + "%"

    // Needed for sink.audio to be populated
    PwObjectTracker {
        objects: [root.sink]
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: BarState.expanded

        BarSlider {
            anchors.verticalCenter: parent.verticalCenter
            value: root.volume
            opacity: root.muted ? 0.5 : 1
            onMoved: v => root.setVolume(v)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
            color: root.textColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    onClicked: m => {
        if (m.button === Qt.MiddleButton && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
        else if (!BarState.expanded)
            BarState.expanded = true;
        else
            Quickshell.execDetached(["pavucontrol"]);
    }
    onWheel: w => setVolume(volume + w.angleDelta.y / 120 * 0.05)
}
