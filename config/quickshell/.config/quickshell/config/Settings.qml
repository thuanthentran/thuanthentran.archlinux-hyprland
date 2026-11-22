// User settings (`import qs.config`, then `Settings.mouseSpeed`), saved to settings.json
// next to this file. It lives in the repo (~/.config/quickshell is a Stow symlink), so the
// choices come back with the dotfiles; the Settings window edits them, or edit the JSON by
// hand (it is watched and reloaded).
//
// Pointer settings are pushed into Hyprland at start, on every change and after Hyprland
// reloads its config, so they win over the values written in hyprland.lua.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root

    // -1 .. 1, libinput's speed (0 = default)
    property alias mouseSpeed: data.mouseSpeed
    property alias touchpadSpeed: data.touchpadSpeed
    property alias mouseAccel: data.mouseAccel           // false: flat (same speed slow or fast)
    property alias mouseScroll: data.mouseScroll         // scroll distance factor
    property alias touchpadScroll: data.touchpadScroll

    FileView {
        id: file
        path: Quickshell.shellPath("config/settings.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: root.apply()
        // first run: write the defaults
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
            root.apply();
        }

        JsonAdapter {
            id: data

            property real mouseSpeed: 0
            property real touchpadSpeed: 0
            property bool mouseAccel: true
            property real mouseScroll: 1.0
            property real touchpadScroll: 0.5
        }
    }

    // --- Hyprland ---------------------------------------------------------------------

    // The touchpad gets its own speed through a per-device block; its name comes from
    // `hyprctl devices`
    property string touchpad: ""
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const pad = JSON.parse(text).mice.find(m => /touchpad/i.test(m.name));
                    root.touchpad = pad?.name ?? "";
                } catch (e) {}
                root.apply();
            }
        }
    }

    function num(v) {
        return Number(v).toFixed(3);
    }

    // Batched: several values often change together (a slider drag, a file reload)
    function apply() {
        applyLater.restart();
    }
    Timer {
        id: applyLater
        interval: 50
        onTriggered: {
            let lua = `hl.config({ input = { sensitivity = ${root.num(root.mouseSpeed)}, `
                + `accel_profile = "${root.mouseAccel ? "adaptive" : "flat"}", `
                + `scroll_factor = ${root.num(root.mouseScroll)}, `
                + `touchpad = { scroll_factor = ${root.num(root.touchpadScroll)} } } })`;
            if (root.touchpad !== "")
                lua += ` hl.device({ name = "${root.touchpad}", sensitivity = ${root.num(root.touchpadSpeed)} })`;
            Quickshell.execDetached(["hyprctl", "dispatch", `(function() ${lua} end)`]);
        }
    }

    onMouseSpeedChanged: apply()
    onTouchpadSpeedChanged: apply()
    onMouseAccelChanged: apply()
    onMouseScrollChanged: apply()
    onTouchpadScrollChanged: apply()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded")
                root.apply();
        }
    }
}
