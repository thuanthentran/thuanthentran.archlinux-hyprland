// Tooltip shown below `target` after a short hover.
//
// A layer-shell overlay with an empty input mask, not an xdg popup: a popup that holds a
// grab makes the compositor spend the next click outside it on closing it, so after
// hovering a taskbar icon long enough for its tooltip, clicking the icon did nothing
// ("works sometimes"). This one never takes input; clicks go straight through.
// Assumes the target's window sits at the screen's top left (the bar), like DropPopup.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

PanelWindow {
    id: root

    required property Item target
    property string text: ""
    property bool show: false

    screen: target?.QsWindow.window?.screen ?? null
    anchors {
        top: true
        left: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-tooltip"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12

    // centred 6 px below the target, kept on screen
    function place() {
        const p = target.mapToItem(null, 0, 0);
        const sw = screen?.width ?? 1920;
        margins.left = Math.round(Math.max(6, Math.min(sw - implicitWidth - 6, p.x + target.width / 2 - implicitWidth / 2)));
        margins.top = Math.round(p.y + target.height + 6);
    }

    onShowChanged: if (!show) visible = false

    Timer {
        running: root.show
        interval: 500
        onTriggered: {
            root.place();
            root.visible = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.popupBg
        border.color: Theme.popupBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }
}
