// Clock; click for the calendar and notifications. A dot marks notifications that came in
// since the panel was last opened; a bell-off icon shows Do Not Disturb.
import QtQuick
import Quickshell
import qs
import qs.widgets

BarButton {
    id: root

    iconText: false
    text: Qt.formatDateTime(clock.date, "ddd dd/MM   HH:mm")
    highlighted: panel.visible

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        visible: Notifs.dnd
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F009B}"
        color: Theme.fgDim
        font.family: Theme.iconFont
        font.pixelSize: 13
    }
    Rectangle {
        visible: Notifs.unread && !Notifs.dnd && Notifs.list.length > 0
        anchors.verticalCenter: parent.verticalCenter
        width: 6
        height: 6
        radius: 3
        color: Theme.cpu
    }

    ClockPanel {
        id: panel
        anchorItem: root
    }

    onClicked: panel.toggle()

    Connections {
        target: BarState
        function onPopupRequested(name) {
            if (name === "clock")
                panel.openWithoutGrab();
        }
    }
}
