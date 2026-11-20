// A bar item: optional text/icon plus any extra children, a hover pill, a tooltip,
// and clicked / wheel signals for any mouse button.
import QtQuick
import Quickshell
import qs

Rectangle {
    id: root

    property string text: ""
    property bool iconText: true          // draw `text` with the Nerd Font icon size
    property string tooltip: ""
    property color textColor: Theme.fg
    property color hoverColor: Theme.hover
    property bool highlighted: false
    property int padding: 8
    readonly property bool hovered: mouse.containsMouse
    default property alias content: row.data

    signal clicked(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight - 6
    radius: 6
    color: highlighted ? Theme.active : hovered ? hoverColor : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 5

        Text {
            visible: root.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.textColor
            font.family: root.iconText ? Theme.iconFont : Theme.font
            font.pixelSize: root.iconText ? Theme.iconSize : Theme.fontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onWheel: w => root.wheel(w)
    }

    Tooltip {
        target: root
        text: root.tooltip
        show: root.hovered && root.tooltip !== ""
    }
}
