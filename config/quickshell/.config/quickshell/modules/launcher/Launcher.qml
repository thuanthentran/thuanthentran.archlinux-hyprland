// App launcher (replaces nwg-drawer): a full-screen overlay in the Launchpad spirit, in
// the white + black + green look. Search on top, the most used apps in a row, then every
// app A-Z. Typing filters; Enter opens the selected app (the first match), arrows / Tab
// move, Esc clears the search and then closes, a click on empty space closes.
// Opened by the bar's Apps button, Super+Space / Super+R (GlobalShortcut
// quickshell:launcher) and `qs ipc call launcher toggle`. How often each app was opened
// comes from AppUsage (the "Frequent" row).
//
// It is a light layer over everything, never left behind: opening an app, or anything else
// taking over (the overview, Alt+Tab, a 3-finger swipe: they all send
// BarState.popupRequested("")), closes it at once.
//
// Searching animates like the overview's app row: the grid's model is changed by insert /
// move / remove only (syncModel), new cards rise, slide in sideways (from the right while
// typing, from the left while deleting) and fade in one after another, dropped cards fade
// out the other way and the rest glide to their new cells.
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
        search.clear();                   // while closed: the full list comes back unanimated
        selected = 0;
        grid.positionViewAtBeginning();
        open = true;
        anim.to = 1;
        anim.duration = 420;
        anim.restart();
        search.takeFocus();
    }
    // `quick`: something else took over, get out of its way
    function close(quick) {
        if (!open)
            return;
        open = false;
        anim.to = 0;
        anim.duration = quick ? 120 : 220;
        anim.restart();
    }
    function typeText(t) {
        search.setText(t);
    }
    function launch(entry) {
        if (!entry)
            return;
        AppUsage.record(entry);
        close();
        entry.execute();
    }

    visible: open || shown > 0
    onVisibleChanged: BarState.launcherVisible = visible
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
    readonly property var frequent: all
        .filter(e => (AppUsage.counts[e.id] ?? 0) > 0)
        .sort((a, b) => AppUsage.counts[b.id] - AppUsage.counts[a.id])
        .slice(0, 7)

    onResultsChanged: {
        selected = 0;
        syncModel();
    }
    Component.onCompleted: syncModel()

    // The grid's model, kept equal to `results` with insert / move / remove only, so cards
    // that stay are not rebuilt and GridView can animate the changes
    ListModel {
        id: appModel
    }
    property int slideDir: 1              // 1: the text grew (typing), -1: it shrank
    function syncModel() {
        const ids = results.map(e => e.id);
        const keep = new Set(ids);
        for (let k = appModel.count - 1; k >= 0; k--)
            if (!keep.has(appModel.get(k).eid))
                appModel.remove(k);
        ids.forEach((id, i) => {
            let j = -1;
            for (let k = i; k < appModel.count; k++)
                if (appModel.get(k).eid === id) {
                    j = k;
                    break;
                }
            if (j < 0)
                appModel.insert(i, { eid: id });
            else if (j !== i)
                appModel.move(j, i, 1);
        });
    }

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
            onTextChanged: {
                root.slideDir = text.length >= root.query.length ? 1 : -1;
                root.query = text;
            }
        }

        // Most used apps (only while not searching)
        Column {
            id: freq
            anchors.top: search.bottom
            anchors.topMargin: 28
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            // folds away while searching (and comes back when the text is gone)
            readonly property bool shown: !root.query && root.frequent.length > 0
            height: shown ? implicitHeight : 0
            opacity: shown ? 1 : 0
            clip: true
            Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

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
            model: appModel

            delegate: AppCell {
                id: gcell
                required property string eid
                required property int index
                entry: DesktopEntries.byId(eid)
                current: index === root.selected && !leaving
                onActivated: root.launch(entry)
                onHoveredChanged: if (hovered && !leaving) root.selected = index
            }

            // Only while open and searching: the list filled or refilled while closed (and
            // cards made by scrolling) just appear. Same timing as the overview's app row:
            // in 410 ms, 30 ms apart (the first 8), out in 175 ms.
            add: Transition {
                enabled: root.open
                SequentialAnimation {
                    PropertyAction { property: "t"; value: 0 }
                    PropertyAction { property: "dir"; value: root.slideDir }
                    PauseAnimation { duration: Math.min(Math.max(0, ViewTransition.index - (ViewTransition.targetIndexes[0] ?? 0)), 8) * 30 }
                    NumberAnimation { property: "t"; to: 1; duration: 410; easing.type: Easing.OutQuint }
                }
            }
            remove: Transition {
                enabled: root.open
                SequentialAnimation {
                    PropertyAction { property: "leaving"; value: true }
                    PropertyAction { property: "dir"; value: -root.slideDir }
                    PropertyAction { property: "z"; value: -1 }
                    NumberAnimation { property: "t"; to: 0; duration: 175; easing.type: Easing.InOutCubic }
                }
            }
            displaced: Transition {
                enabled: root.open
                NumberAnimation { properties: "x,y"; duration: 380; easing.type: Easing.OutQuint }
            }
            move: Transition {
                enabled: root.open
                NumberAnimation { properties: "x,y"; duration: 380; easing.type: Easing.OutQuint }
            }

            Text {
                anchors.centerIn: parent
                opacity: root.results.length === 0 ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }
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
        // Entrance / exit, driven by the grid's transitions: 0 -> 1 rises the card 64 px,
        // slides it 40 px sideways (`dir`), grows it from 94 % and fades it in
        property real t: 1
        property int dir: 1
        property bool leaving: false

        width: 128
        height: 120

        Item {
            id: card
            anchors.fill: parent
            opacity: cell.t
            scale: 0.94 + 0.06 * cell.t
            transform: Translate {
                x: cell.dir * 40 * (1 - cell.t)
                y: (cell.leaving ? 10 : 64) * (1 - cell.t)
            }

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

    Connections {
        target: BarState
        // The bar's Apps button
        function onLauncherToggle() {
            root.toggle();
        }
        // The overview, Alt+Tab, a swipe or a bar panel is taking over
        function onPopupRequested(name) {
            root.close(true);
        }
    }
}
