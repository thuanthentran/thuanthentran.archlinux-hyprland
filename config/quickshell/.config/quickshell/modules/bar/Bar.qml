// Top bar, one per screen. Reserves its height (exclusive zone), so
// tiling, maximize and keep_on_screen (which read the monitor's reserved area) follow it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

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
        NowPlaying {}

        Item { Layout.fillWidth: true }

        SystemStats {}
        QuickSettings {}
        Tray {}
        Battery {}
        PowerButton {}
    }

    // Centred on the screen, not between the left and right groups. Fades out while the
    // quick settings are expanded, which may need its space.
    Clock {
        anchors.centerIn: parent
        opacity: BarState.expanded ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
