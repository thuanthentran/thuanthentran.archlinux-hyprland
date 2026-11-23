// What a lock screen shows (one per screen, also the preview): the wallpaper dimmed, the
// date and a large clock on top, then a round avatar (the user's initial), the name and a
// password pill. Typing goes to the pill from anywhere; Enter checks it, Esc clears it (or
// closes the preview). A wrong password shakes the pill and says why under it.
// Comes in by fading and settling the clock down, goes out by fading up before unlocking.
// Also the boot login screen: the greeter (extras/greeter/shell.qml) passes a `lock` object
// with the same members, backed by greetd, plus the user and a wallpaper it can read.
import QtQuick
import Quickshell
import qs.config

Item {
    id: root

    required property var lock
    property bool preview: false
    property string user: Quickshell.env("USER") ?? ""
    property string wallpaper: Quickshell.env("HOME") + "/.config/hypr/wallpapers/default.png"

    // 0 -> 1 on arrival, back to 0 while unlocking
    property real shown: 0
    Component.onCompleted: {
        shown = 1;
        input.forceActiveFocus();
    }
    Behavior on shown {
        NumberAnimation {
            duration: root.lock.leaving ? 240 : 600
            easing.type: root.lock.leaving ? Easing.InCubic : Easing.OutCubic
        }
    }
    Connections {
        target: root.lock
        function onLeavingChanged() {
            if (root.lock.leaving)
                root.shown = 0;
        }
        function onFailed() {
            shake.restart();
            input.forceActiveFocus();
        }
    }

    Image {
        anchors.fill: parent
        source: "file://" + root.wallpaper
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // a click anywhere puts the typing back in the field
    MouseArea {
        anchors.fill: parent
        onPressed: input.forceActiveFocus()
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: root.shown

        // date + time
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.11 - 24 * (1 - root.shown)
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: 20
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Theme.fg
                font.family: Theme.displayFont
                font.pixelSize: 120
                font.weight: Font.Bold
            }
        }

        // who + password
        Column {
            id: login
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.6 + 16 * (1 - root.shown)
            spacing: 12

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76
                height: 76
                radius: 38
                color: Qt.rgba(1, 1, 1, 0.1)
                border.color: Qt.rgba(1, 1, 1, 0.16)
                Text {
                    anchors.centerIn: parent
                    text: (root.user || "?").charAt(0).toUpperCase()
                    color: Theme.fg
                    font.family: Theme.displayFont
                    font.pixelSize: 34
                    font.weight: Font.Bold
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.user
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Item { width: 1; height: 4 }

            Rectangle {
                id: pill
                anchors.horizontalCenter: parent.horizontalCenter
                width: 260
                height: 40
                radius: 20
                color: Qt.rgba(1, 1, 1, 0.1)
                border.color: root.lock.messageIsError && root.lock.password === ""
                    ? Qt.rgba(Theme.red.r, Theme.red.g, Theme.red.b, 0.7)
                    : input.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : Qt.rgba(1, 1, 1, 0.16)
                Behavior on border.color { ColorAnimation { duration: 160 } }
                transform: Translate { id: shakeT }

                Text {
                    anchors.centerIn: parent
                    visible: input.text === ""
                    text: root.lock.checking ? "" : "Enter password"
                    color: Theme.fgOff
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                }
                TextInput {
                    id: input
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 40
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: 18
                    font.letterSpacing: 2
                    clip: true
                    readOnly: root.lock.checking
                    cursorDelegate: Rectangle {
                        width: 1.5
                        color: Theme.accent
                        // only once something is typed: never on top of the hint
                        visible: input.cursorVisible && input.text !== ""
                    }
                    text: root.lock.password
                    onTextChanged: root.lock.password = text
                    Keys.onReturnPressed: root.lock.submit()
                    Keys.onEnterPressed: root.lock.submit()
                    Keys.onEscapePressed: {
                        if (root.preview && text === "")
                            root.lock.unlock();
                        else
                            root.lock.password = "";
                    }
                }
                // go button, or a spinner while PAM checks
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: 14
                    color: goArea.containsMouse ? Theme.active : Theme.hover
                    opacity: root.lock.password !== "" || root.lock.checking ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    // drawn, not a glyph: icon fonts sit off centre at this size
                    Canvas {
                        id: arrow
                        anchors.fill: parent
                        visible: !root.lock.checking
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.strokeStyle = Theme.fg;
                            c.lineWidth = 1.6;
                            c.lineCap = "round";
                            c.lineJoin = "round";
                            c.beginPath();
                            c.moveTo(9, 14);
                            c.lineTo(19, 14);
                            c.moveTo(15, 10);
                            c.lineTo(19, 14);
                            c.lineTo(15, 18);
                            c.stroke();
                        }
                    }
                    Canvas {
                        id: spinner
                        anchors.fill: parent
                        visible: root.lock.checking
                        onPaint: {
                            const c = getContext("2d");
                            c.reset();
                            c.strokeStyle = Theme.fg;
                            c.lineWidth = 1.6;
                            c.lineCap = "round";
                            c.beginPath();
                            c.arc(14, 14, 6.5, 0, Math.PI * 1.5);
                            c.stroke();
                        }
                        RotationAnimator on rotation {
                            running: root.lock.checking
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }
                    MouseArea {
                        id: goArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.lock.submit()
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                text: root.lock.message
                color: root.lock.messageIsError ? Theme.red : Theme.fgDim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 24
            visible: root.preview
            text: "Preview: Esc to close"
            color: Theme.fgOff
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: shakeT; property: "x"; to: -12; duration: 50; easing.type: Easing.OutQuad }
        NumberAnimation { target: shakeT; property: "x"; to: 10; duration: 70; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeT; property: "x"; to: -7; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeT; property: "x"; to: 4; duration: 50; easing.type: Easing.InOutQuad }
        NumberAnimation { target: shakeT; property: "x"; to: 0; duration: 50; easing.type: Easing.OutQuad }
    }
}
