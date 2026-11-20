// On / off switch; `toggled` asks the owner to flip `checked`.
import QtQuick
import qs

Rectangle {
    id: root

    property bool checked: false
    signal toggled

    implicitWidth: 36
    implicitHeight: 20
    radius: height / 2
    color: checked ? Theme.cpu : Qt.rgba(1, 1, 1, 0.18)
    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        width: root.height - 4
        height: width
        radius: width / 2
        color: "white"
        Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: root.toggled()
    }
}
