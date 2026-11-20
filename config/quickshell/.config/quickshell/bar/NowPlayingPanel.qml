// Player panel: large cover, title / artist / album, seek bar with times, controls,
// visualizer, and a player switcher when several are running.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs
import qs.widgets

DropPopup {
    id: root

    readonly property var player: Players.active

    contentWidth: 360

    component Ctl: Rectangle {
        id: ctl
        property string icon
        property bool on: true
        property bool accent: false
        property int size: 18
        signal hit
        width: size + 16
        height: size + 12
        radius: 8
        color: ctlArea.containsMouse && on ? Theme.hover : "transparent"
        Text {
            anchors.centerIn: parent
            text: ctl.icon
            color: !ctl.on ? Theme.fgOff : ctl.accent ? Theme.cpu : Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: ctl.size
        }
        MouseArea {
            id: ctlArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: if (ctl.on) ctl.hit()
        }
    }

    Row {
        width: parent.width
        spacing: 12

        ClippingRectangle {
            width: 84
            height: 84
            radius: 8
            color: Qt.rgba(1, 1, 1, 0.08)

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(256, 256)
                asynchronous: true
            }
            Text {
                visible: !(root.player?.trackArtUrl)
                anchors.centerIn: parent
                text: "\u{F075A}"
                color: Theme.fgDim
                font.family: Theme.iconFont
                font.pixelSize: 32
            }
        }

        Column {
            width: parent.width - 84 - 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: root.player?.trackTitle || root.player?.identity || ""
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player?.trackArtist ?? ""
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 12
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: 12
            }
            Text {
                text: root.player?.identity ?? ""
                color: Theme.fgOff
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
    }

    // Seek bar + times
    Item {
        visible: Players.length > 0
        width: parent.width
        height: 34

        BarSlider {
            y: 2
            width: parent.width
            value: Players.length > 0 ? Players.position / Players.length : 0
            onMoved: v => Players.seek(v * Players.length)
        }
        Text {
            anchors.bottom: parent.bottom
            text: Players.time(Players.position)
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
        Text {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            text: Players.time(Players.length)
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: 11
            font.features: { "tnum": 1 }
        }
    }

    // Controls
    Item {
        width: parent.width
        height: 44

        Row {
            anchors.centerIn: parent
            spacing: 6

            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\u{F049D}"
                size: 15
                on: root.player?.shuffleSupported ?? false
                accent: root.player?.shuffle ?? false
                onHit: root.player.shuffle = !root.player.shuffle
            }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\u{F04AE}"
                on: root.player?.canGoPrevious ?? false
                onHit: root.player.previous()
            }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"
                size: 26
                on: root.player?.canTogglePlaying ?? false
                onHit: root.player.togglePlaying()
            }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                icon: "\u{F04AD}"
                on: root.player?.canGoNext ?? false
                onHit: root.player.next()
            }
            Ctl {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.player?.loopState === MprisLoopState.Track ? "\u{F0458}" : "\u{F0456}"
                size: 15
                on: root.player?.loopSupported ?? false
                accent: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                onHit: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                    : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
            }
        }
    }

    Item {
        width: parent.width
        height: 34

        Visualizer {
            anchors.centerIn: parent
            barWidth: 6
            maxHeight: 30
            centered: false
            color: Theme.cpu
            opacity: root.player?.isPlaying ? 0.9 : 0.3
        }
    }

    // Player switcher (only when there are several)
    SectionLabel {
        visible: Players.all.length > 1
        text: "Players"
    }
    Repeater {
        model: Players.all.length > 1 ? Players.all : []

        MenuRow {
            required property var modelData
            icon: modelData.isPlaying ? "\u{F040A}" : "\u{F03E4}"
            text: modelData.identity + (modelData.trackTitle ? "  ·  " + modelData.trackTitle : "")
            active: modelData === root.player
            onClicked: Players.last = modelData
        }
    }
}
