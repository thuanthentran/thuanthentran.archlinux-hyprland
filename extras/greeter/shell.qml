//@ pragma NativeTextRendering
// Boot login screen: a Quickshell greeter for greetd, the lock screen's twin (it draws the
// same modules/lock/LockSurface.qml). Not run from the repo: `setup.sh greeter` copies this
// file, the quickshell config/ dir (Theme, Settings), LockSurface and the wallpaper into
// /etc/greetd/quickshell, since the `greeter` user can't read anyone's home; greetd starts
// Hyprland with /etc/greetd/hyprland.lua, which runs `qs -p /etc/greetd/quickshell`.
//
// Login: the user is the first regular account in /etc/passwd (uid 1000-59999 with a real
// shell); the typed password answers greetd's prompts, then the Hyprland session starts
// the same way the hyprland.desktop session entry does.
//
// Outside greetd (Greetd.available false) it runs as a test: `qs -p <that dir>` shows it
// over the current session, every password "fails" and Esc quits.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import qs.modules.lock

ShellRoot {
    id: root

    // --- what LockSurface expects from its `lock` --------------------------------------
    property string password: ""
    property bool checking: false
    property string message: ""
    property bool messageIsError: false
    property bool leaving: false
    signal failed

    readonly property bool testMode: !Greetd.available
    readonly property var session: ["/usr/bin/start-hyprland"]
    readonly property var sessionEnv: ["XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=Hyprland", "XDG_SESSION_DESKTOP=Hyprland"]

    function submit() {
        if (checking || leaving || password === "" || user === "")
            return;
        checking = true;
        message = "";
        messageIsError = false;
        if (testMode)
            testFail.restart();
        else
            Greetd.createSession(user);
    }
    // Esc on an empty field: only means something in the test
    function unlock() {
        if (testMode)
            Qt.quit();
    }
    function fail(text) {
        checking = false;
        password = "";
        message = text;
        messageIsError = true;
        failed();
    }

    Timer {
        id: testFail
        interval: 600
        onTriggered: root.fail("Test mode: not checked (Esc quits)")
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.password);
            } else if (message !== "") {
                root.message = message;
                root.messageIsError = error;
            }
        }
        function onAuthFailure(message) {
            root.fail(message !== "" ? message : "Wrong password");
        }
        function onError(error) {
            root.fail("Login error: " + error);
            if (Greetd.state !== GreetdState.Inactive)
                Greetd.cancelSession();
        }
        function onReadyToLaunch() {
            root.leaving = true;          // LockSurface fades out
            launch.restart();
        }
    }
    Timer {
        id: launch
        interval: 260
        // quit: true, Quickshell exits once greetd has it; the greeter's Hyprland follows
        onTriggered: Greetd.launch(root.session, root.sessionEnv, true)
    }

    // --- who ---------------------------------------------------------------------------
    property string user: ""
    FileView {
        path: "/etc/passwd"
        onLoaded: {
            for (const line of text().split("\n")) {
                const f = line.split(":");
                const uid = parseInt(f[2]);
                if (uid >= 1000 && uid < 60000 && !/(nologin|false)$/.test(f[6] ?? "")) {
                    root.user = f[0];
                    return;
                }
            }
        }
    }

    // --- one screen each; the first one takes the keyboard -----------------------------
    Variants {
        model: Quickshell.screens

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
            WlrLayershell.namespace: "quickshell-greeter"
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            LockSurface {
                anchors.fill: parent
                lock: root
                user: root.user
                wallpaper: Quickshell.shellPath("wallpaper.png")
            }
        }
    }
}
