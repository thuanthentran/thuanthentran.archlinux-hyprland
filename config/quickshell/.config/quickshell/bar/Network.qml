// Wi-Fi signal bars, a cable when wired, crossed-out when offline. Name and % in the tooltip.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs
import qs.widgets

BarButton {
    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property real strength: wifiNet?.signalStrength ?? 0

    text: wired ? "\u{F0200}"
        : !wifiNet ? "\u{F092E}"
        : strength < 0.2 ? "\u{F092F}"
        : strength < 0.4 ? "\u{F091F}"
        : strength < 0.6 ? "\u{F0922}"
        : strength < 0.8 ? "\u{F0925}"
        : "\u{F0928}"
    textColor: wired || wifiNet ? Theme.fg : Theme.fgOff
    tooltip: wired ? "Wired" : wifiNet ? wifiNet.name + " (" + Math.round(strength * 100) + "%)" : "Offline"

    onClicked: Quickshell.execDetached(["nm-connection-editor"])
}
