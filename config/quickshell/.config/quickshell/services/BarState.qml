// Shared bar state (`import qs`, then `BarState.expanded`).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Quick settings cluster opened in place on the bar (click it; leaving it closes it)
    property bool expanded: false
    // Number of sliders being dragged; the cluster stays open while > 0
    property int held: 0
    // Set by `qs ipc call bar popup <name>` (sound, wifi, bluetooth) to open that drop-down
    signal popupRequested(string name)
    // The Apps button asks the overview to close before opening the drawer
    signal overviewDismiss()
    // The Apps button: open / close the launcher
    signal launcherToggle()
    // The launcher is on screen (opening, open or still fading out); the overview waits
    // for it to be gone before flying in, so the two animations don't run on top of each other
    property bool launcherVisible: false
}
