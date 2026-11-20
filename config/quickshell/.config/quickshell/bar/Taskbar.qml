// One icon per window. Click focuses it; a minimized window (in special:magic) is
// restored instead, middle click closes.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.widgets

Row {
    spacing: 2

    Repeater {
        model: Hyprland.toplevels

        BarButton {
            id: btn

            required property HyprlandToplevel modelData
            readonly property string appId: modelData.wayland?.appId ?? ""
            readonly property bool minimized: modelData.workspace?.name === "special:magic"

            padding: 5
            tooltip: modelData.title
            highlighted: modelData.activated
            opacity: minimized ? 0.5 : 1

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(btn.appId)?.icon ?? btn.appId, "application-x-executable")
            }

            onClicked: m => {
                if (m.button === Qt.MiddleButton)
                    modelData.wayland?.close();
                else if (minimized)
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize.sh", "restore", modelData.address]);
                else
                    modelData.wayland?.activate();
            }
        }
    }
}
