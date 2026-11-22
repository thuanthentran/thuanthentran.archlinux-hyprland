// One notification: icon / image, app and age, summary, body, action buttons, close (x).
// Used by the popups and by the list in the clock panel.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs.config
import qs.services

Rectangle {
    id: root

    required property var notification
    property bool compact: false           // in the list: body clamped harder
    readonly property bool hovered: hover.hovered
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    signal closeClicked

    width: parent ? parent.width : 340
    implicitHeight: content.implicitHeight + 20
    radius: 12
    color: Theme.popupBg
    border.color: critical ? Theme.red : Theme.popupBorder

    HoverHandler {
        id: hover
    }
    MouseArea {
        anchors.fill: parent
        onClicked: Notifs.activate(root.notification)
    }

    Row {
        id: content
        x: 12
        y: 10
        width: parent.width - 24
        spacing: 10

        IconImage {
            implicitSize: 36
            source: Notifs.icon(root.notification)
        }

        Column {
            width: parent.width - 36 - 10
            spacing: 2

            Item {
                width: parent.width
                height: 16

                Text {
                    width: parent.width - 40
                    elide: Text.ElideRight
                    text: root.notification.appName
                    color: Theme.fgDim
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Text {
                    visible: !root.hovered
                    anchors.right: parent.right
                    text: Notifs.age(root.notification)
                    color: Theme.fgOff
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                // Close
                Rectangle {
                    visible: root.hovered
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 10
                    color: closeArea.containsMouse ? Theme.hover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "\u{F0156}"
                        color: Theme.fg
                        font.family: Theme.iconFont
                        font.pixelSize: 13
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.closeClicked()
                    }
                }
            }
            Text {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.notification.summary
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }
            Text {
                visible: text !== ""
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: root.compact ? 2 : 4
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: root.notification.body
                color: Theme.fg
                opacity: 0.85
                font.family: Theme.font
                font.pixelSize: 12
            }
            // Action buttons (the "default" action is the click on the card)
            Flow {
                readonly property var actions: root.notification.actions.filter(a => a.identifier !== "default" && a.text)
                visible: actions.length > 0
                width: parent.width
                spacing: 6
                topPadding: 4

                Repeater {
                    model: parent.actions

                    Rectangle {
                        required property var modelData
                        width: label.implicitWidth + 20
                        height: 26
                        radius: 6
                        color: actArea.containsMouse ? Theme.active : Theme.hover

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                modelData.invoke();
                                if (!root.notification.resident)
                                    root.notification.dismiss();
                            }
                        }
                    }
                }
            }
        }
    }
}
