// Search pill: a real text field (select, Ctrl+A / C / V...) with a hint while empty. The
// caret only shows once the field is in use (clicked, or something typed), so the hint and
// the caret never sit on top of each other. Used by the overview and the launcher, whose
// window has the keyboard: call takeFocus() so typing anywhere lands here (`focus` is
// already an Item property).
//
// `key(e)` comes first for every key press: set e.accepted to take it (navigation keys),
// leave it for the field to edit text. `engaged` goes back to false with clear().
import QtQuick
import qs.config

Rectangle {
    id: root

    property string hint: "Type to search"
    property bool engaged: false
    readonly property string text: input.text
    property int minWidth: 320
    signal key(var e)

    function takeFocus() {
        input.forceActiveFocus();
    }
    function clear() {
        input.text = "";
        engaged = false;
    }
    function setText(t) {
        input.text = t;
    }
    // A typed character that reached the window but not the field (it had lost focus)
    function insert(t) {
        input.forceActiveFocus();
        input.insert(input.cursorPosition, t);
    }

    implicitWidth: Math.max(minWidth, input.contentWidth + 80)
    implicitHeight: 34
    radius: height / 2
    color: Theme.popupBg
    border.color: Theme.popupBorder

    // the whole pill takes clicks (around the text too)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: {
            root.engaged = true;
            input.forceActiveFocus();
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0349}"    // magnify
        color: Theme.fgDim
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
    }
    Text {
        anchors.centerIn: parent
        visible: !root.engaged && input.text === ""
        text: root.hint
        color: Theme.fgOff
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
    }

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 24
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        color: Theme.fg
        selectionColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
        selectedTextColor: Theme.fg
        selectByMouse: true
        clip: true
        font.family: Theme.font
        font.pixelSize: Theme.fontSize + 1
        cursorDelegate: Rectangle {
            width: 1.5
            color: Theme.accent
            visible: input.cursorVisible && root.engaged
        }
        onTextChanged: if (text) root.engaged = true
        Keys.onPressed: e => root.key(e)

        // a press on the text itself (selecting) also counts as using the field
        TapHandler {
            onPressedChanged: if (pressed) root.engaged = true
        }
    }
}
