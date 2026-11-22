// Horizontal slider for the bar (volume, brightness). Click or drag to set; `moved`
// reports the new value in 0..1. While dragged it holds the quick settings open.
// `peak` (>= 0, linear audio peak from PwNodePeakMonitor) draws a level meter over the
// filled part, Windows 11 style: it rises with the sound, up to the current value.
import QtQuick
import qs.config
import qs.services

Item {
    id: root

    property real value: 0
    property real peak: -1
    // Linear peak: mastered music sits around 0.8, so a dB scale would pin the meter to
    // the end; linear leaves a visible tail of the fill and drops clearly in quiet parts
    readonly property real meter: Math.max(0, Math.min(1, peak))
    readonly property bool pressed: area.pressed

    signal moved(real value)

    implicitWidth: 110
    implicitHeight: 18

    onPressedChanged: BarState.held += pressed ? 1 : -1
    Component.onDestruction: if (pressed) BarState.held -= 1

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.rgba(1, 1, 1, 0.2)

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.value))
            height: parent.height
            radius: 2
            color: Theme.fg
        }
        // Level meter: fast up, slower down
        Rectangle {
            visible: root.peak >= 0
            width: track.width * Math.max(0, Math.min(1, root.value)) * root.meter
            height: parent.height
            radius: 2
            color: Theme.cpu
            Behavior on width {
                NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
            }
        }
    }
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * Math.max(0, Math.min(1, root.value)) - width / 2
        width: area.pressed || area.containsMouse ? 12 : 10
        height: width
        radius: width / 2
        color: "white"
        Behavior on width { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true

        function set(x) {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: m => set(m.x)
        onPositionChanged: m => { if (pressed) set(m.x); }
    }
}
