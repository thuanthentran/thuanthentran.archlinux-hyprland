// Restore a minimized window, maximize, close (acts on the active window).
import QtQuick
import Quickshell
import qs
import qs.widgets

Row {
    spacing: 2

    readonly property string scripts: Quickshell.env("HOME") + "/.config/hypr/scripts/"

    function dispatch(expr) {
        Quickshell.execDetached(["hyprctl", "dispatch", expr]);
    }

    BarButton {
        text: "\u{F0638}"
        tooltip: "Restore a minimized window"
        onClicked: Quickshell.execDetached([parent.scripts + "minimize.sh", "restore"])
    }
    BarButton {
        text: "\u{F0293}"
        tooltip: "Maximize / restore"
        onClicked: Quickshell.execDetached([parent.scripts + "toggle-maximize.sh"])
    }
    BarButton {
        text: "\u{F05AD}"
        tooltip: "Close window"
        hoverColor: Theme.redHover
        onClicked: parent.dispatch("hl.dsp.window.close()")
    }
}
