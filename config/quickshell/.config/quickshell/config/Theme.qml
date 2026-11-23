// Colours, fonts and sizes shared by every widget (`import qs.config`, then `Theme.fg`).
// White + black + green, clean and minimal: neutral near-black surfaces, white text, green
// only as the accent (switch on, today, focus, peaks, the active item); hover and selection
// are white tints, never colour. The colours come from palette.json next to this file, the
// one palette of the desktop: edit it there (it applies live here) and run
// install/palette.py to carry it into Hyprland, the greeter, rofi, kitty and hyprlock.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    FileView {
        path: Quickshell.shellPath("config/palette.json")
        blockLoading: true                // the right colours from the first frame
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: p
            // defaults only matter if the file is missing
            property color accent: "#4ade80"
            property color accentText: "#07130b"
            property color bar: "#0a0b0a"
            property color surface: "#111211"
            property color fg: "#f4f5f4"
            property color button: "#4a4d4a"
            property color red: "#ff6b6b"
            property color yellow: "#facc15"
        }
    }
    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    readonly property color accent: p.accent
    readonly property color accentText: p.accentText          // text / icons on an accent fill

    readonly property color barBg: alpha(p.bar, 0.62)
    readonly property color popupBg: alpha(p.surface, 0.96)
    readonly property color popupBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color card: Qt.rgba(1, 1, 1, 0.04)       // a block inside a panel
    readonly property color field: Qt.rgba(1, 1, 1, 0.06)      // text inputs
    readonly property color track: Qt.rgba(1, 1, 1, 0.16)      // slider tracks, switch off

    readonly property color fg: p.fg
    readonly property color fgDim: alpha(p.fg, 0.6)
    readonly property color fgOff: alpha(p.fg, 0.42)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color active: Qt.rgba(1, 1, 1, 0.18)

    readonly property color red: p.red
    readonly property color redHover: alpha(p.red, 0.7)
    readonly property color yellow: p.yellow

    // Graphs: CPU in the accent, RAM in white
    readonly property color cpu: accent
    readonly property color ram: fg

    // hyprbars title bar, as set in hyprland.lua (the overview draws a stand-in)
    readonly property color titleBar: alpha(p.surface, 0.94)
    readonly property color titleButton: p.button

    // UI text and big display text (clock, headings), picked in Settings
    readonly property string font: Settings.font
    readonly property string displayFont: Settings.displayFont
    readonly property string iconFont: "CaskaydiaCove Nerd Font"
    readonly property int fontSize: 12      // Lexend runs large: 12 reads like 13 in most fonts
    readonly property int iconSize: 15
    readonly property int barHeight: 26
    // Space the bar takes from the windows (none when it auto-hides)
    readonly property int barReserved: Settings.barAutoHide ? 0 : barHeight
}
