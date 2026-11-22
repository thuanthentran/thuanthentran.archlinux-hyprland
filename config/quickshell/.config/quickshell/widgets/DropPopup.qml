// Panel that drops down below a bar item (Wi-Fi list, volume mixer, ...). A click outside
// closes it (xdg popup grab, which also gives it the keyboard). While open it holds the
// quick settings expanded, since the mouse leaves the bar to use it.
import QtQuick
import Quickshell
import qs.config
import qs.services

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
        if (visible)
            close();
        else
            visible = true;
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

    // Opening grows the panel out of the bar item: `grow` 0 -> 1 interpolates the frame from
    // a sliver as wide as the item, right under it, to the full panel (position, size and
    // corner radius together); the content stays put and the frame uncovers it. Closing
    // through toggle() / close() runs it back into the item.
    readonly property int gap: 5          // between the bar's edge and the open panel
    readonly property real fullH: col.implicitHeight + 24
    property real grow: 0

    // Where the item's centre falls inside the popup. The popup is centred under the item
    // and slid back on screen near the edges (as the compositor does), so redo that here.
    readonly property real originX: {
        if (!anchorItem || !anchorItem.QsWindow.window)
            return width / 2;
        const c = anchorItem.mapToItem(null, anchorItem.width / 2, 0).x;
        const sw = anchorItem.QsWindow.window.width;
        const left = Math.max(0, Math.min(sw - width, c - width / 2));
        return c - left;
    }

    function close() {
        if (!visible)
            return;
        openAnim.stop();
        closeAnim.restart();
    }

    anchor.item: anchorItem
    anchor.rect.x: 0
    anchor.rect.y: anchorItem.height + (Theme.barHeight - anchorItem.height) / 2
    anchor.rect.width: anchorItem.width
    anchor.rect.height: 0
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    grabFocus: true
    visible: false
    color: "transparent"
    implicitWidth: contentWidth
    implicitHeight: fullH + gap

    onVisibleChanged: {
        if (!visible)
            grabFocus = true;
        if (visible !== counted) {
            BarState.held += visible ? 1 : -1;
            counted = visible;
        }
        if (visible) {
            closeAnim.stop();
            grow = 0;
            openAnim.restart();
        }
    }
    Component.onDestruction: if (counted) BarState.held -= 1

    NumberAnimation {
        id: openAnim
        target: root
        property: "grow"
        to: 1
        duration: 280
        easing.type: Easing.OutCubic
    }
    SequentialAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "grow"; to: 0; duration: 180; easing.type: Easing.InCubic }
        ScriptAction { script: root.visible = false }
    }

    function lerp(a, b) {
        return a + (b - a) * grow;
    }

    Rectangle {
        id: frame

        x: root.lerp(root.originX - root.anchorItem.width / 2, 0)
        y: root.lerp(0, root.gap)
        width: root.lerp(root.anchorItem.width, root.width)
        height: root.lerp(2, root.fullH)
        radius: root.lerp(1, 12)
        color: Theme.popupBg
        border.color: Theme.popupBorder
        clip: true

        // the content in its final place, whatever the frame's size now
        Item {
            x: -frame.x
            y: root.gap - frame.y
            width: root.width
            height: root.fullH

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
}
