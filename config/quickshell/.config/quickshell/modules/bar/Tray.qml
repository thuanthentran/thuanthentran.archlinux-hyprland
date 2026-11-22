// System tray: left click activates, middle click secondary action, right click menu.
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.widgets

Row {
    spacing: 2

    Repeater {
        model: SystemTray.items

        BarButton {
            id: btn

            required property SystemTrayItem modelData

            padding: 6
            tooltip: modelData.tooltipTitle || modelData.title

            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 16
                source: btn.modelData.icon
            }

            onClicked: m => {
                if (m.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (m.button === Qt.MiddleButton) {
                    modelData.secondaryActivate();
                } else if (modelData.hasMenu) {
                    const p = btn.mapToItem(null, 0, btn.height + 6);
                    modelData.display(QsWindow.window, p.x, p.y);
                }
            }
            onWheel: w => modelData.scroll(w.angleDelta.y / 120, false)
        }
    }
}
