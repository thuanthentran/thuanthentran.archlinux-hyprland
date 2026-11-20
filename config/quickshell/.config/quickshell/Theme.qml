// Colours, fonts and sizes shared by every widget (`import qs`, then `Theme.fg`).
// Translucent dark bar, flat, soft hover pills (the look Waybar had before).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color barBg: Qt.rgba(24 / 255, 24 / 255, 27 / 255, 0.55)
    readonly property color fg: "#f2f2f5"
    readonly property color fgDim: Qt.rgba(242 / 255, 242 / 255, 245 / 255, 0.6)
    readonly property color fgOff: Qt.rgba(242 / 255, 242 / 255, 245 / 255, 0.5)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.14)
    readonly property color active: Qt.rgba(1, 1, 1, 0.22)
    readonly property color red: "#ff5f57"
    readonly property color redHover: Qt.rgba(1, 95 / 255, 87 / 255, 0.7)
    readonly property color yellow: "#ffbd2e"
    readonly property color cpu: "#0a84ff"
    readonly property color ram: "#30d158"
    readonly property color popupBg: Qt.rgba(40 / 255, 40 / 255, 44 / 255, 0.95)
    readonly property color popupBorder: Qt.rgba(1, 1, 1, 0.12)

    readonly property string font: "IBM Plex Sans"
    readonly property string iconFont: "CaskaydiaCove Nerd Font"
    readonly property int fontSize: 13
    readonly property int iconSize: 15
    readonly property int barHeight: 32
}
