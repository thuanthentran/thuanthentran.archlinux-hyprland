// Horizontal slider for the bar (volume, brightness). Click or drag to set; `moved`
// reports the new value in 0..1. While dragged it holds the quick settings open.
import QtQuick
import qs

Item {
    id: root

    property real value: 0
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
