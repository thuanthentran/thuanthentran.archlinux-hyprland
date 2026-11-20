// Wi-Fi signal bars, a cable when wired, crossed out when offline.
// Expanded: network name and signal %. Click (expanded) opens the connection editor.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs
import qs.widgets

BarButton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property real strength: wifiNet?.signalStrength ?? 0
    readonly property string label: wired ? "Wired" : wifiNet ? wifiNet.name + "  " + Math.round(strength * 100) + "%" : "Offline"

    text: wired ? "\u{F0200}"
        : !wifiNet ? "\u{F092E}"
        : strength < 0.2 ? "\u{F092F}"
        : strength < 0.4 ? "\u{F091F}"
        : strength < 0.6 ? "\u{F0922}"
        : strength < 0.8 ? "\u{F0925}"
        : "\u{F0928}"
    textColor: wired || wifiNet ? Theme.fg : Theme.fgOff
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    tooltip: BarState.expanded ? "" : label

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

    onClicked: {
        if (!BarState.expanded)
            BarState.expanded = true;
        else
            Quickshell.execDetached(["nm-connection-editor"]);
    }
}
