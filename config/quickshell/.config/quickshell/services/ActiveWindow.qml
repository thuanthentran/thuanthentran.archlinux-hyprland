// The focused window and whether it is maximized (`import qs.services`). Maximized here
// means scripts/toggle-maximize.sh tagged it `maximized`: Hyprland then hides its title bar
// and the top bar shows its title and buttons (WindowTitle, WindowButtons). Tags only come
// with Hyprland's window list, so it is re-read when focus changes and when the script (or
// keep_on_screen in hyprland.lua) calls `qs ipc call windows refresh`.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property bool maximized: (toplevel?.lastIpcObject?.tags ?? [])
        .some(t => t.replace(/\*$/, "") === "maximized")

    // Maximized and on this screen: what a bar shows
    function maximizedOn(screen) {
        return maximized && (toplevel?.monitor?.name ?? "") === screen?.name;
    }
    function refresh() {
        Hyprland.refreshToplevels();
    }

    function minimize() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize.sh", "minimize"]);
    }
    function toggleMaximize() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/toggle-maximize.sh"]);
    }
    function close() {
        Hyprland.dispatch("hl.dsp.window.close()");
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            Hyprland.refreshToplevels();
        }
    }
}
