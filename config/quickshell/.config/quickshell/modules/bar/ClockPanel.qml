// Drop-down under the clock: today's date, a month calendar, and the notification list
// (newest first) with Clear all and a Do Not Disturb switch.
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

DropPopup {
    id: root

    contentWidth: 360

    onVisibleChanged: {
        if (visible) {
            calendar.reset();
            Notifs.unread = false;
        }
    }

    Text {
        leftPadding: 6
        text: Qt.formatDate(new Date(), "dddd, d MMMM")
        color: Theme.fg
        font.family: Theme.displayFont
        font.pixelSize: 15
        font.weight: Font.DemiBold
    }

    Calendar {
        id: calendar
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.popupBorder
    }

    // Notifications header: title, Clear all, Do Not Disturb
    Item {
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            text: "Notifications"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                visible: Notifs.list.length > 0
                anchors.verticalCenter: parent.verticalCenter
                width: clearText.implicitWidth + 16
                height: 24
                radius: 6
                color: clearArea.containsMouse ? Theme.hover : "transparent"

                Text {
                    id: clearText
                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: 12
                }
                MouseArea {
                    id: clearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Notifs.clearAll()
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F009B}"           // bell-off
                color: Notifs.dnd ? Theme.fg : Theme.fgOff
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Notifs.dnd
                onToggled: Notifs.dnd = !Notifs.dnd
            }
        }
    }

    Text {
        visible: Notifs.list.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: 8
        bottomPadding: 8
        text: Notifs.dnd ? "No notifications · Do Not Disturb is on" : "No notifications"
        color: Theme.fgOff
        font.family: Theme.font
        font.pixelSize: 12
    }

    Flickable {
        visible: Notifs.list.length > 0
        width: parent.width
        height: Math.min(list.implicitHeight, 380)
        contentHeight: list.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: list
            width: parent.width
            spacing: 6

            Repeater {
                model: Notifs.list

                NotificationCard {
                    required property var modelData
                    notification: modelData
                    compact: true
                    color: Theme.card
                    onCloseClicked: modelData.dismiss()
                }
            }
        }
    }
}
