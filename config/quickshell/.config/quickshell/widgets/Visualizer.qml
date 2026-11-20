// Bars from Cava.values, growing from the middle (or the bottom).
import QtQuick
import qs

Row {
    id: root

    property int barWidth: 2
    property int maxHeight: 14
    property bool centered: true
    property color color: Theme.fg

    spacing: barWidth > 2 ? 2 : 1
    height: maxHeight

    Repeater {
        model: Cava.bars

        Rectangle {
            required property int index
            anchors.verticalCenter: root.centered ? parent.verticalCenter : undefined
            anchors.bottom: root.centered ? undefined : parent.bottom
            width: root.barWidth
            height: Math.max(2, (Cava.values[index] ?? 0) * root.maxHeight)
            radius: width / 2
            color: root.color
            Behavior on height { NumberAnimation { duration: 60 } }
        }
    }
}
