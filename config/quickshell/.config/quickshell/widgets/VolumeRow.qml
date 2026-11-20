// Mute button (icon or app icon) + name + slider + % for one PipeWire node.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import qs

Item {
    id: root

    required property PwNode node
    property string label: ""
    property string appIcon: ""            // icon theme name; empty = speaker glyph
    property bool metering: true           // show the level meter (measured only while visible)
    readonly property real volume: node?.audio?.volume ?? 0
    readonly property bool muted: node?.audio?.muted ?? false

    width: parent ? parent.width : 0
    implicitHeight: label !== "" ? 46 : 28

    function set(v) {
        if (node?.audio)
            node.audio.volume = Math.max(0, Math.min(1, v));
    }

    Text {
        visible: root.label !== ""
        x: 38
        y: 2
        width: parent.width - 38 - 8
        elide: Text.ElideRight
        text: root.label
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 12
    }

    Row {
        anchors.bottom: parent.bottom
        x: 8
        width: parent.width - 16
        height: 26
        spacing: 8

        // Mute toggle
        Rectangle {
            width: 22
            height: 22
            radius: 6
            anchors.verticalCenter: parent.verticalCenter
            color: muteArea.containsMouse ? Theme.hover : "transparent"

            Text {
                visible: root.appIcon === ""
                anchors.centerIn: parent
                text: root.muted ? "\u{F075F}" : "\u{F057E}"
                color: root.muted ? Theme.fgOff : Theme.fg
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSize
            }
            IconImage {
                visible: root.appIcon !== ""
                anchors.centerIn: parent
                implicitSize: 18
                opacity: root.muted ? 0.4 : 1
                source: Quickshell.iconPath(root.appIcon, "audio-x-generic")
            }
            MouseArea {
                id: muteArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: if (root.node?.audio) root.node.audio.muted = !root.muted
            }
        }
        BarSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 22 - 40 - 16
            value: root.volume
            peak: peaks.enabled && !root.muted ? peaks.peak : -1
            opacity: root.muted ? 0.5 : 1
            onMoved: v => root.set(v)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            horizontalAlignment: Text.AlignRight
            text: Math.round(root.volume * 100) + "%"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    PwNodePeakMonitor {
        id: peaks
        node: root.node
        enabled: root.metering && root.visible && (QsWindow.window?.visible ?? false)
    }

    // Scroll anywhere on the row changes this node's volume
    WheelHandler {
        onWheel: e => root.set(root.volume + e.angleDelta.y / 120 * 0.05)
    }
}
