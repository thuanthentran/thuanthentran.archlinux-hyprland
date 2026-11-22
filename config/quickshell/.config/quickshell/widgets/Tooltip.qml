// Tooltip shown below `target` after a short hover.
import QtQuick
import Quickshell
import qs.config
import qs.services

PopupWindow {
    id: root

    required property Item target
    property string text: ""
    property bool show: false

    // Anchor to a zero-height line 6 px below the target, so the popup never covers it
    // (covering it would end the hover and make the tooltip flicker)
    anchor.item: target
    anchor.rect.x: 0
    anchor.rect.y: target.height + 6
    anchor.rect.width: target.width
    anchor.rect.height: 0
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    visible: false
    color: "transparent"
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12

    onShowChanged: if (!show) visible = false

    Timer {
        running: root.show
        interval: 500
        onTriggered: root.visible = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.popupBg
        border.color: Theme.popupBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
