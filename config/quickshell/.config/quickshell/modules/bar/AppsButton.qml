import QtQuick
import Quickshell
import qs.config
import qs.services
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

    onClicked: BarState.launcherToggle()      // modules/launcher/Launcher.qml
}
