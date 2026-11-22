// Current track on the bar: cover, visualizer, title with a thin progress line under it.
// Hover slides out prev / play-pause / next; click opens the player panel; middle click
// plays / pauses. Hidden when no player is running.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

BarButton {
    id: root

    readonly property var player: Players.active

    visible: player !== null
    padding: 6
    highlighted: panel.visible

    component Ctl: Text {
        id: ctl
        property bool enabledCtl: true
        signal hit
        anchors.verticalCenter: parent.verticalCenter
        color: enabledCtl ? (ctlArea.containsMouse ? "white" : Theme.fg) : Theme.fgOff
        font.family: Theme.iconFont
        font.pixelSize: 16
        MouseArea {
            id: ctlArea
            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            onClicked: if (ctl.enabledCtl) ctl.hit()
        }
    }

    ClippingRectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 4
        color: Qt.rgba(1, 1, 1, 0.1)

        Image {
            anchors.fill: parent
            source: root.player?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(64, 64)
            asynchronous: true
        }
        Text {
            visible: !(root.player?.trackArtUrl)
            anchors.centerIn: parent
            text: "\u{F075A}"
            color: Theme.fgDim
            font.family: Theme.iconFont
            font.pixelSize: 13
        }
    }

    Visualizer {
        anchors.verticalCenter: parent.verticalCenter
        opacity: root.player?.isPlaying ? 0.9 : 0.35
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            id: title
            width: Math.min(implicitWidth, 240)
            elide: Text.ElideRight
            text: {
                const p = root.player;
                if (!p)
                    return "";
                return p.trackArtist ? p.trackTitle + "  ·  " + p.trackArtist : p.trackTitle || p.identity;
            }
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: 12
        }
        // Progress line
        Rectangle {
            visible: Players.length > 0
            width: title.width
            height: 2
            radius: 1
            color: Qt.rgba(1, 1, 1, 0.18)

            Rectangle {
                height: parent.height
                radius: 1
                width: Players.length > 0 ? parent.width * Math.min(1, Players.position / Players.length) : 0
                color: Theme.fg
            }
        }
    }

    Reveal {
        anchors.verticalCenter: parent.verticalCenter
        shown: root.hovered || panel.visible
        spacing: 10

        Ctl {
            text: "\u{F04AE}"
            enabledCtl: root.player?.canGoPrevious ?? false
            onHit: root.player.previous()
        }
        Ctl {
            text: root.player?.isPlaying ? "\u{F03E4}" : "\u{F040A}"
            enabledCtl: root.player?.canTogglePlaying ?? false
            onHit: root.player.togglePlaying()
        }
        Ctl {
            text: "\u{F04AD}"
            enabledCtl: root.player?.canGoNext ?? false
            onHit: root.player.next()
        }
    }

    NowPlayingPanel {
        id: panel
        anchorItem: root
    }

    onClicked: m => {
        if (m.button === Qt.MiddleButton)
            player?.togglePlaying();
        else
            panel.toggle();
    }

    Connections {
        target: BarState
        function onPopupRequested(name) {
            if (name === "media")
                panel.openWithoutGrab();
        }
    }
}
