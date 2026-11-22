// One window in the overview / film / Alt+Tab strip: its screencopy under a drawn
// stand-in for the hyprbars title bar, flying from the window's own rect (`info`,
// progress 0) to `goal` (progress 1). Grid tiles can be dragged to reorder.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config

Item {
    id: tile

    required property var ov         // the Overview window (mode, gesture, labels...)

    property var info
    property var goal                 // where it goes at progress 1
    property real progress
    property bool selected: false
    property bool dim: false
    property bool faded: false        // search: doesn't match
    property bool draggable: false
    readonly property bool dragging: tdrag.active
    readonly property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    readonly property bool painted: view.hasContent
    readonly property var toplevel: ov.toplevelFor(info.addr)
    signal picked
    signal closeRequested
    signal dragMoved(point p)         // pointer, in the overlay's coordinates

    property real fade: 1
    opacity: (faded ? 0.25 : 1) * fade
    Behavior on opacity { NumberAnimation { duration: 120 } }

    // Drag to reorder (grid): follows the pointer from where it was picked up; let go,
    // it glides into its slot
    property var dragFrom: null
    DragHandler {
        id: tdrag
        target: null
        enabled: tile.draggable
        onActiveChanged: {
            if (active) {
                tile.dragFrom = { x: tile.x, y: tile.y, w: tile.width, h: tile.height };
            } else {
                const r = { x: tile.x, y: tile.y, w: tile.width, h: tile.height };
                tile.dragFrom = null;
                tile.flyFrom(r, 0);
            }
        }
        onCentroidChanged: if (active) tile.dragMoved(tile.mapToItem(tile.parent, centroid.position.x, centroid.position.y))
    }

    // Spreading from the film into the grid: from `from` to `goal` as fly goes 0 -> 1
    property var from: null
    property real fly: 1
    function flyFrom(r, delay) {
        flyAnim.stop();
        from = r;
        fly = 0;
        pause.duration = delay;
        flyAnim.start();
    }
    readonly property var aim: dragFrom ? {
        x: dragFrom.x + tdrag.activeTranslation.x,
        y: dragFrom.y + tdrag.activeTranslation.y,
        w: dragFrom.w,
        h: dragFrom.h
    } : from && fly < 1 ? {
        x: from.x + (goal.x - from.x) * fly,
        y: from.y + (goal.y - from.y) * fly,
        w: from.w + (goal.w - from.w) * fly,
        h: from.h + (goal.h - from.h) * fly
    } : goal

    SequentialAnimation {
        id: flyAnim
        PauseAnimation {
            id: pause
        }
        NumberAnimation {
            target: tile
            property: "fly"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    x: info.x + (aim.x - info.x) * progress
    y: info.y + (aim.y - info.y) * progress
    width: info.w + (aim.w - info.w) * progress
    height: info.h + (aim.h - info.h) * progress

    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 12
        color: "transparent"
        border.width: 3
        border.color: Qt.rgba(1, 1, 1, 0.85)
        visible: tile.selected
    }

    // Drawn at the window's real size and scaled on the GPU: resizing it instead made
    // the clip texture and the title text re-render at rounded sizes every frame,
    // which showed as jitter (choppy motion) while zooming
    Item {
        id: body
        width: tile.info.w
        height: tile.info.h
        opacity: tile.dim ? 0.75 : 1
        transform: Scale {
            xScale: tile.width / tile.info.w
            yScale: tile.height / tile.info.h
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: 12                                     // Hyprland's rounding
            color: Qt.rgba(1, 1, 1, 0.08)

            // Stand-in for the hyprbars title bar (same colour, title, buttons)
            Rectangle {
                id: titleBar
                width: parent.width
                height: tile.info.bar
                visible: tile.info.bar > 0
                color: Qt.rgba(43 / 255, 43 / 255, 46 / 255, 0.94)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 100
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.info.title
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 9 * 1.33           // hyprbars bar_text_size (pt)
                    elide: Text.ElideRight
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: ["#ff5f57", "#28c840", "#febc2e"]
                        Rectangle {
                            required property string modelData
                            width: 11
                            height: 11
                            radius: 5.5
                            color: modelData
                        }
                    }
                }
            }

            ScreencopyView {
                id: view
                y: titleBar.height
                width: parent.width
                height: parent.height - titleBar.height
                captureSource: tile.toplevel?.wayland ?? null
                // frozen while the film moves (fingers or letting go): copying every
                // window every frame costs frames, and nobody reads them mid-swipe
                live: (ov.gesture !== "film" && !ov.settling) || !hasContent
            }
            // No picture (yet, or minimized windows Hyprland doesn't render): app icon
            IconImage {
                anchors.centerIn: parent
                visible: !view.hasContent
                implicitSize: Math.min(64, parent.height * 0.6)
                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(tile.info.appId)?.icon ?? tile.info.appId, "application-x-executable")
            }
        }
    }

    // Icon + title above the thumbnail, once shrunk
    Row {
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width)
        spacing: 6
        opacity: Math.max(0, ov.labels * 2 - 1)
        visible: !tile.dim

        IconImage {
            implicitSize: 18
            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(tile.info.appId)?.icon ?? tile.info.appId, "application-x-executable")
        }
        Text {
            width: Math.min(implicitWidth, tile.width - 24)
            text: tile.info.title
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: m => m.button === Qt.MiddleButton ? tile.closeRequested() : tile.picked()
    }

    // Close button on hover
    Rectangle {
        visible: tile.hovered && tile.progress === 1 && ov.mode === "grid"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 26
        height: 26
        radius: 13
        color: closeMouse.containsMouse ? Theme.red : Qt.rgba(40 / 255, 40 / 255, 44 / 255, 0.95)
        border.color: Theme.popupBorder

        Text {
            anchors.centerIn: parent
            text: "\u{F0156}"
            color: Theme.fg
            font.family: Theme.iconFont
            font.pixelSize: 14
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: tile.closeRequested()
        }
    }
}
