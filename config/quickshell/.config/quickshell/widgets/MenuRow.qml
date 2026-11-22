// A row in a drop-down list: icon, text, optional detail on the right, hover highlight.
import QtQuick
import qs.config
import qs.services

Rectangle {
    id: root

    property string icon: ""
    property real wifiLevel: -1            // >= 0: draw a WifiIcon at this level instead of `icon`
    property string text: ""
    property string detail: ""
    property bool active: false            // e.g. the connected network: bold + accent icon
    property bool dim: false
    default property alias extra: below.data   // shown under the row (a password field)
    signal clicked(var mouse)

    width: parent ? parent.width : 0
    implicitHeight: 32 + below.implicitHeight
    radius: 6
    color: area.containsMouse ? Theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }

    MouseArea {
        id: area
        width: parent.width
        height: 32
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => root.clicked(m)
    }

    WifiIcon {
        visible: root.wifiLevel >= 0
        x: 9
        y: (32 - height) / 2
        level: root.wifiLevel
        color: root.active ? Theme.accent : Theme.fg
    }
    Text {
        id: iconText
        x: 8
        width: 20
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: root.icon
        color: root.active ? Theme.accent : root.dim ? Theme.fgOff : Theme.fg
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
    }
    Text {
        anchors.left: iconText.right
        anchors.leftMargin: 6
        anchors.right: detailText.left
        anchors.rightMargin: 8
        height: 32
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: root.text
        color: root.dim ? Theme.fgOff : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.weight: root.active ? Font.DemiBold : Font.Normal
    }
    Text {
        id: detailText
        anchors.right: parent.right
        anchors.rightMargin: 8
        height: 32
        verticalAlignment: Text.AlignVCenter
        text: root.detail
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: 12
    }
    Column {
        id: below
        y: 32
        x: 8
        width: parent.width - 16
    }
}
