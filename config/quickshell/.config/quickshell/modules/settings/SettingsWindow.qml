// The Settings window: a normal window (Hyprland manages it like an app) that edits the
// Settings singleton. Opened from the power menu or `qs ipc call settings open`.
// Sections are added here as settings grow (appearance, gestures...).
import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.widgets

FloatingWindow {
    id: root

    title: "Settings"
    visible: false
    implicitWidth: 560
    implicitHeight: 500
    color: Theme.popupBg

    // Closing it from the title bar destroys the surface but leaves `visible` true, so
    // turn it off first to get a new one
    function open() {
        visible = false;
        visible = true;
    }

    // One labelled slider; `from` / `to` map onto the slider, `step` rounds the value
    component SliderRow: Item {
        id: row

        property string label: ""
        property string hint: ""
        property real value: 0
        property real from: 0
        property real to: 1
        property real step: 0.05
        property string unit: ""
        signal changed(real value)

        width: parent ? parent.width : 0
        implicitHeight: 52

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - slider.width - valueText.width - 32
            spacing: 2

            Text {
                text: row.label
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
            Text {
                visible: row.hint !== ""
                width: parent.width
                text: row.hint
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        BarSlider {
            id: slider
            anchors.right: valueText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 200
            value: (row.value - row.from) / (row.to - row.from)
            onMoved: v => {
                const x = row.from + v * (row.to - row.from);
                row.changed(Math.round(x / row.step) * row.step);
            }
        }
        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            horizontalAlignment: Text.AlignRight
            text: row.value.toFixed(2) + row.unit
            color: Theme.fgDim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.features: { "tnum": 1 }
        }
    }

    component Heading: Text {
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: 18
        font.weight: Font.DemiBold
        bottomPadding: 8
    }

    component SwitchRow: Item {
        id: srow

        property string label: ""
        property string hint: ""
        property bool checked: false
        signal toggled

        width: parent ? parent.width : 0
        implicitHeight: 52

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: srow.label
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
            Text {
                visible: srow.hint !== ""
                text: srow.hint
                color: Theme.fgDim
                font.family: Theme.font
                font.pixelSize: 11
            }
        }
        Switch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: srow.checked
            onToggled: srow.toggled()
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 48
        clip: true

        Column {
            id: col
            x: 28
            y: 24
            width: parent.width - 56
            spacing: 4

            Heading {
                text: "Top bar"
            }
            SwitchRow {
                label: "Auto-hide"
                hint: "Hidden until the pointer touches the top edge of the screen"
                checked: Settings.barAutoHide
                onToggled: Settings.barAutoHide = !Settings.barAutoHide
            }

            Heading {
                text: "Mouse & touchpad"
                topPadding: 20
            }

            SliderRow {
                label: "Mouse speed"
                value: Settings.mouseSpeed
                from: -1
                to: 1
                onChanged: v => Settings.mouseSpeed = v
            }
            SwitchRow {
                label: "Mouse acceleration"
                hint: "Off: the pointer moves the same distance however fast the mouse goes"
                checked: Settings.mouseAccel
                onToggled: Settings.mouseAccel = !Settings.mouseAccel
            }
            SliderRow {
                label: "Mouse scroll speed"
                value: Settings.mouseScroll
                from: 0.2
                to: 2
                unit: "×"
                onChanged: v => Settings.mouseScroll = v
            }
            SliderRow {
                label: "Touchpad speed"
                value: Settings.touchpadSpeed
                from: -1
                to: 1
                onChanged: v => Settings.touchpadSpeed = v
            }
            SliderRow {
                label: "Touchpad scroll speed"
                hint: "Two-finger scrolling"
                value: Settings.touchpadScroll
                from: 0.1
                to: 1.5
                unit: "×"
                onChanged: v => Settings.touchpadScroll = v
            }
        }
    }
}
