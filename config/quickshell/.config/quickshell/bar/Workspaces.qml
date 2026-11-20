// Regular workspaces (special ones like the minimized-window stash have id < 0).
import QtQuick
import Quickshell.Hyprland
import qs
import qs.widgets

Row {
    spacing: 2

    Repeater {
        model: Hyprland.workspaces

        BarButton {
            required property HyprlandWorkspace modelData

            visible: modelData.id > 0
            padding: 7
            iconText: false
            text: modelData.name
            highlighted: modelData.active
            textColor: modelData.active || hovered ? "white" : Theme.fgDim
            onClicked: modelData.activate()
        }
    }
}
