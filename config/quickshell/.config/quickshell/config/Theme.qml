// Colours, fonts and sizes shared by every widget (`import qs.config`, then `Theme.fg`).
// White + black + green, clean and minimal: neutral near-black surfaces, white text, green
// only as the accent (switch on, today, focus, peaks, the active item); hover and selection
// are white tints, never colour. Keep other apps in step when changing it (see CLAUDE.md:
// hyprbars and borders in hyprland.lua, rofi spotlight.rasi, kitty, gtk css).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color accent: "#4ade80"
    readonly property color accentText: "#07130b"              // text / icons on an accent fill

    readonly property color barBg: Qt.rgba(10 / 255, 11 / 255, 10 / 255, 0.62)
    readonly property color popupBg: Qt.rgba(17 / 255, 18 / 255, 17 / 255, 0.96)
    readonly property color popupBorder: Qt.rgba(1, 1, 1, 0.08)
    readonly property color card: Qt.rgba(1, 1, 1, 0.04)       // a block inside a panel
    readonly property color field: Qt.rgba(1, 1, 1, 0.06)      // text inputs
    readonly property color track: Qt.rgba(1, 1, 1, 0.16)      // slider tracks, switch off

    readonly property color fg: "#f4f5f4"
    readonly property color fgDim: Qt.rgba(244 / 255, 245 / 255, 244 / 255, 0.6)
    readonly property color fgOff: Qt.rgba(244 / 255, 245 / 255, 244 / 255, 0.42)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color active: Qt.rgba(1, 1, 1, 0.18)

    readonly property color red: "#ff6b6b"
    readonly property color redHover: Qt.rgba(1, 107 / 255, 107 / 255, 0.7)
    readonly property color yellow: "#facc15"

    // Graphs: CPU in the accent, RAM in white
    readonly property color cpu: accent
    readonly property color ram: fg

    // hyprbars title bar, as set in hyprland.lua (the overview draws a stand-in)
    readonly property color titleBar: Qt.rgba(17 / 255, 18 / 255, 17 / 255, 0.94)
    readonly property color titleButton: "#4a4d4a"

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
