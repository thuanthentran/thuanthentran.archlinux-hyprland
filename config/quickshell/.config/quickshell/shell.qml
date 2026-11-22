//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
//@ pragma NativeTextRendering
// UseQApplication: needed for tray right-click menus. IconTheme: app / tray icons, keep in
// sync with install/apply-theme.sh. NativeTextRendering: draw text with FreeType +
// fontconfig hinting like other apps (Qt's default distance-field text looked frayed on
// curves and diagonals at small sizes). Pragmas only apply on a restart.
// Quickshell entry point: the top bar (one per screen) and small helpers.
// Saving any file under this directory reloads the shell (hot reload).
// Logs: `qs log`. Commands from scripts / keybinds: `qs ipc call <target> <fn>`.
// Imports: `qs.config` (Theme, Settings), `qs.services` (data singletons: BarState, SysStats,
// Players, Notifs, Touchpad, WindowOrder...), `qs.widgets` (shared pieces), `qs.modules.*`
// (bar, overview, osd, notifications, settings).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.overview
import qs.modules.osd
import qs.modules.notifications
import qs.modules.settings
import qs.modules.launcher
import qs.widgets

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    // `qs ipc call shell ping` -> shows a toast; checks that IPC and layer shell work
    IpcHandler {
        target: "shell"

        function ping(): string {
            toast.show("Quickshell is running");
            return "pong";
        }
    }

    // `qs ipc call bar expand|collapse|toggle` -> quick settings; `qs ipc call bar popup
    // sound|wifi|bluetooth|media|clock` opens a drop-down (also handy for testing)
    IpcHandler {
        target: "bar"

        function expand(): void { BarState.expanded = true; }
        function collapse(): void { BarState.expanded = false; BarState.popupRequested(""); }
        function toggle(): void { BarState.expanded = !BarState.expanded; }
        function popup(name: string): void { BarState.popupRequested(name); }
    }

    // `qs ipc call windows refresh`: re-read Hyprland's windows (toggle-maximize.sh calls
    // it after tagging a window `maximized`)
    IpcHandler {
        target: "windows"

        function refresh(): void { ActiveWindow.refresh(); }
    }

    Osd {
        id: osd
    }
    Popups {}
    // `qs ipc call osd brightness|volume|mic`: show the OSD (brightness keys call this,
    // since sysfs changes can't be watched)
    IpcHandler {
        target: "osd"

        function brightness(): void {
            Backlight.refresh();
            osd.show("brightness");
        }
        function volume(): void { osd.show("volume"); }
        function mic(): void { osd.show("mic"); }
    }

    // `qs ipc call notifs clear|dnd`: clear the notification list / toggle Do Not Disturb
    IpcHandler {
        target: "notifs"

        function clear(): void { Notifs.clearAll(); }
        function dnd(): bool {
            Notifs.dnd = !Notifs.dnd;
            return Notifs.dnd;
        }
    }

    Launcher {
        id: launcher
    }
    // `qs ipc call launcher toggle|search <text>`: the app launcher (also the Apps button,
    // Super+R)
    IpcHandler {
        target: "launcher"

        function toggle(): void { launcher.toggle(); }
        function search(text: string): void {   // for testing: open it with this typed
            if (!launcher.open)
                launcher.show();
            launcher.typeText(text);
        }
    }

    SettingsWindow {
        id: settings
    }
    // `qs ipc call settings open`: the Settings window (also in the power menu)
    IpcHandler {
        target: "settings"

        function open(): void { settings.open(); }
    }

    Overview {
        id: overview
    }
    // `qs ipc call overview toggle|alttab <1|-1>|release|swipe begin|move dx dy|swipe end`:
    // window overview, Alt+Tab strip, 3-finger gesture
    // (keys use the GlobalShortcuts inside)
    IpcHandler {
        target: "overview"

        function toggle(): void { overview.toggle(); }
        // Alt+Tab steps (1 / -1) and Alt release, for testing without the keyboard
        function alttab(dir: int): void { overview.altTab(dir); }
        function release(): void { overview.altReleased(); }
        // 3-finger swipe by hand: swipe begin|end, then swipe move with dx dy in mm (dy < 0 is up)
        function swipe(phase: string): void {
            if (phase === "begin") overview.gestureBegin();
            else overview.gestureEnd(false);
        }
        function move(dx: real, dy: real): void { overview.gestureUpdate(dx, dy); }
        function bench(): void { overview.bench(); }   // frame timing, see Overview.qml
        function search(text: string): void { overview.query = text; }   // like typing in the grid
    }

    Toast {
        id: toast
    }
}
