// Window overview (Mission Control / Task View): every window of the current workspace
// as a live thumbnail in a grid, minimized ones in a strip at the bottom. Opened by a
// Super tap and Super+Tab (Hyprland binds -> GlobalShortcut "quickshell:overview").
//
// The real windows are never scaled: a full-screen overlay below the bar paints the
// wallpaper and live screencopies of the windows. At progress 0 each thumbnail sits
// exactly where its window is, at 1 it is in the grid, so opening and closing animate
// windows between their place and the grid. The 3-finger gesture will drive `progress`
// directly later on.
//
// Order is most recently used first (Hyprland's focusHistoryID), frozen while open.
// Keys: arrows / Tab move, Enter picks, Esc closes. Click picks, middle click closes a
// window, click on empty space goes back to the current window.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import qs

PanelWindow {
    id: root

    property bool open: false
    property real progress: 0             // 0: windows in place, 1: grid
    property var tiles: []                // see build()
    property var minimized: []
    property int selected: 0              // index into tiles
    property string target: ""            // window to focus once closed ("" = none)
    property var mon: null                // monitor JSON from hyprctl, frozen while open
    property bool ready: false            // every thumbnail has its first frame

    readonly property int gap: 28
    readonly property int labelH: 26
    readonly property int pad: 56
    readonly property int stripH: minimized.length > 0 ? 120 : 0
    readonly property string home: Quickshell.env("HOME")

    function toggle() {
        if (open)
            close("");
        else
            show();
    }

    function show() {
        if (open || fetch.running)
            return;
        fetch.running = true;
    }

    // Close, focusing `addr` (a window address) or nothing
    function close(addr) {
        if (!open)
            return;
        open = false;
        target = addr;
        // Hyprland ignores a focus change while this layer holds the keyboard, so wait
        // for the keyboard focus to be given back (keyboardFocus follows `open`)
        if (addr)
            refocus.restart();
        anim.to = 0;
        anim.restart();
    }

    function focusWindow(addr) {
        Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
        Hyprland.dispatch(`hl.dsp.window.bring_to_top()`);
    }

    function toplevelFor(addr) {
        const a = addr.replace(/^0x/, "");
        return Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === a) ?? null;
    }

    // Uniform-height rows; tries every row count and keeps the one with the most
    // thumbnail area. Windows never grow past their real size.
    function grid(items, W, H) {
        const n = items.length;
        let best = null;
        for (let r = 1; r <= n; r++) {
            const per = Math.ceil(n / r);
            const rows = [];
            for (let i = 0; i < n; i += per)
                rows.push(items.slice(i, i + per));
            let t = (H - (rows.length - 1) * gap) / rows.length - labelH;
            for (const row of rows)
                t = Math.min(t, (W - (row.length - 1) * gap) / row.reduce((s, it) => s + it.w / it.h, 0));
            if (t <= 0)
                continue;
            const area = items.reduce((s, it) => {
                const h = Math.min(t, it.h);
                return s + h * h * it.w / it.h;
            }, 0);
            if (!best || area > best.area)
                best = { area, rows, t };
        }
        if (!best)
            return [];
        const out = [];
        const rowH = best.t + labelH;
        let y = (H - best.rows.length * rowH - (best.rows.length - 1) * gap) / 2;
        for (const row of best.rows) {
            const sizes = row.map(it => {
                const h = Math.min(best.t, it.h);
                return [h * it.w / it.h, h];
            });
            let x = (W - sizes.reduce((s, z) => s + z[0], 0) - (row.length - 1) * gap) / 2;
            for (const [w, h] of sizes) {
                out.push({ x, y: y + labelH + (best.t - h) / 2, w, h });
                x += w + gap;
            }
            y += rowH + gap;
        }
        return out;
    }

    function build(clients, monitors) {
        mon = monitors.find(m => m.focused) ?? monitors[0];
        const ws = mon.activeWorkspace.id;
        const ox = mon.x, oy = mon.y + Theme.barHeight;     // overlay origin (below the bar)
        const mru = (a, b) => a.focusHistoryID - b.focusHistoryID;
        const info = c => ({
            addr: c.address,
            title: c.title,
            appId: c["class"],
            // real place, relative to the overlay, including the hyprbars title bar
            // (not part of the screencopy, so the tile draws its own)
            bar: c.fullscreen ? 0 : 30,
            x: c.at[0] - ox, y: c.at[1] - oy - (c.fullscreen ? 0 : 30), w: c.size[0], h: c.size[1] + (c.fullscreen ? 0 : 30)
        });
        const wins = clients.filter(c => c.mapped && c.workspace.id === ws).sort(mru).map(info);
        const mins = clients.filter(c => c.workspace.name === "special:magic").sort(mru).map(info);

        const W = mon.width / mon.scale, H = mon.height / mon.scale - Theme.barHeight;
        const g = grid(wins, W - 2 * pad, H - 2 * pad - (mins.length > 0 ? 120 : 0));
        tiles = wins.map((w, i) => Object.assign(w, { gx: g[i].x + pad, gy: g[i].y + pad, gw: g[i].w, gh: g[i].h }));

        // Minimized: a strip of small thumbnails, sliding up from below the screen
        const sh = 80;
        const sizes = mins.map(m => [Math.min(sh * m.w / m.h, 200), sh]);
        let x = (W - sizes.reduce((s, z) => s + z[0], 0) - (mins.length - 1) * 20) / 2;
        minimized = mins.map((m, i) => {
            const o = Object.assign(m, { gx: x, gy: H - pad / 2 - sh, gw: sizes[i][0], gh: sh });
            o.x = x;
            o.y = H + 40;
            o.w = sizes[i][0];
            o.h = sh;
            x += sizes[i][0] + 20;
            return o;
        });

        // Windows the grid rearranges: the active one is selected
        selected = 0;
        target = "";
        progress = 0;
        ready = false;
        open = true;
        readyTimeout.restart();
        Qt.callLater(checkReady);
    }

    // Start flying only once the thumbnails have a picture: until then the overlay is
    // invisible, otherwise the wallpaper would cover the real windows before their
    // thumbnails show up, and the current window would seem to fade out.
    function checkReady() {
        if (!open || ready)
            return;
        for (let i = 0; i < tileRep.count; i++)
            if (!tileRep.itemAt(i)?.painted)
                return;
        go();
    }
    function go() {
        if (!open || ready)
            return;
        ready = true;
        anim.to = 1;
        anim.restart();
    }

    // Arrow keys: nearest tile in that direction, by grid position
    function move(dx, dy) {
        const cur = tiles[selected];
        if (!cur)
            return;
        const cx = cur.gx + cur.gw / 2, cy = cur.gy + cur.gh / 2;
        let best = -1, bestD = Infinity;
        tiles.forEach((t, i) => {
            const tx = t.gx + t.gw / 2 - cx, ty = t.gy + t.gh / 2 - cy;
            const along = tx * dx + ty * dy;
            if (i === selected || along <= 1)
                return;
            const d = along + 3 * Math.abs(tx * dy + ty * dx);
            if (d < bestD) {
                bestD = d;
                best = i;
            }
        });
        if (best >= 0)
            selected = best;
    }

    Timer {
        id: readyTimeout
        interval: 150
        onTriggered: root.go()
    }
    Timer {
        id: refocus
        interval: 40
        onTriggered: root.focusWindow(root.target)
    }

    Process {
        id: fetch
        command: ["sh", "-c", "hyprctl -j clients; echo '\x1e'; hyprctl -j monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [c, m] = text.split("\x1e");
                try {
                    root.build(JSON.parse(c), JSON.parse(m));
                } catch (e) {
                    console.warn("overview: " + e);
                }
            }
        }
    }

    NumberAnimation {
        id: anim
        target: root
        property: "progress"
        duration: 260
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.progress === 0 && !root.open) {
                root.tiles = [];
                root.minimized = [];
            }
        }
    }

    // Window removed while open (closed with middle click, or quit): drop its tile
    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            if (!root.open)
                return;
            const alive = t => root.toplevelFor(t.addr) !== null;
            if (!root.tiles.every(alive) || !root.minimized.every(alive))
                fetch.running = true;
        }
    }

    GlobalShortcut {
        appid: "quickshell"
        name: "overview"
        description: "Show all windows"
        onPressed: root.toggle()
    }
    // Super tap: a release bind, and Hyprland's `global` passes a release as `released`
    GlobalShortcut {
        appid: "quickshell"
        name: "overview-tap"
        description: "Show all windows (Super tap)"
        onReleased: root.toggle()
    }

    screen: Quickshell.screens.find(s => s.name === (mon?.name ?? Hyprland.focusedMonitor?.name)) ?? Quickshell.screens[0]
    visible: open || progress > 0
    // Kept invisible (not hidden, so screencopies run) until the thumbnails are ready
    contentItem.opacity: ready || !open ? 1 : 0
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Wallpaper (hides the real windows), then a dim that grows with progress
    Image {
        anchors.fill: parent
        anchors.topMargin: -Theme.barHeight
        source: "file://" + root.home + "/.config/hypr/wallpapers/default.png"
        fillMode: Image.PreserveAspectCrop
        // opaque from the start: the thumbnails cover their windows exactly, so nothing
        // fades, the windows just start moving
        asynchronous: false
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4 * root.progress
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape)
                root.close(root.tiles[0]?.addr ?? "");
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                root.close(root.tiles[root.selected]?.addr ?? "");
            else if (e.key === Qt.Key_Left)
                root.move(-1, 0);
            else if (e.key === Qt.Key_Right)
                root.move(1, 0);
            else if (e.key === Qt.Key_Up)
                root.move(0, -1);
            else if (e.key === Qt.Key_Down)
                root.move(0, 1);
            else if (e.key === Qt.Key_Tab)
                root.selected = (root.selected + 1) % Math.max(1, root.tiles.length);
            else if (e.key === Qt.Key_Backtab)
                root.selected = (root.selected - 1 + root.tiles.length) % Math.max(1, root.tiles.length);
            else
                return;
            e.accepted = true;
        }

        // Click on empty space: back to the window that was active
        MouseArea {
            anchors.fill: parent
            onClicked: root.close(root.tiles[0]?.addr ?? "")
        }

        Repeater {
            model: root.minimized

            WindowTile {
                required property var modelData
                required property int index
                info: modelData
                progress: root.progress
                dim: true
                onPicked: {
                    root.open = false;
                    anim.to = 0;
                    anim.restart();
                    Quickshell.execDetached([root.home + "/.config/hypr/scripts/minimize.sh", "restore", modelData.addr]);
                }
                onCloseRequested: root.toplevelFor(modelData.addr)?.wayland?.close()
            }
        }

        Repeater {
            id: tileRep
            model: root.tiles

            WindowTile {
                required property var modelData
                required property int index
                info: modelData
                progress: root.progress
                selected: root.open && index === root.selected
                // most recently used on top; the picked one above everything while closing
                z: modelData.addr === root.target ? 1000 : root.tiles.length - index
                onHoveredChanged: if (hovered && root.open) root.selected = index
                onPaintedChanged: root.checkReady()
                onPicked: root.close(modelData.addr)
                onCloseRequested: root.toplevelFor(modelData.addr)?.wayland?.close()
            }
        }
    }

    component WindowTile: Item {
        id: tile

        property var info
        property real progress
        property bool selected: false
        property bool dim: false
        readonly property bool hovered: mouse.containsMouse || closeMouse.containsMouse
        readonly property bool painted: view.hasContent
        readonly property var toplevel: root.toplevelFor(info.addr)
        signal picked
        signal closeRequested

        x: info.x + (info.gx - info.x) * progress
        y: info.y + (info.gy - info.y) * progress
        width: info.w + (info.gw - info.w) * progress
        height: info.h + (info.gh - info.h) * progress

        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: 12
            color: "transparent"
            border.width: 3
            border.color: Qt.rgba(1, 1, 1, 0.85)
            visible: tile.selected
        }

        ClippingRectangle {
            id: frame
            readonly property real s: tile.height / tile.info.h    // scale vs the real window
            anchors.fill: parent
            radius: 12 * s                                         // Hyprland's rounding
            color: Qt.rgba(1, 1, 1, 0.08)
            opacity: tile.dim ? 0.75 : 1

            // Stand-in for the hyprbars title bar (same colour, title, buttons)
            Rectangle {
                id: titleBar
                width: parent.width
                height: tile.info.bar * frame.s
                visible: tile.info.bar > 0
                color: Qt.rgba(43 / 255, 43 / 255, 46 / 255, 0.94)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 120 * frame.s
                    horizontalAlignment: Text.AlignHCenter
                    text: tile.info.title
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Math.max(1, 11 * 1.33 * frame.s)
                    elide: Text.ElideRight
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * frame.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * frame.s
                    layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: ["#ff5f57", "#28c840", "#febc2e"]
                        Rectangle {
                            required property string modelData
                            width: 14 * frame.s
                            height: width
                            radius: width / 2
                            color: modelData
                        }
                    }
                }
            }

            ScreencopyView {
                id: view
                y: titleBar.height
                width: parent.width
                height: parent.height - titleBar.height
                captureSource: tile.toplevel?.wayland ?? null
                live: true
                constraintSize: Qt.size(tile.info.gw * 1.5, tile.info.gh * 1.5)
            }
            // No picture (yet, or minimized windows Hyprland doesn't render): app icon
            IconImage {
                anchors.centerIn: parent
                visible: !view.hasContent
                implicitSize: Math.min(64, parent.height * 0.6)
                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(tile.info.appId)?.icon ?? tile.info.appId, "application-x-executable")
            }
        }

        // Icon + title above the thumbnail, only in the grid
        Row {
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, parent.width)
            spacing: 6
            opacity: Math.max(0, tile.progress * 2 - 1)
            visible: !tile.dim

            IconImage {
                implicitSize: 18
                source: Quickshell.iconPath(DesktopEntries.heuristicLookup(tile.info.appId)?.icon ?? tile.info.appId, "application-x-executable")
            }
            Text {
                width: Math.min(implicitWidth, tile.width - 24)
                text: tile.info.title
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => m.button === Qt.MiddleButton ? tile.closeRequested() : tile.picked()
        }

        // Close button on hover
        Rectangle {
            visible: tile.hovered && tile.progress === 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            width: 26
            height: 26
            radius: 13
            color: closeMouse.containsMouse ? Theme.red : Qt.rgba(40 / 255, 40 / 255, 44 / 255, 0.95)
            border.color: Theme.popupBorder

            Text {
                anchors.centerIn: parent
                text: "\u{F0156}"
                color: Theme.fg
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: tile.closeRequested()
            }
        }
    }
}
