// Quickshell entry point. Runs alongside Waybar; widgets are added here one by one.
// Saving any file under this directory reloads the shell (hot reload).
// Logs: `qs log`. Commands from scripts / Waybar / keybinds: `qs ipc call <target> <fn>`.
import Quickshell
import Quickshell.Io
import "widgets"

ShellRoot {
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

