// Screen brightness: icon (scroll to change, % in the tooltip); expanded adds a slider.
import QtQuick
import Quickshell
import qs
import qs.widgets

BarButton {
    id: root

    visible: Backlight.available
    pill: BarState.expanded      // collapsed, the whole cluster is one button
    text: "\u{F00E0}"
    tooltip: BarState.expanded ? "" : Math.round(Backlight.level * 100) + "%"

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: BarState.expanded

        BarSlider {
            anchors.verticalCenter: parent.verticalCenter
            value: Backlight.shown
            onMoved: v => Backlight.set(v)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            text: Math.round(Backlight.shown * 100) + "%"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    onClicked: if (!BarState.expanded) BarState.expanded = true
    onWheel: w => Backlight.step(w.angleDelta.y)
}
