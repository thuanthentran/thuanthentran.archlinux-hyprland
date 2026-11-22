// Top bar, one per screen. Normally reserves its height (exclusive zone), so tiling,
// maximize and keep_on_screen (which read the monitor's reserved area) follow it.
// With Settings.barAutoHide it reserves nothing and hides above the screen: only a thin
// strip at the top edge takes the pointer; touching it slides the bar down, and it slides
// back up once the pointer leaves (not while the quick settings or a drop-down are open).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: bar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: "transparent"
    exclusionMode: Settings.barAutoHide ? ExclusionMode.Ignore : ExclusionMode.Auto
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.layer: WlrLayer.Top

    // The focused window on this screen is maximized: its title and buttons are up here
    readonly property bool maximized: ActiveWindow.maximizedOn(screen)

    // Auto-hide: shown while the pointer is on it (after touching the top edge) or
    // something opened from it is in use
    property bool revealed: false
    readonly property bool shown: !Settings.barAutoHide || revealed || BarState.expanded || BarState.held > 0
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                hideLater.stop();
                bar.revealed = true;
            } else {
                hideLater.restart();
            }
        }
    }
    Timer {
        id: hideLater
        interval: 500
        onTriggered: bar.revealed = hover.hovered
    }
    // When hidden only this strip takes input; the rest passes through to the windows
    Item {
        id: edge
        width: parent.width
        height: 2
    }
    mask: Region {
        item: bar.shown ? body : edge
    }

    Rectangle {
        id: body
        width: parent.width
        height: Theme.barHeight
        color: Theme.barBg
        y: bar.shown ? 0 : -height
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 4

            AppsButton {}
            Workspaces {}
            Taskbar {}
            NowPlaying {}

            // free space; the maximized window's title sits at its left
            Item {
                id: gap
                Layout.fillWidth: true
                implicitHeight: Theme.barHeight

                WindowTitle {
                    x: 8
                    shown: bar.maximized
                    // up to the clock (or the whole gap while the clock is hidden)
                    maxWidth: (BarState.expanded ? gap.width : clock.x - 4 - gap.x) - x - 16
                }
            }

            SystemStats {}
            QuickSettings {}
            Tray {}
            Battery {}
            PowerButton {}
            WindowButtons {
                shown: bar.maximized
            }
        }

        // Centred on the screen, not between the left and right groups. Fades out while the
        // quick settings are expanded, which may need its space.
        Clock {
            id: clock
            anchors.centerIn: parent
            opacity: BarState.expanded ? 0 : 1
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
