// New notifications, top right under the bar, newest on top. Each hides after its
// timeout (5 s default; critical ones stay; hovering holds it), timed in Notifs; it stays
// in the clock panel's list. Only the cards take input.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: root

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    anchors {
        top: true
        right: true
    }
    margins {
        top: 8
        right: 8
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"
    color: "transparent"
    implicitWidth: 360
    implicitHeight: Math.max(1, column.implicitHeight)
    visible: Notifs.popups.length > 0
    mask: Region { item: column }

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: Notifs.popups

            NotificationCard {
                id: card

                required property var modelData
                notification: modelData
                onCloseClicked: modelData.dismiss()

                // Slide in from the right, only when it just arrived (cards are rebuilt
                // whenever the list changes)
                property real slide: Date.now() - (Notifs.times[modelData.id] ?? 0) < 500 ? 40 : 0
                transform: Translate { x: card.slide }
                opacity: 1 - card.slide / 40
                Component.onCompleted: slide = 0
                Behavior on slide { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                onHoveredChanged: {
                    if (hovered)
                        Notifs.hovering = modelData.id;
                    else if (Notifs.hovering === modelData.id)
                        Notifs.hovering = -1;
                }
            }
        }
    }
}
