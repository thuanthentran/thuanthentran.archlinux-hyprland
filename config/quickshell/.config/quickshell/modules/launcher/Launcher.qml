// App launcher (replaces nwg-drawer): a full-screen overlay in the Launchpad spirit, in
// the white + black + green look. Search on top, the most used apps in a row, then every
// app A-Z. Typing filters; Enter opens the selected app (the first match), arrows / Tab
// move, Esc clears the search and then closes, a click on empty space closes.
// Opened by the bar's Apps button, Super+R (GlobalShortcut quickshell:launcher) and
// `qs ipc call launcher toggle`. How often each app was opened is kept in
// Quickshell.statePath("launcher.json") for the "Frequent" row.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs.config
import qs.services
import qs.widgets

PanelWindow {
    id: root

    property bool open: false
    property real shown: 0                // 0 -> 1 while opening, back while closing
    property string query: ""
    property int selected: 0

    function toggle() {
        if (open)
            close();
        else
            show();
    }
    function show() {
        BarState.popupRequested("");      // bar panels hold the keyboard
        BarState.overviewDismiss();
        screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        search.clear();
        selected = 0;
        grid.positionViewAtBeginning();
        open = true;
        anim.to = 1;
        anim.duration = 260;
        anim.restart();
        search.takeFocus();
    }
    function close() {
        if (!open)
            return;
        open = false;
        anim.to = 0;
        anim.duration = 180;
        anim.restart();
    }
    function typeText(t) {
        search.setText(t);
    }
    function launch(entry) {
        if (!entry)
            return;
        const c = Object.assign({}, usage.counts);
        c[entry.id] = (c[entry.id] ?? 0) + 1;
        usage.counts = c;
        close();
        entry.execute();
    }

    visible: open || shown > 0
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-launcher"     // blur, no Hyprland fade (layer rules)
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    NumberAnimation {
        id: anim
        target: root
        property: "shown"
        easing.type: Easing.OutCubic
    }

    // --- apps -------------------------------------------------------------------------

    FileView {
        path: Quickshell.statePath("launcher.json")
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    // Best matches first: name starts with the text, then a word of it does, then it
    // appears anywhere (generic name, comment, categories, id count less)
    function score(e, q) {
        const name = e.name.toLowerCase();
        if (name.startsWith(q))
            return 0;
        if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 1;
        if (name.includes(q))
            return 2;
        const rest = [e.genericName, e.comment, e.id, ...(e.categories ?? [])].join(" ").toLowerCase();
        return rest.includes(q) ? 3 : -1;
    }
    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (!q)
            return all;
        return all.map(e => ({ e, s: score(e, q) }))
            .filter(x => x.s >= 0)
            .sort((a, b) => a.s - b.s)
            .map(x => x.e);
    }
    readonly property var frequent: query ? [] : all
        .filter(e => (usage.counts[e.id] ?? 0) > 0)
        .sort((a, b) => usage.counts[b.id] - usage.counts[a.id])
        .slice(0, 7)

    onResultsChanged: selected = 0

    function key(e) {
        const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));
        const n = results.length;
        if (e.key === Qt.Key_Escape) {
            if (query || search.engaged)
                search.clear();
            else
                close();
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            launch(results[selected]);
        } else if (e.key === Qt.Key_Down) {
            selected = Math.min(n - 1, selected + cols);
        } else if (e.key === Qt.Key_Up) {
            selected = Math.max(0, selected - cols);
        } else if ((e.key === Qt.Key_Right && !query) || e.key === Qt.Key_Tab) {
            selected = Math.min(n - 1, selected + 1);
        } else if ((e.key === Qt.Key_Left && !query) || e.key === Qt.Key_Backtab) {
            selected = Math.max(0, selected - 1);
        } else {
            return;
        }
        grid.positionViewAtIndex(selected, GridView.Contain);
        e.accepted = true;
    }

    // --- look -------------------------------------------------------------------------

    // Backdrop (Hyprland blurs what is behind it); a click on it closes
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(6 / 255, 7 / 255, 6 / 255, 0.8)
        opacity: root.shown

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: body
        anchors.fill: parent
        anchors.topMargin: 56
        anchors.bottomMargin: 40
        opacity: root.shown
        scale: 0.96 + 0.04 * root.shown

        SearchField {
            id: search
            anchors.horizontalCenter: parent.horizontalCenter
            minWidth: 420
            implicitHeight: 40
            hint: "Search apps"
            onKey: e => root.key(e)
            onTextChanged: root.query = text
        }

        // Most used apps (only while not searching)
        Column {
            id: freq
            anchors.top: search.bottom
            anchors.topMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            visible: root.frequent.length > 0
            height: visible ? implicitHeight : 0

            Text {
                text: "Frequent"
                color: Theme.fgDim
                font.family: Theme.displayFont
                font.pixelSize: 13
                leftPadding: 8
            }
            Row {
                spacing: 0
                Repeater {
                    model: root.frequent
                    AppCell {
                        required property var modelData
                        entry: modelData
                        onActivated: root.launch(modelData)
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.popupBorder
            }
        }

        GridView {
            id: grid
            anchors.top: freq.bottom
            anchors.topMargin: 16
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            cellWidth: 128
            cellHeight: 120
            width: Math.min(parent.width - 160, cellWidth * 9)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.results

            delegate: AppCell {
                required property var modelData
                required property int index
                entry: modelData
                current: index === root.selected
                onActivated: root.launch(modelData)
                onHoveredChanged: if (hovered) root.selected = index
            }

            Text {
                anchors.centerIn: parent
                visible: root.results.length === 0
                text: "No apps match"
                color: Theme.fgOff
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
            }
        }
    }

    component AppCell: Item {
        id: cell

        property var entry
        property bool current: false
        readonly property bool hovered: area.containsMouse
        signal activated

        width: 128
        height: 120

        Rectangle {
            anchors.fill: parent
            anchors.margins: 6
            radius: 16
            color: cell.current || cell.hovered ? Theme.hover : "transparent"
            border.color: cell.current ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        IconImage {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            implicitSize: 56
            source: Quickshell.iconPath(cell.entry?.icon ?? "", "application-x-executable")
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 82
            width: parent.width - 20
            horizontalAlignment: Text.AlignHCenter
            text: cell.entry?.name ?? ""
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: cell.activated()
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "launcher"
        description: "Open / close the app launcher"
        onPressed: root.toggle()
    }

    // The bar's Apps button
    Connections {
        target: BarState
        function onLauncherToggle() {
            root.toggle();
        }
    }
}
