// CPU and RAM graphs plus network speed. When the quick settings expand, the percentages
// slide out next to the graphs.
import QtQuick
import qs
import qs.widgets

Row {
    id: root

    spacing: 2

    component Meter: BarButton {
        id: meter

        property string label
        property real value
        property var history
        property color graphColor
        property string details

        pill: false
        padding: 6
        tooltip: details

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: meter.label
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
        Sparkline {
            anchors.verticalCenter: parent.verticalCenter
            values: meter.history
            color: meter.graphColor
        }
        Reveal {
            anchors.verticalCenter: parent.verticalCenter
            shown: BarState.expanded

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                text: Math.round(meter.value * 100) + "%"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }

    Meter {
        label: "CPU"
        value: SysStats.cpu
        history: SysStats.cpuHistory
        graphColor: Theme.cpu
        details: "CPU " + Math.round(SysStats.cpu * 100) + "%"
    }
    Meter {
        label: "RAM"
        value: SysStats.mem
        history: SysStats.memHistory
        graphColor: Theme.ram
        details: "RAM " + SysStats.memUsedGiB.toFixed(1) + " / " + SysStats.memTotalGiB.toFixed(1) + " GiB"
    }

    // Network speed: fixed-width columns so the bar doesn't shift as the numbers change
    BarButton {
        pill: false
        padding: 6

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Repeater {
                model: [["\u{F0045}", SysStats.rxRate], ["\u{F005D}", SysStats.txRate]]

                Row {
                    required property var modelData
                    spacing: 3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[0]
                        color: Theme.fgDim
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                    }
                    Text {
                        width: 58
                        horizontalAlignment: Text.AlignRight
                        text: SysStats.rate(modelData[1])
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 10
                        font.features: { "tnum": 1 }
                    }
                }
            }
        }
    }
}
