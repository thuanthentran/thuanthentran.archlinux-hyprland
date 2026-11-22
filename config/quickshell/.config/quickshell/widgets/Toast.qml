// Small message in the top-right corner, below the top bar; hides itself after 2 s.
import QtQuick
import qs.config
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    property string text: ""

    function show(message) {
        text = message;
        visible = true;
        hideTimer.restart();
    }

    visible: false
    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 12
    }
    // Stay clear of the bar's exclusive zone without reserving space of our own
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-toast"
    color: "transparent"
    implicitWidth: label.implicitWidth + 32
    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#e6202020"
        border.color: "#33ffffff"

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: "white"
            font.family: Theme.font
            font.pixelSize: 14
        }
    }

    Timer {
        id: hideTimer
        interval: 2000
        onTriggered: root.visible = false
    }
}
