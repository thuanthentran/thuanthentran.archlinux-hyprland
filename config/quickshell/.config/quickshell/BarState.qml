// Shared bar state (`import qs`, then `BarState.expanded`).
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Quick settings cluster opened in place on the bar (click it; leaving it closes it)
    property bool expanded: false
    // Number of sliders being dragged; the cluster stays open while > 0
    property int held: 0
}
