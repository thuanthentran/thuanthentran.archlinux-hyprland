// On-screen display for volume, mic mute and brightness: a pill near the bottom of the
// focused screen, shown for 1.5 s. Volume / mute changes are picked up from PipeWire
// (keys, apps, anything) except while the quick settings are open, since the bar shows
// them there; brightness keys call `qs ipc call osd brightness`. Takes no input.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import qs
import qs.widgets

PanelWindow {
    id: root

    property string kind: "volume"       // volume, mic, brightness
    property bool ready: false           // ignore the values PipeWire reports at startup
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property real value: kind === "brightness" ? Backlight.shown
        : kind === "mic" ? (source?.audio?.volume ?? 0)
        : (sink?.audio?.volume ?? 0)
    readonly property bool muted: kind === "mic" ? (source?.audio?.muted ?? false)
        : kind === "volume" ? (sink?.audio?.muted ?? false) : false
    readonly property string icon: kind === "brightness" ? "\u{F00E0}"
        : kind === "mic" ? (muted ? "\u{F036D}" : "\u{F036C}")
        : muted ? "\u{F075F}" : value < 0.01 ? "\u{F0581}" : value < 0.34 ? "\u{F057F}" : value < 0.67 ? "\u{F0580}" : "\u{F057E}"

    function show(k) {
        if (!ready)
            return;
        kind = k;
        shown = true;
        hide.restart();
    }
    property bool shown: false

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors.bottom: true
    margins.bottom: 90
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"
    mask: Region {}                      // clicks go through
    color: "transparent"
    implicitWidth: 300
    implicitHeight: 52
    visible: shown || pill.opacity > 0

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
    Timer {
        running: true
        interval: 2000
        onTriggered: root.ready = true
    }
    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { if (!BarState.expanded) root.show("volume"); }
        function onMutedChanged() { if (!BarState.expanded) root.show("volume"); }
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.show("mic"); }
    }

    Rectangle {
        id: pill

        anchors.fill: parent
        radius: height / 2
        color: Theme.popupBg
        border.color: Theme.popupBorder
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        Row {
            anchors.centerIn: parent
            spacing: 14

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                text: root.icon
                color: root.muted ? Theme.fgOff : Theme.fg
                font.family: Theme.iconFont
                font.pixelSize: 20
            }
            // Level bar (display only)
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                height: 6
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.18)

                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.value))
                    height: parent.height
                    radius: 3
                    color: root.muted ? Theme.fgOff : Theme.fg
                    Behavior on width { NumberAnimation { duration: 100 } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: root.muted ? "Off" : Math.round(root.value * 100) + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.features: { "tnum": 1 }
            }
        }
    }
}
