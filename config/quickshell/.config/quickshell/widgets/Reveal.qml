// Content that slides open sideways when `shown`, with a small overshoot, and folds away
// to zero width (and out of its Row's spacing) when not.
import QtQuick

Item {
    id: root

    property bool shown: false
    property int spacing: 6
    default property alias content: inner.data

    implicitWidth: shown ? inner.implicitWidth : 0
    implicitHeight: inner.implicitHeight
    clip: true
    opacity: shown ? 1 : 0
    visible: shown || widthAnim.running

    Behavior on implicitWidth {
        NumberAnimation {
            id: widthAnim
            duration: 320
            easing.type: root.shown ? Easing.OutBack : Easing.InOutCubic
            easing.overshoot: 1.4
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 220 }
    }

    Row {
        id: inner
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.spacing
    }
}
