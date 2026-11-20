// Month grid, Monday first. Arrows (or scrolling) change the month; clicking the month
// name jumps back to today. Today is a filled circle.
import QtQuick
import qs

Column {
    id: root

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()      // 0..11
    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7

    function shift(d) {
        const m = new Date(year, month + d, 1);
        year = m.getFullYear();
        month = m.getMonth();
    }
    function reset() {
        today = new Date();
        year = today.getFullYear();
        month = today.getMonth();
    }

    width: parent ? parent.width : 300
    spacing: 4

    component Arrow: Rectangle {
        id: arrow
        property string icon
        signal hit
        width: 26
        height: 26
        radius: 6
        color: arrowArea.containsMouse ? Theme.hover : "transparent"
        Text {
            anchors.centerIn: parent
            text: arrow.icon
            color: Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: 16
        }
        MouseArea {
            id: arrowArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: arrow.hit()
        }
    }

    Item {
        width: parent.width
        height: 28

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 6
            text: Qt.formatDate(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                onClicked: root.reset()
            }
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Arrow { icon: "\u{F0141}"; onHit: root.shift(-1) }
            Arrow { icon: "\u{F0142}"; onHit: root.shift(1) }
        }
    }

    Grid {
        id: grid
        columns: 7
        readonly property real cell: root.width / 7

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            Text {
                required property string modelData
                width: grid.cell
                height: 22
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Theme.fgOff
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
        Repeater {
            model: 42
            Item {
                required property int index
                readonly property date day: new Date(root.year, root.month, 1 - root.offset + index)
                readonly property bool inMonth: day.getMonth() === root.month
                readonly property bool isToday: day.toDateString() === root.today.toDateString()
                width: grid.cell
                height: 30

                Rectangle {
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: parent.isToday ? Theme.cpu : "transparent"
                }
                Text {
                    anchors.centerIn: parent
                    text: parent.day.getDate()
                    color: parent.isToday ? "white" : parent.inMonth ? Theme.fg : Theme.fgOff
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: parent.isToday ? Font.DemiBold : Font.Normal
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}
