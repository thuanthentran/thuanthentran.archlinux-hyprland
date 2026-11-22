// One icon per window, in WindowOrder (the order the 3-finger film and the overview use).
// Click focuses it; a minimized window (in special:magic) is restored instead, middle
// click closes. Drag an icon sideways to reorder.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.widgets

Row {
    id: row

    spacing: 2

    Repeater {
        id: rep
        model: WindowOrder.model

        BarButton {
            id: btn

            required property string addr
            readonly property HyprlandToplevel modelData: WindowOrder.toplevel(addr)
            readonly property string appId: modelData?.wayland?.appId ?? ""
            readonly property bool minimized: modelData?.workspace?.name === "special:magic"

            padding: 5
            visible: modelData !== null
            tooltip: drag.active ? "" : (modelData?.title ?? "")
            highlighted: (modelData?.activated ?? false) || drag.active
            opacity: minimized ? 0.5 : 1

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(btn.appId)?.icon ?? btn.appId, "application-x-executable")
            }

            onClicked: m => {
                if (m.button === Qt.MiddleButton)
                    modelData?.wayland?.close();
                else if (minimized)
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/scripts/minimize.sh", "restore", btn.addr]);
                else
                    modelData?.wayland?.activate();
            }

            // Reorder: while dragging, the window takes the place of the button under the
            // pointer (the row reflows, so the dragged button stays under it)
            DragHandler {
                id: drag
                target: null
                yAxis.enabled: false
                onCentroidChanged: {
                    if (!active)
                        return;
                    const x = btn.mapToItem(row, centroid.position.x, 0).x;
                    for (let i = 0; i < rep.count; i++) {
                        const it = rep.itemAt(i);
                        if (it && it !== btn && x >= it.x && x < it.x + it.width) {
                            WindowOrder.moveTo(btn.addr, it.addr);
                            break;
                        }
                    }
                }
            }
        }
    }
}
