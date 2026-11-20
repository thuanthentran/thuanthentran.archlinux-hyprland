import QtQuick
import Quickshell.Services.UPower
import qs
import qs.widgets

BarButton {
    readonly property var dev: UPower.displayDevice
    readonly property int percent: Math.round(dev.percentage * 100)
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
        || dev.state === UPowerDeviceState.FullyCharged || dev.state === UPowerDeviceState.PendingCharge

    function hm(s) {
        return Math.floor(s / 3600) + "h " + Math.floor(s % 3600 / 60) + "m";
    }

    visible: dev.isLaptopBattery
    iconText: false
    text: percent + "%  " + (charging ? "\u{F0084}" : ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"][Math.min(9, Math.floor(percent / 10))])
    textColor: charging ? Theme.fg : percent <= 15 ? Theme.red : percent <= 30 ? Theme.yellow : Theme.fg
    tooltip: dev.timeToEmpty > 0 ? hm(dev.timeToEmpty) + " left"
        : dev.timeToFull > 0 ? hm(dev.timeToFull) + " to full"
        : UPowerDeviceState.toString(dev.state)
}
