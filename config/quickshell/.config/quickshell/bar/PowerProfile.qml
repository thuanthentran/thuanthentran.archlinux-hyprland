// Power profile (power-profiles-daemon), only in the expanded quick settings.
// Click cycles saver -> balanced -> performance.
import QtQuick
import Quickshell.Services.UPower
import qs
import qs.widgets

Reveal {
    id: root

    readonly property var profiles: PowerProfiles.hasPerformanceProfile
        ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
        : [PowerProfile.PowerSaver, PowerProfile.Balanced]
    readonly property int current: PowerProfiles.profile

    shown: BarState.expanded

    BarButton {
        text: root.current === PowerProfile.PowerSaver ? "\u{F032A}"
            : root.current === PowerProfile.Performance ? "\u{F14DE}"
            : "\u{F05D1}"

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.current === PowerProfile.PowerSaver ? "Saver"
                : root.current === PowerProfile.Performance ? "Performance"
                : "Balanced"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        onClicked: {
            const i = root.profiles.indexOf(root.current);
            PowerProfiles.profile = root.profiles[(i + 1) % root.profiles.length];
        }
    }
}
