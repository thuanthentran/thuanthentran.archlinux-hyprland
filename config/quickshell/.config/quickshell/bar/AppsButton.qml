import QtQuick
import Quickshell
import qs
import qs.widgets

BarButton {
    padding: 10
    text: "\u{F003B}"   // apps grid

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Apps"
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.weight: Font.Bold
    }

    onClicked: Quickshell.execDetached(["nwg-drawer"])
}
