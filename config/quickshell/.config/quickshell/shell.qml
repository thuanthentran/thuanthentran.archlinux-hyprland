//@ pragma UseQApplication
//@ pragma IconTheme WhiteSur-dark
// UseQApplication: needed for tray right-click menus. IconTheme: app / tray icons, keep in
// sync with install/apply-theme.sh. Pragmas only apply on a restart.
// Quickshell entry point: the top bar (one per screen) and small helpers.
// Saving any file under this directory reloads the shell (hot reload).
// Logs: `qs log`. Commands from scripts / keybinds: `qs ipc call <target> <fn>`.
// Imports: `qs` is this directory (Theme), `qs.widgets` / `qs.bar` its subdirectories.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.bar
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
            toast.show("Quickshell đang chạy");
            return "pong";
        }
    }

    Toast {
        id: toast
    }
}
