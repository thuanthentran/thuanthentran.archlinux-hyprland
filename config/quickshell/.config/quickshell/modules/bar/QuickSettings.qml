// The quick settings cluster: volume, brightness, network, Bluetooth, power profile.
// (The tray sits outside it: its icons act on their own apps, not as part of one button.)
// Click it to expand it in place (details slide out, the clock fades); moving the mouse
// off it folds it back after a moment. The bar itself keeps its size.
import QtQuick
import qs.config
import qs.services

Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 8
    implicitHeight: Theme.barHeight - 4
    radius: 6
    // Collapsed it acts as one button, so it highlights as a whole; expanded, each part
    // highlights on its own over a faint background
    color: BarState.expanded ? Qt.rgba(1, 1, 1, 0.07) : hover.hovered ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 200 } }

    // Click on the cluster's background (between icons) also expands it
    MouseArea {
        anchors.fill: parent
        onClicked: BarState.expanded = true
    }
    // Fold back only after the mouse has been on the cluster and left it (opening it from
    // IPC with the mouse elsewhere keeps it open)
    property bool entered: false
    Connections {
        target: BarState
        function onExpandedChanged() { root.entered = hover.hovered; }
    }
    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) root.entered = true
    }
    Timer {
        interval: 400
        running: BarState.expanded && root.entered && !hover.hovered && BarState.held === 0
        onTriggered: BarState.expanded = false
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Volume {}
        Brightness {}
        Network {}
        Bluetooth {}
        PowerProfile {}
    }
}
