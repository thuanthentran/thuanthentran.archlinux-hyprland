// A bar item: optional text/icon plus any extra children, a hover pill, a tooltip,
// and clicked / pressed / wheel signals for any mouse button.
import QtQuick
import Quickshell
import qs.config
import qs.services

Rectangle {
    id: root

    property string text: ""
    property bool iconText: true          // draw `text` with the Nerd Font icon size
    property string tooltip: ""
    property color textColor: Theme.fg
    property color hoverColor: Theme.hover
    property bool highlighted: false
    property bool pill: true              // own hover pill; off when a parent highlights instead
    property int padding: 8
    readonly property bool hovered: hover.hovered
    default property alias content: row.data

    signal clicked(var mouse)
    signal pressed(var mouse)
    signal wheel(var wheel)

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight - 6
    radius: 6
    color: highlighted ? Theme.active : hovered && pill ? hoverColor : "transparent"
    Behavior on color { ColorAnimation { duration: 120 } }

    // Below the content, so interactive children (sliders) take their own clicks
    MouseArea {
        id: mouse
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: m => root.clicked(m)
        onPressed: m => root.pressed(m)
        onWheel: w => root.wheel(w)
    }
    HoverHandler {
        id: hover
    }

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

    Tooltip {
        target: root
        text: root.tooltip
        show: root.hovered && root.tooltip !== ""
    }
}
