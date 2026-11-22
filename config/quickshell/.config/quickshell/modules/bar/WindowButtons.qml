// Minimize / restore / close for the maximized window, at the bar's right end (where the
// hidden title bar had them). Same grey dots as the hyprbars buttons; hovering the group
// shows every symbol (white minimize, green restore, red close).
import QtQuick
import qs.config
import qs.services
import qs.widgets

Reveal {
    id: root

    spacing: 8

    readonly property bool hot: hover.hovered
    HoverHandler {
        id: hover
    }

    Item { width: 2; height: 1 }
    Dot {
        symbol: "\u{F0374}"            // minus
        symbolColor: Theme.fg
        onActivated: ActiveWindow.minimize()
    }
    Dot {
        symbol: "\u{F0415}"            // plus
        symbolColor: Theme.accent
        onActivated: ActiveWindow.toggleMaximize()
    }
    Dot {
        symbol: "\u{F0156}"            // close
        symbolColor: Theme.red
        onActivated: ActiveWindow.close()
    }
    Item { width: 4; height: 1 }

    component Dot: Rectangle {
        id: dot

        property string symbol
        property color symbolColor
        signal activated

        anchors.verticalCenter: parent.verticalCenter
        width: 13
        height: 13
        radius: 6.5
        color: area.pressed ? Qt.lighter(Theme.titleButton, 1.25) : Theme.titleButton

        Text {
            anchors.centerIn: parent
            text: dot.symbol
            color: dot.symbolColor
            opacity: root.hot ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            font.family: Theme.iconFont
            font.pixelSize: 11
        }
        MouseArea {
            id: area
            anchors.fill: parent
            anchors.margins: -3
            onClicked: dot.activated()
        }
    }
}
