// Drop-down mixer: output device, master volume, and one slider per app playing to it.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import qs.services
import qs.widgets

DropPopup {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // Apps = whatever is linked into the default output
    readonly property var streams: links.linkGroups.map(g => g.source).filter(n => n && n.isStream && n.audio)

    title: "Sound"
    contentWidth: 340

    PwNodeLinkTracker {
        id: links
        node: root.sink
    }
    PwObjectTracker {
        objects: [root.sink].concat(root.streams)
    }

    SectionLabel {
        text: "Output"
    }
    Repeater {
        model: root.outputs

        MenuRow {
            required property PwNode modelData
            // HDMI / DP outputs have long card names ("AD107 ... Pro 9"); their nick is "HDMI 3"
            readonly property bool hdmi: /hdmi|displayport/i.test(modelData.nickname + modelData.name)
            icon: hdmi ? "\u{F0379}" : /head/i.test(modelData.description + modelData.name) ? "\u{F02CB}" : "\u{F04C3}"
            text: hdmi && modelData.nickname ? modelData.nickname : modelData.description || modelData.nickname || modelData.name
            active: modelData === root.sink
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }
    VolumeRow {
        node: root.sink
    }

    SectionLabel {
        visible: root.streams.length > 0
        text: "Apps"
    }
    Repeater {
        model: root.streams

        VolumeRow {
            required property PwNode modelData
            node: modelData
            label: modelData.properties["application.name"] || modelData.description || modelData.name
            appIcon: modelData.properties["application.icon-name"] || modelData.properties["application.process.binary"] || ""
        }
    }

    MenuRow {
        icon: "\u{F0493}"
        text: "Sound settings…"
        dim: true
        onClicked: {
            root.visible = false;
            Quickshell.execDetached(["pavucontrol"]);
        }
    }
}
