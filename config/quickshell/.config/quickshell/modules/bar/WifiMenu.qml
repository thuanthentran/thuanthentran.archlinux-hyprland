// Drop-down Wi-Fi list: on / off switch, networks by signal. Click a network to connect
// (asks for the password when needed), click the connected one to disconnect,
// right click a saved one to forget it.
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.config
import qs.services
import qs.widgets

DropPopup {
    id: root

    required property var wifi            // WifiDevice or null
    property string asking: ""            // network waiting for its password
    property string error: ""
    readonly property var networks: !wifi ? [] : wifi.networks.values.filter(n => n.name !== "")
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)).slice(0, 10)

    title: "Wi-Fi"
    hasSwitch: true
    switchOn: Networking.wifiEnabled
    onSwitchToggled: Networking.wifiEnabled = !Networking.wifiEnabled
    onVisibleChanged: {
        if (wifi)
            wifi.scannerEnabled = visible;
        asking = "";
        error = "";
    }

    Text {
        visible: !Networking.wifiEnabled || root.networks.length === 0
        leftPadding: 8
        text: !Networking.wifiEnabled ? "Wi-Fi is off" : "Searching…"
        color: Theme.fgDim
        font.family: Theme.font
        font.pixelSize: 12
    }

    Repeater {
        model: Networking.wifiEnabled ? root.networks : []

        MenuRow {
            id: row

            required property var modelData
            // Unknown counts as open; if it does need a password, connecting fails with
            // NoSecrets and the password field opens
            readonly property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Unknown
            readonly property bool askingHere: root.asking === modelData.name

            wifiLevel: modelData.signalStrength
            text: modelData.name
            active: modelData.connected
            detail: modelData.stateChanging ? "Connecting…"
                : modelData.connected ? "Connected"
                : modelData.known ? "Saved"
                : secured ? "\u{F033E}" : ""

            onClicked: m => {
                root.error = "";
                if (m.button === Qt.RightButton) {
                    if (modelData.known)
                        modelData.forget();
                } else if (modelData.connected) {
                    modelData.disconnect();
                } else if (modelData.known || !secured) {
                    modelData.connect();
                } else {
                    root.asking = askingHere ? "" : modelData.name;
                }
            }

            Connections {
                target: row.modelData
                function onConnectionFailed(reason) {
                    root.error = row.modelData.name + ": " + ConnectionFailReason.toString(reason);
                    if (reason === ConnectionFailReason.NoSecrets)
                        root.asking = row.modelData.name;
                }
            }

            // Password field, under the row
            Rectangle {
                visible: row.askingHere
                width: parent.width
                height: visible ? 30 : 0
                radius: 6
                color: Theme.field
                border.color: pw.activeFocus ? Theme.accent : Theme.popupBorder

                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                    onAccepted: {
                        row.modelData.connectWithPsk(text);
                        root.asking = "";
                    }
                    Keys.onEscapePressed: root.asking = ""

                    Text {
                        visible: !pw.text
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password, then Enter"
                        color: Theme.fgOff
                        font: pw.font
                    }
                }
            }
        }
    }

    Text {
        visible: root.error !== ""
        width: parent.width
        leftPadding: 8
        wrapMode: Text.Wrap
        text: root.error
        color: Theme.red
        font.family: Theme.font
        font.pixelSize: 12
    }

    MenuRow {
        icon: "\u{F0493}"
        text: "Network settings…"
        dim: true
        onClicked: {
            root.visible = false;
            Quickshell.execDetached(["nm-connection-editor"]);
        }
    }
}
