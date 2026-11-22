// Panel that drops down below a bar item (calendar, Wi-Fi list, volume mixer, ...).
//
// It grows out of the item: `grow` 0 -> 1 interpolates the frame from a sliver as wide as
// the item, right under it, to the full panel (position, size and corner radius together);
// the content stays put, fading in as the frame uncovers it. Closing runs it all back.
//
// Not an xdg popup: the compositor closes those on an outside click at once, so the
// closing animation could never run (and Hyprland faded them instead). It is a
// transparent layer surface over the whole screen; a click outside the panel (the bar's
// own buttons included) or Esc closes it, animated. While open it takes the keyboard and
// holds the quick settings / an auto-hiding bar open (BarState.held).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: root

    required property Item anchorItem
    property string title: ""
    property int contentWidth: 320
    default property alias content: body.data
    property bool hasSwitch: false        // on / off switch right of the title
    property bool switchOn: false
    signal switchToggled
    property bool counted: false
    // Opened from IPC: no keyboard (keeps the focused app's), mostly for screenshots
    property bool grabFocus: true

    function toggle() {
        if (visible && !closeAnim.running)
            close();
        else
            visible = true;
    }
    function openWithoutGrab() {
        grabFocus = false;
        visible = true;
    }
    function close() {
        if (!visible || closeAnim.running)
            return;
        openAnim.stop();
        closeAnim.restart();
    }

    // Folding the quick settings closes their drop-downs
    Connections {
        target: BarState
        function onExpandedChanged() {
            if (!BarState.expanded)
                root.close();
        }
        // `qs ipc call bar collapse` sends "": close every drop-down
        function onPopupRequested(name) {
            if (name === "")
                root.close();
        }
    }

    screen: anchorItem?.QsWindow.window?.screen ?? null
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-popup"       // no Hyprland fade (layer rule)
    WlrLayershell.keyboardFocus: grabFocus ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

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
            place();
            openAnim.restart();
        }
    }
    Component.onDestruction: if (counted) BarState.held -= 1

    // --- geometry ---------------------------------------------------------------------

    readonly property int gap: 5          // between the bar's edge and the open panel
    readonly property real fullH: col.implicitHeight + 24
    property real grow: 0

    // The item's rect on the screen (the bar sits at the screen's top left), taken when
    // opening; the panel goes centred under it, kept on screen
    property rect item: Qt.rect(0, 0, 0, 0)
    function place() {
        if (!anchorItem)
            return;
        const p = anchorItem.mapToItem(null, 0, 0);
        item = Qt.rect(p.x, p.y, anchorItem.width, anchorItem.height);
    }
    readonly property real openX: Math.max(6, Math.min(width - contentWidth - 6, item.x + item.width / 2 - contentWidth / 2))
    readonly property real openY: Theme.barHeight + gap

    function lerp(a, b) {
        return a + (b - a) * grow;
    }

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
        NumberAnimation { target: root; property: "grow"; to: 0; duration: 200; easing.type: Easing.InOutCubic }
        ScriptAction { script: root.visible = false }
    }

    // Everything outside the panel: a click there (or Esc) closes it
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        focus: true
        onPressed: root.close()
        Keys.onEscapePressed: root.close()

        Rectangle {
            id: frame

            x: root.lerp(root.item.x, root.openX)
            y: root.lerp(root.item.y + root.item.height, root.openY)
            width: root.lerp(root.item.width, root.contentWidth)
            height: root.lerp(2, root.fullH)
            radius: root.lerp(1, 12)
            color: Theme.popupBg
            border.color: Theme.popupBorder
            clip: true

            // clicks on the panel's empty parts stay in the panel
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            // the content in its final place, whatever the frame's size now; it fades in and
            // out over the same time as the frame grows and shrinks
            Item {
                opacity: root.grow
                x: root.openX - frame.x
                y: root.openY - frame.y
                width: root.contentWidth
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
}
