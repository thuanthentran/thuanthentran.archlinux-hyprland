// Power button with a menu: lock, sleep, log out, restart, shut down. Restart and shut
// down ask for a second click so a slip doesn't turn the machine off.
import QtQuick
import Quickshell
import qs
import qs.widgets

BarButton {
    id: root

    property string armed: ""      // action waiting for its confirming click

    text: "\u{23FB}"
    highlighted: menu.visible
    onClicked: menu.visible = !menu.visible

    function run(action) {
        if ((action.confirm ?? "") !== "" && armed !== action.id) {
            armed = action.id;
            disarm.restart();
            return;
        }
        armed = "";
        menu.visible = false;
        Quickshell.execDetached(["sh", "-c", action.cmd]);
    }

    readonly property var actions: [
        { id: "lock", icon: "\u{F033E}", label: "Lock", cmd: "loginctl lock-session" },
        { id: "sleep", icon: "\u{F04B2}", label: "Sleep", cmd: "systemctl suspend" },
        { id: "logout", icon: "\u{F0343}", label: "Log out", cmd: "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'" },
        { id: "reboot", icon: "\u{F0709}", label: "Restart", confirm: "Click again to restart", cmd: "systemctl reboot" },
        { id: "poweroff", icon: "\u{F0425}", label: "Shut down", confirm: "Click again to shut down", cmd: "systemctl poweroff" }
    ]

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.armed = ""
    }

    PopupWindow {
        id: menu

        visible: false
        grabFocus: true          // the compositor closes the menu on a click outside it
        onVisibleChanged: if (!visible) root.armed = ""
        anchor.item: root
        anchor.rect.x: 0
        anchor.rect.y: root.height + 6
        anchor.rect.width: root.width
        anchor.rect.height: 0
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left
        color: "transparent"
        implicitWidth: 220
        implicitHeight: list.implicitHeight + 12


        Rectangle {
            anchors.fill: parent
            radius: 10
            color: Theme.popupBg
            border.color: Theme.popupBorder

            Column {
                id: list
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        required property var modelData
                        readonly property bool isArmed: root.armed === modelData.id

                        width: list.width
                        height: 32
                        radius: 6
                        color: isArmed ? Theme.redHover : area.containsMouse ? Theme.hover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 18
                                text: modelData.icon
                                color: Theme.fg
                                font.family: Theme.iconFont
                                font.pixelSize: Theme.iconSize
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: isArmed ? modelData.confirm : modelData.label
                                color: Theme.fg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                            }
                        }

                        MouseArea {
                            id: area
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.run(modelData)
                        }
                    }
                }
            }
        }
    }
}
