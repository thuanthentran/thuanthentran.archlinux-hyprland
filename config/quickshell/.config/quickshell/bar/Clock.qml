import QtQuick
import Quickshell
import qs.widgets

BarButton {
    iconText: false
    text: Qt.formatDateTime(clock.date, "ddd dd/MM   HH:mm")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
