// Collapsed: shown only while Bluetooth is on (another icon once a device is connected).
// Expanded: always shown with its state; click opens the device list (with the on / off
// switch), right click opens Blueman.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

BarButton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
    readonly property string label: !enabled ? "Off" : connected.length > 0 ? connected.map(d => d.name).join(", ") : "On"

    visible: adapter !== null && (enabled || BarState.expanded)
    text: !enabled ? "\u{F00B2}" : connected.length > 0 ? "\u{F00B1}" : "\u{F00AF}"
    textColor: enabled ? Theme.fg : Theme.fgOff
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    highlighted: menu.visible
    tooltip: BarState.expanded ? "" : label

    BluetoothMenu {
        id: menu
        anchorItem: root
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: BarState.expanded

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.textColor
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    onClicked: m => {
        if (m.button === Qt.RightButton)
            Quickshell.execDetached(["blueman-manager"]);
        else if (!BarState.expanded)
            BarState.expanded = true;
        else
            menu.toggle();
    }

    Connections {
        target: BarState
        function onPopupRequested(name) {
            if (name === "bluetooth") {
                BarState.expanded = true;
                menu.openWithoutGrab();
            }
        }
    }
}
