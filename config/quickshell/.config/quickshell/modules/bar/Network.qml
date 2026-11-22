// Wi-Fi signal arcs, a cable when wired, crossed out when offline.
// Expanded: network name and signal %; click opens the Wi-Fi list.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

BarButton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNet: wifi?.networks.values.find(n => n.connected) ?? null
    readonly property real strength: wifiNet?.signalStrength ?? 0
    readonly property string label: wired ? "Wired" : wifiNet ? wifiNet.name + "  " + Math.round(strength * 100) + "%" : "Offline"

    // Wi-Fi uses the drawn WifiIcon below; glyphs only for wired / offline
    text: wired ? "\u{F0200}" : !wifiNet ? "\u{F092E}" : ""
    textColor: wired || wifiNet ? Theme.fg : Theme.fgOff
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    highlighted: menu.visible
    tooltip: BarState.expanded ? "" : label

    WifiMenu {
        id: menu
        anchorItem: root
        wifi: root.wifi
    }

    WifiIcon {
        visible: !root.wired && root.wifiNet !== null
        anchors.verticalCenter: parent.verticalCenter
        level: root.strength
        color: root.textColor
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

    onClicked: {
        if (!BarState.expanded)
            BarState.expanded = true;
        else
            menu.toggle();
    }

    Connections {
        target: BarState
        function onPopupRequested(name) {
            if (name === "wifi") {
                BarState.expanded = true;
                menu.openWithoutGrab();
            }
        }
    }
}
