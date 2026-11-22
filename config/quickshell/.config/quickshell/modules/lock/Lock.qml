// Lock screen (replaces hyprlock): ext-session-lock through WlSessionLock, so the
// compositor keeps everything hidden until we unlock, and the password is checked by PAM
// with the same `login` stack hyprlock used (faillock included).
//
// Locking goes through `scripts/lock.sh` (hypridle's lock_cmd, so `loginctl lock-session`,
// Super+Ctrl+Q and the power menu all end up here); it falls back to hyprlock when
// Quickshell doesn't answer. While locked a marker file is kept: if Quickshell dies and is
// restarted, it locks again at once, and `misc.allow_session_lock_restore` in hyprland.lua
// lets it take the lock back from Hyprland's "lock client died" screen.
//
// `qs ipc call lock preview` shows the same screen in an ordinary overlay (Esc closes it),
// to look at it without locking anything.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.config
import qs.services

Scope {
    id: root

    property bool locked: false
    property bool previewing: false
    readonly property bool active: locked || previewing

    // shared by every screen's password field
    property string password: ""
    property bool checking: false
    property string message: ""
    property bool messageIsError: false
    property bool leaving: false          // fading out before the lock goes away
    signal failed

    function lock() {
        if (locked)
            return;
        BarState.popupRequested("");
        reset();
        locked = true;
        marker.setText("locked\n");
    }
    function preview() {
        if (active)
            return;
        reset();
        previewing = true;
    }
    function closePreview() {
        if (previewing && !locked)
            unlock();
    }
    function reset() {
        password = "";
        checking = false;
        message = "";
        messageIsError = false;
        leaving = false;
    }
    function submit() {
        if (checking || leaving || password === "")
            return;
        checking = true;
        message = "";
        if (!pam.start()) {
            checking = false;
            message = "Couldn't start authentication";
            messageIsError = true;
        }
    }
    function unlock() {
        leaving = true;
        leaveTimer.restart();
    }
    Timer {
        id: leaveTimer
        interval: 260                     // the content's fade out (LockSurface)
        onTriggered: {
            root.locked = false;
            root.previewing = false;
            root.reset();
            marker.setText("");
        }
    }

    PamContext {
        id: pam
        config: "login"
        onPamMessage: {
            if (responseRequired) {
                respond(root.password);
            } else if (message !== "") {
                root.message = message;
                root.messageIsError = messageIsError;
            }
        }
        onCompleted: result => {
            root.checking = false;
            if (result === PamResult.Success) {
                root.unlock();
                return;
            }
            root.password = "";
            if (!root.messageIsError || root.message === "")
                root.message = result === PamResult.MaxTries ? "Too many attempts" : "Wrong password";
            root.messageIsError = true;
            root.failed();
        }
        onError: error => {
            root.checking = false;
            root.password = "";
            root.message = "Authentication error: " + PamError.toString(error);
            root.messageIsError = true;
            root.failed();
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: root.locked

        WlSessionLockSurface {
            color: "black"
            LockSurface {
                anchors.fill: parent
                lock: root
            }
        }
    }

    Variants {
        model: root.previewing ? [Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]] : []

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "black"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            LockSurface {
                anchors.fill: parent
                lock: root
                preview: true
            }
        }
    }

    // Locked when Quickshell went away: lock again on start
    FileView {
        id: marker
        path: Quickshell.statePath("locked")
        onLoaded: if (text().trim() === "locked") root.lock()
    }
}
