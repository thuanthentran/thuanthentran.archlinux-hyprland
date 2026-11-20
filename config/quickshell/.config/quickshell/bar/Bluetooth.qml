// Shown only while Bluetooth is on; a different icon when a device is connected.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.widgets

BarButton {
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    visible: Bluetooth.defaultAdapter?.enabled ?? false
    text: connected.length > 0 ? "\u{F00B1}" : "\u{F00AF}"
    tooltip: connected.length > 0 ? connected.map(d => d.name).join("\n") : "Bluetooth on"

    onClicked: Quickshell.execDetached(["blueman-manager"])
}
