// Title of the maximized window (its own title bar is hidden, see ActiveWindow), left in
// the bar's free space like a macOS app name. Fades in and out; never runs under the
// clock (`maxWidth`, set by the bar). Double-click restores the window.
import QtQuick
import qs.config
import qs.services

Item {
    id: root

    property bool shown: false
    property real maxWidth: 400

    implicitHeight: Theme.barHeight
    width: Math.min(label.implicitWidth, Math.max(0, maxWidth))
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 200 } }

    // the title of the last maximized window stays while fading out
    property string title: ""
    Binding on title {
        when: root.shown
        value: ActiveWindow.toplevel?.title ?? ""
    }

    Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        text: root.title
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.weight: Font.Medium
        elide: Text.ElideRight
        transform: Translate {
            x: root.shown ? 0 : -8
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }
    MouseArea {
        anchors.fill: parent
        onDoubleClicked: ActiveWindow.toggleMaximize()
    }
}
