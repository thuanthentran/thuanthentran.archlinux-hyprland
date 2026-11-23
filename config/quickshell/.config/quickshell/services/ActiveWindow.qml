// The focused window and whether it is maximized (`import qs.services`). Maximized here
// means scripts/toggle-maximize.sh tagged it `maximized`: Hyprland then hides its title bar
// and the top bar shows its title and buttons (WindowTitle, WindowButtons). Tags only come
// with Hyprland's window list, so it is re-read when focus changes and when the script (or
// keep_on_screen in hyprland.lua) calls `qs ipc call windows refresh`.
//
// Also guards the minimized-window stash (special:magic): focusing a window in it from
// outside (nwg-dock's click does `hl.dsp.focus`) makes Hyprland open the stash over the
// workspace instead of bringing the window back. When the stash opens that way, the window
// is restored (minimize.sh restore); opening it on purpose to look in goes through peek()
// (Super+Shift+S, `qs ipc call windows peek`), which is left alone.
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
    // Focus a window (address with or without 0x) and raise it: focus alone leaves a covered
    // floating window under the others. Minimized ones (in the stash) are restored instead.
    function focus(addr, minimized) {
        const a = "0x" + (addr ?? "").replace(/^0x/, "");
        if (minimized)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize.sh", "restore", a]);
        else
            Hyprland.dispatch(`(function() hl.dispatch(hl.dsp.focus({ window = "address:${a}" })) hl.dispatch(hl.dsp.window.bring_to_top()) end)`);
    }
    function close() {
        Hyprland.dispatch("hl.dsp.window.close()");
    }

    property real peekUntil: 0
    function peek() {
        peekUntil = Date.now() + 1000;
        Hyprland.dispatch('hl.dsp.workspace.toggle_special("magic")');
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            Hyprland.refreshToplevels();
        }
        // "activespecial>>special:magic,eDP-1" when the stash opens on a screen
        function onRawEvent(event) {
            if (event.name === "activespecial" && event.data.startsWith("special:magic,") && Date.now() > root.peekUntil)
                unstash.restart();
        }
    }
    // after the focus event that opened it has landed
    Timer {
        id: unstash
        interval: 60
        onTriggered: {
            const t = Hyprland.activeToplevel;
            if (t && t.workspace?.name === "special:magic")
                Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize.sh", "restore", t.address]);
        }
    }
}
