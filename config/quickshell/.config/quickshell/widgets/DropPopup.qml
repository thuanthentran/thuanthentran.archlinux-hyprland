// Panel that drops down below a bar item (Wi-Fi list, volume mixer, ...). A click outside
// closes it (xdg popup grab, which also gives it the keyboard). While open it holds the
// quick settings expanded, since the mouse leaves the bar to use it.
import QtQuick
import Quickshell
import qs

PopupWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property int contentWidth: 320
    default property alias content: body.data
    property bool hasSwitch: false        // on / off switch right of the title
    property bool switchOn: false
    signal switchToggled
    property bool counted: false

    function toggle() {
        visible = !visible;
    }
    // Opened without a click (IPC): the compositor refuses a popup grab without a recent
    // input event, so open it without one (no keyboard, no close-on-outside-click)
    function openWithoutGrab() {
        grabFocus = false;
        visible = true;
    }

    // Folding the quick settings closes their drop-downs
    Connections {
        target: BarState
        function onExpandedChanged() {
            if (!BarState.expanded)
                root.visible = false;
        }
        // `qs ipc call bar collapse` sends "": close every drop-down
        function onPopupRequested(name) {
            if (name === "")
                root.visible = false;
        }
    }

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem.height + 8
    anchor.rect.width: anchorItem.width
    anchor.rect.height: 0
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    visible: false
    color: "transparent"
    implicitWidth: contentWidth
    implicitHeight: frame.implicitHeight

    onVisibleChanged: {
        if (!visible)
            grabFocus = true;
        if (visible !== counted) {
            BarState.held += visible ? 1 : -1;
            counted = visible;
        }
        if (visible) {
            frame.opacity = 0;
            slide.y = -8;
            openAnim.restart();
        }
    }
    Component.onDestruction: if (counted) BarState.held -= 1

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: frame; property: "opacity"; to: 1; duration: 160 }
        NumberAnimation { target: slide; property: "y"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    Rectangle {
        id: frame

        width: parent.width
        implicitHeight: col.implicitHeight + 24
        radius: 12
        color: Theme.popupBg
        border.color: Theme.popupBorder
        transform: Translate { id: slide }

        Column {
            id: col
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            Item {
                visible: root.title !== ""
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Switch {
                    visible: root.hasSwitch
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.switchOn
                    onToggled: root.switchToggled()
                }
            }

            Column {
                id: body
                width: parent.width
                spacing: 4
            }
        }
    }
}
