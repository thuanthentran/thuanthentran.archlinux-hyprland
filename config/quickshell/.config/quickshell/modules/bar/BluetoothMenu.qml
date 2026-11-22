// Drop-down Bluetooth list: on / off switch, then devices (connected, paired, nearby).
// Click connects / disconnects, or pairs a new device (and connects once paired);
// right click a paired device to forget it. Scans while open.
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.config
import qs.services
import qs.widgets

DropPopup {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    // Skip nearby devices without a usable name (shown as their address, or as U+FFFD)
    readonly property var devices: Bluetooth.devices.values
        .filter(d => d.paired || (d.name && d.name.replace(/-/g, ":") !== d.address && !d.name.includes("\uFFFD")))
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))
        .slice(0, 12)

    function glyph(icon) {
        return /headset|headphone|audio/.test(icon) ? "\u{F02CB}"
            : /mouse/.test(icon) ? "\u{F037D}"
            : /keyboard/.test(icon) ? "\u{F030C}"
            : /phone/.test(icon) ? "\u{F011C}"
            : /computer/.test(icon) ? "\u{F0322}"
            : "\u{F00AF}";
    }

    title: "Bluetooth"
    hasSwitch: true
    switchOn: on
    onSwitchToggled: if (adapter) adapter.enabled = !adapter.enabled
    onVisibleChanged: if (adapter && on) adapter.discovering = visible
    onOnChanged: if (adapter && on && visible) adapter.discovering = true

    Text {
        visible: !root.on || root.devices.length === 0
        leftPadding: 8
        text: !root.adapter ? "No Bluetooth adapter" : !root.on ? "Bluetooth is off" : "Searching…"
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: root.on ? root.devices : []

        MenuRow {
            id: row

            required property var modelData

            icon: root.glyph(modelData.icon)
            text: modelData.name
            active: modelData.connected
            dim: !modelData.paired && !modelData.connected
            detail: modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                : modelData.pairing ? "Pairing…"
                : modelData.connected ? (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "Connected")
                : modelData.paired ? "Paired" : ""

            onClicked: m => {
                if (m.button === Qt.RightButton) {
                    if (modelData.paired)
                        modelData.forget();
                } else if (modelData.connected) {
                    modelData.disconnect();
                } else if (modelData.paired) {
                    modelData.connect();
                } else {
                    modelData.trusted = true;
                    modelData.pair();
                }
            }

            Connections {
                target: row.modelData
                function onPairedChanged() {
                    if (row.modelData.paired)
                        row.modelData.connect();
                }
            }
        }
    }

    MenuRow {
        icon: "\u{F0493}"
        text: "Bluetooth settings…"
        dim: true
        onClicked: {
            root.visible = false;
            Quickshell.execDetached(["blueman-manager"]);
        }
    }
}
