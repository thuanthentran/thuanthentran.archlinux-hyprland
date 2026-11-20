// Top bar, one per screen. Replaces Waybar; reserves its height like Waybar did, so
// tiling, maximize and keep_on_screen (which read the monitor's reserved area) follow it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 6

        AppsButton {}
        Workspaces {}
        Taskbar {}

        Item { Layout.fillWidth: true }

        WindowControls {}
        Volume {}
        Network {}
        Bluetooth {}
        Brightness {}
        Battery {}
        Tray {}
        PowerButton {}
    }

    // Centred on the screen, not between the left and right groups
    Clock {
        anchors.centerIn: parent
    }
}
