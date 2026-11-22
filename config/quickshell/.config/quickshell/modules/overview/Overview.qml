// Window overview (Mission Control / Task View), Alt+Tab switcher and the 3-finger
// "home bar" gesture, all one overlay.
//
// Modes:
//  - grid: every window of the current workspace as a live thumbnail in a grid,
//    minimized ones in a row below. Super tap / Super+Tab (Hyprland binds ->
//    GlobalShortcut "quickshell:overview" / "overview-tap"), or a 3-finger swipe up
//    past `gridAt`. A 3-finger swipe down closes it.
//  - strip: Alt+Tab / Alt+Shift+Tab, the keyboard version of the film: the next /
//    previous window in the order slides to the middle (wrapping at the ends). A quick
//    Alt+Tab switches without showing anything; holding Alt a moment or pressing Tab
//    again shows the strip; releasing Alt picks (a timer in hyprland.lua watches Alt and
//    sends "quickshell:alttab-release").
//  - film: the 3-finger gesture (Touchpad.qml). Every window becomes one frame of a film
//    strip, at its real size and place, one screen apart, in WindowOrder. The film has two
//    ends (no wrapping round; pulling past an end only stretches); the fingers pull it
//    sideways. Moving up shrinks the frames toward the strip layout so more of them show;
//    up to `gridAt` the film spreads into the grid, frame by frame, in film order; going
//    back down before letting go gathers it into the film again. Letting go picks the
//    frame in the middle, after coasting on (one window at most) with the swipe's speed.
//
// The real windows are never scaled: the overlay paints the wallpaper and live
// screencopies. At progress 0 each tile sits exactly over its window, at 1 it is where
// the mode puts it, so opening / closing animate windows between the two.
//
// Order: WindowOrder (the bar's taskbar order, changed by dragging a taskbar button or a
// grid tile), so the film doesn't change between swipes. The film / strip start at the
// active window: left of it are the windows before it, right the ones after.
// Keys: arrows / Tab move (strip: left / right), Enter picks, Esc closes; in the grid,
// typing searches (windows that don't match fade, matching apps show under the search
// pill; Enter opens the selected window or else the first app). Click picks, middle click
// closes a window, click on empty space goes back to the current window.
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

    // Gesture tuning, in millimetres on the touchpad (the TUF's is 126 x 73)
    readonly property real deadMm: 3       // the first mm each way are ignored (finger jitter,
                                           // a sideways swipe drifting a bit up)
    readonly property real liftFull: 18    // moving up this far shrinks the film to the strip
    readonly property real gridAt: 32      // ... and this far turns it into the grid
    readonly property real pageMm: 80      // sideways per window, film at full size
    readonly property real cardMm: 45      // ... and shrunk to the strip
    readonly property real dismissMm: 12   // swipe down this far closes the grid
    readonly property int settleMs: 1000   // film: letting go, the picked window zooms back to its place
    readonly property real zoomTo: 0.6     // fingers level, sideways: the frames zoom out to this size
    readonly property real zoomMm: 10      // ... fully once this far sideways
    readonly property real zoomRate: 14    // zoom-out speed (1/s; 14: about 0.2 s), quick so it's
                                           // done before a fast swipe brings the next window in
    readonly property real coast: 0.22     // letting go: s of the swipe's speed to coast on
    readonly property int titleBar: 20     // hyprbars bar_height in hyprland.lua
    readonly property real pageGap: 80     // film at full size: space between screens (px)

    property bool open: false
    property real progress: 0             // 0: windows in place, 1: where the mode puts them
    property var tiles: []                // see build()
    property var minimized: []
    property var gridRects: []            // grid place of each tile, by tile index
    property int selected: 0              // index into tiles
    property string target: ""            // window to focus once closed ("" = none)
    property var mon: null                // monitor JSON from hyprctl, frozen while open
    property real areaW: 0                // overlay size, from the monitor
    property real areaH: 0
    property bool ready: false            // every thumbnail has its first frame
    property string mode: "grid"          // "grid", "strip" or "film"
    property bool loaded: false           // tiles hold fresh data for this opening
    property bool session: false          // Alt is held after an Alt+Tab
    property bool commitPending: false    // Alt released before the window list arrived
    property int pos: 0                   // strip: index of the picked card
    property int taps: 0                  // strip: Tab presses this time
    property int cur: 0                   // index of the active window in tiles
    property var slots: []                // grid: tile indices in display order
    property string query: ""             // grid: typed search
    property real scroll: 0               // strip / film: which card is in the middle
    property real slot: 0                 // strip: distance between card centres
    property real lift: 0                 // film: how far the fingers went up, past deadMm
    property real rawLift: 0              // film: the same, dead zone included
    property real rawPan: 0               // film: sideways so far, for the dead zone
    property bool dragging: false         // film: fingers on the touchpad drive scroll / lift
    property string gesture: ""           // "", "film", "grid" (spread, waiting for END), "dismiss"
    property real pendingDx: 0            // film: sideways movement before the list arrived
    property real dismissDy: 0
    property real vel: 0                  // film: scroll speed, cards / s
    property real lastT: 0

    // What is drawn: scroll / lift eased toward their targets once per frame (144 Hz here),
    // so the motion is smooth even though the touchpad reports at its own uneven pace
    property real vScroll: 0
    property real vLift: 0
    property real hz: 0                   // film: 0..1, how far the frames are zoomed out (to zoomTo)
    property real vHz: 0
    property bool settling: false         // film let go: only the picked window goes back to its place

    readonly property real shrink: mode === "film" ? Math.min(1, vLift / liftFull) : 1
    readonly property real mmPerCard: pageMm + (cardMm - pageMm) * shrink
    readonly property real labels: mode === "film" ? progress * shrink : progress
    // settling: the last 35 % of the zoom back fades the wallpaper (and the other frames) out
    readonly property real settleFade: settling ? Math.min(1, progress / 0.35) : 1

    readonly property int gap: 28
    readonly property int labelH: 26
    readonly property int pad: 56
    readonly property string home: Quickshell.env("HOME")

    // Benchmark: `qs ipc call overview bench` swipes by itself for 2 s (there and back, up
    // and down) and logs frame intervals to `qs log`. Ticks of the animation driver, not
    // presented frames: for those, run qs with
    // QT_LOGGING_RULES=qt.scenegraph.time.renderloop=true
    property var benchFrames: []
    property int benchTick: 0
    function bench() {
        if (open || gesture)
            return;
        benchFrames = [];
        benchTick = 0;
        gestureBegin();
        benchTimer.start();
    }
    Timer {
        id: benchTimer
        interval: 7
        repeat: true
        onTriggered: {
            const t = root.benchTick++;
            const back = t >= 143;
            root.gestureUpdate(back ? 0.6 : -0.6, back ? 0.15 : -0.15);
            if (t >= 286) {
                stop();
                root.gestureEnd(false);
                const f = root.benchFrames.slice(5).sort((a, b) => a - b);
                const avg = f.reduce((a, b) => a + b, 0) / f.length;
                console.log(`bench: ${f.length} frames, avg ${(avg * 1000).toFixed(1)} ms (${(1 / avg).toFixed(0)} fps), p95 ${(f[Math.floor(f.length * 0.95)] * 1000).toFixed(1)} ms, max ${(f[f.length - 1] * 1000).toFixed(1)} ms`);
            }
        }
    }

    FrameAnimation {
        running: root.visible && root.ready && root.mode !== "grid"
        onTriggered: {
            if (benchTimer.running)
                root.benchFrames.push(frameTime);
            const k = 1 - Math.exp(-frameTime * 32);       // ~30 ms to catch up
            const ds = root.scroll - root.vScroll, dl = root.lift - root.vLift;
            root.vScroll = Math.abs(ds) < 0.0005 ? root.scroll : root.vScroll + ds * k;
            root.vLift = Math.abs(dl) < 0.01 ? root.lift : root.vLift + dl * k;
            // the zoom-out isn't under the fingers' control: eased at its own pace (zoomRate)
            // (quick out, slow back in: letting go zooms back over about settleMs)
            const dz = root.hz - root.vHz;
            const kz = 1 - Math.exp(-frameTime * (dz > 0 ? root.zoomRate : 3000 / root.settleMs));
            root.vHz = Math.abs(dz) < 0.002 ? root.hz : root.vHz + dz * kz;
        }
    }

    Behavior on scroll {
        enabled: root.open && !root.dragging
        NumberAnimation {
            duration: root.mode === "film" ? root.settleMs : 260
            easing.type: Easing.OutCubic
        }
    }
    Behavior on lift {
        enabled: !root.dragging
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutCubic
        }
    }

    function toggle() {
        if (open)
            close("");
        else
            show();
    }

    // A bar panel holds the keyboard, and while it does Hyprland ignores focus changes:
    // close them all when the overview, Alt+Tab or a swipe starts
    function closePanels() {
        BarState.popupRequested("");
    }

    function show() {
        if (open || fetch.running || session || gesture)
            return;
        closePanels();
        mode = "grid";
        loaded = false;
        fetch.running = true;
    }

    // Alt+Tab (dir 1) / Alt+Shift+Tab (dir -1)
    function altTab(dir) {
        if (open && mode === "grid") {
            const n = Math.max(1, tiles.length);
            selected = (selected + dir + n) % n;
            return;
        }
        if (gesture)
            return;
        if (!session) {
            if (open)                     // still closing from the last pick
                return;
            closePanels();
            session = true;
            commitPending = false;
            mode = "strip";
            loaded = false;
            pos = dir;                    // wrapped once the list is in (build)
            taps = 1;
            hold.restart();
            fetch.running = true;
            return;
        }
        taps++;
        if (!loaded) {
            pos += dir;
            return;
        }
        pos = wrap(pos + dir);
        scroll = pos;
        selected = pos;
        present();                        // pressing Tab again shows the strip at once
    }

    function altReleased() {
        if (!session)
            return;
        session = false;
        hold.stop();
        if (!loaded)
            commitPending = true;
        else
            commit();
    }

    // Focus the window in the middle of the strip
    function commit() {
        commitPending = false;
        const addr = tiles[wrap(pos)]?.addr ?? "";
        if (open) {
            close(addr);
        } else {
            if (addr)
                focusWindow(addr);
            reset();
        }
    }

    // --- 3-finger gesture -------------------------------------------------------------

    function gestureBegin() {
        if (session)
            return;
        if (open && mode === "grid") {
            gesture = "dismiss";
            dismissDy = 0;
            return;
        }
        if (open || fetch.running)
            return;
        closePanels();
        gesture = "film";
        mode = "film";
        dragging = true;
        lift = 0;
        rawLift = 0;
        rawPan = 0;
        scroll = 0;
        vScroll = 0;
        vLift = 0;
        hz = 0;
        vHz = 0;
        pos = 0;
        vel = 0;
        lastT = Date.now();
        pendingDx = 0;
        loaded = false;
        fetch.running = true;
    }

    function gestureUpdate(dx, dy) {
        if (gesture === "dismiss") {
            dismissDy += dy;
            return;
        }
        if (gesture === "grid") {         // spread, fingers still down: back down undoes it
            rawLift = Math.max(0, rawLift - dy);
            lift = Math.max(0, rawLift - deadMm);
            if (lift < gridAt - 4)
                gather();
            return;
        }
        if (gesture !== "film")
            return;
        rawLift = Math.max(0, rawLift - dy);
        lift = Math.max(0, rawLift - deadMm);
        // sideways dead zone: only the part past deadMm moves the film
        const before = rawPan;
        rawPan += dx;
        const eff = p => Math.sign(p) * Math.max(0, Math.abs(p) - deadMm);
        dx = eff(rawPan) - eff(before);
        // Sideways with the fingers level: the frames zoom out (to zoomTo); stays
        // zoomed out for the rest of the swipe
        if (rawLift < deadMm)
            hz = Math.max(hz, Math.min(1, Math.abs(eff(rawPan)) / zoomMm));
        if (!loaded) {
            pendingDx += dx;
            return;
        }
        drag(dx);
        if (lift >= gridAt)
            spread();
    }

    function drag(dx) {
        const n = tiles.length;
        let ds = -dx / mmPerCard;
        // Past either end of the film (0 .. n-1): a rubber band, at most 0.3 of a window
        const over = v => v < 0 ? -v : v > n - 1 ? v - (n - 1) : 0;
        if (over(scroll + ds) > over(scroll))
            ds *= 0.3 * Math.max(0, 1 - over(scroll) / 0.3);
        scroll += ds;
        const now = Date.now(), dt = Math.max(1, now - lastT);
        lastT = now;
        vel = dt > 100 ? 0 : vel * 0.6 + 0.4 * (ds * 1000 / dt);
    }

    function gestureEnd(cancelled) {
        const g = gesture;
        gesture = "";
        if (g === "dismiss") {
            if (dismissDy > dismissMm && !cancelled)
                close(tiles[cur]?.addr ?? "");
            return;
        }
        dragging = false;
        if (g !== "film")
            return;                       // "grid": stays open
        if (!loaded)
            return;                       // build() sees the gesture is over and gives up
        // Pick the frame in the middle once it has coasted on (not if the fingers stopped)
        if (Date.now() - lastT > 80)
            vel = 0;
        const n = tiles.length;
        // coasting moves on one window at most past the one in the middle
        const base = Math.round(scroll);
        let t = Math.round(scroll + vel * coast);
        t = Math.max(base - 1, Math.min(base + 1, t));
        t = Math.max(0, Math.min(n - 1, t));
        scroll = t;
        lift = 0;
        hz = 0;
        const addr = tiles[wrap(t)]?.addr ?? "";
        if (open) {
            // The others don't fly back: they ride on with the film and off screen, and the
            // real windows show up in place as the wallpaper fades out at the end
            settling = true;
            close(addr);
        } else {
            if (addr && t !== cur)
                focusWindow(addr);
            reset();
        }
    }

    // Lifted high enough: the film spreads into the grid, frame by frame in film order
    function spread() {
        gesture = "grid";
        anim.stop();
        const c = Math.max(0, Math.min(tiles.length - 1, Math.round(scroll)));
        const from = [];
        for (let i = 0; i < tileRep.count; i++) {
            const it = tileRep.itemAt(i);
            from.push({ x: it.x, y: it.y, w: it.width, h: it.height });
        }
        progress = 1;
        ready = true;
        gridRects = gridFor();
        selected = c;
        mode = "grid";
        const n = tiles.length;
        for (let i = 0; i < tileRep.count; i++)
            tileRep.itemAt(i).flyFrom(from[i], i * 30);
        for (let i = 0; i < minRep.count; i++) {
            const m = minimized[i];
            minRep.itemAt(i).flyFrom({ x: m.x, y: m.y, w: m.w, h: m.h }, (n + i) * 30);
        }
    }

    // Back down before letting go: the grid gathers into the film again, last tile first,
    // and the fingers drive it as before
    function gather() {
        gesture = "film";
        const c = selected;
        const n = tiles.length;
        const from = [];
        for (let i = 0; i < tileRep.count; i++) {
            const it = tileRep.itemAt(i);
            from.push({ x: it.x, y: it.y, w: it.width, h: it.height });
        }
        scroll = c;
        vScroll = c;
        vLift = lift;
        mode = "film";
        lastT = Date.now();
        vel = 0;
        for (let i = 0; i < tileRep.count; i++)
            tileRep.itemAt(i).flyFrom(from[i], (n - 1 - i) * 20);
    }

    // ----------------------------------------------------------------------------------

    function wrap(i) {
        const n = Math.max(1, tiles.length);
        return ((i % n) + n) % n;
    }

    // Strip / film: where card i sits for the current scroll and shrink; d is its distance
    // from the middle (cards in order, no wrapping). At shrink 0 the cards are the windows
    // themselves, one screen apart; at 1 they are the strip's cards.
    function filmRect(t, i) {
        const d = i - vScroll;
        const s = shrink;
        // the window itself, one screen per frame, zoomed out around its centre by vHz
        const z = 1 - (1 - zoomTo) * (mode === "film" ? vHz : 0);
        const cx = t.x + t.w / 2 + d * (areaW + pageGap) * z, cy = t.y + t.h / 2;
        const page = { x: cx - t.w * z / 2, y: cy - t.h * z / 2, w: t.w * z, h: t.h * z };
        const card = { x: areaW / 2 + d * slot - t.sw / 2, y: (areaH - t.sh + labelH) / 2, w: t.sw, h: t.sh };
        return {
            x: page.x + (card.x - page.x) * s,
            y: page.y + (card.y - page.y) * s,
            w: page.w + (card.w - page.w) * s,
            h: page.h + (card.h - page.h) * s
        };
    }

    // Close, focusing `addr` (a window address) or nothing
    function close(addr) {
        if (!open)
            return;
        session = false;
        hold.stop();
        open = false;
        target = addr;
        // Hyprland ignores a focus change while this layer holds the keyboard, so wait
        // for the keyboard focus to be given back (keyboardFocus follows `open`)
        if (addr)
            refocus.restart();
        anim.to = 0;
        anim.restart();
    }

    function reset() {
        settling = false;
        tiles = [];
        minimized = [];
        gridRects = [];
        loaded = false;
        commitPending = false;
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

    // Grid places by tile index, laid out in `slots` order (film order, or as dragged)
    function gridFor() {
        const g = grid(slots.map(i => tiles[i]), areaW - 2 * pad, areaH - 2 * pad - (minimized.length > 0 ? 120 : 0));
        const rects = [];
        slots.forEach((i, k) => rects[i] = { x: g[k].x + pad, y: g[k].y + pad, w: g[k].w, h: g[k].h });
        return rects;
    }

    // Dragging tile i in the grid: over another tile, it takes that tile's place (in
    // WindowOrder too, so the bar and the film follow); the others glide to their new spots
    function dragOver(i, p) {
        let j = -1;
        gridRects.forEach((r, k) => {
            if (k !== i && p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h)
                j = k;
        });
        if (j < 0)
            return;
        const s = slots.slice();
        s.splice(s.indexOf(i), 1);
        s.splice(slots.indexOf(j), 0, i);
        WindowOrder.moveTo(tiles[i].addr, tiles[j].addr);
        for (let k = 0; k < tileRep.count; k++) {
            const it = tileRep.itemAt(k);
            if (k !== i)
                it.flyFrom({ x: it.x, y: it.y, w: it.width, h: it.height }, 0);
        }
        slots = s;
        gridRects = gridFor();
    }

    // --- search (grid): type to filter windows; apps that match can be launched ----------

    function matches(text) {
        const words = query.toLowerCase().split(/\s+/).filter(w => w);
        const t = (text ?? "").toLowerCase();
        return words.every(w => t.includes(w));
    }
    function tileMatches(t) {
        return !query || (!!t && matches(t.title + " " + t.appId));
    }
    readonly property var apps: query === "" ? [] : DesktopEntries.applications.values
        .filter(e => !e.noDisplay && matches(e.name + " " + e.genericName + " " + (e.keywords ?? []).join(" ") + " " + e.id))
        .slice(0, 6)

    onQueryChanged: {
        // `query` is also cleared from code (Esc, a new opening): keep the field in step
        if (searchField.text !== query)
            searchField.setText(query);
        if (!query || tileMatches(tiles[selected] ?? {}))
            return;
        for (const i of slots)
            if (tileMatches(tiles[i])) {
                selected = i;
                return;
            }
    }

    function launch(entry) {
        if (!entry)
            return;
        entry.execute();
        close("");
    }

    // Enter: the selected window if it matches, else the first app
    function pick() {
        const t = tiles[selected];
        if (t && tileMatches(t))
            close(t.addr);
        else
            launch(apps[0]);
    }

    function build(clients, monitors) {
        if (mode === "film" && gesture !== "film" && !open) {
            reset();                      // the swipe ended before the list came
            return;
        }
        mon = monitors.find(m => m.focused) ?? monitors[0];
        const ws = mon.activeWorkspace.id;
        const ox = mon.x, oy = mon.y + Theme.barReserved;     // overlay origin (below the bar)
        const mru = (a, b) => a.focusHistoryID - b.focusHistoryID;
        const byOrder = (a, b) => WindowOrder.rank(a.address) - WindowOrder.rank(b.address);
        const info = c => ({
            addr: c.address,
            mru: c.focusHistoryID,
            title: c.title,
            appId: c["class"],
            // real place, relative to the overlay, including the hyprbars title bar
            // (not part of the screencopy, so the tile draws its own)
            bar: c.fullscreen ? 0 : root.titleBar,
            x: c.at[0] - ox, y: c.at[1] - oy - (c.fullscreen ? 0 : root.titleBar), w: c.size[0], h: c.size[1] + (c.fullscreen ? 0 : root.titleBar)
        });
        const wins = clients.filter(c => c.mapped && c.workspace.id === ws).sort(byOrder).map(info);
        const mins = clients.filter(c => c.workspace.name === "special:magic").sort(mru).map(info);

        const W = mon.width / mon.scale, H = mon.height / mon.scale - Theme.barReserved;
        areaW = W;
        areaH = H;
        // Strip cards: same height, at most 55 % of the screen wide
        const ch = H * 0.6, maxW = W * 0.55;
        tiles = wins.map(w => {
            const sw = Math.min(ch * w.w / w.h, maxW, w.w);
            return Object.assign(w, { sw, sh: sw * w.h / w.w });
        });
        slot = Math.max(...tiles.map(t => t.sw), 0) + 60;
        // the active window: where the film / strip starts and what Esc goes back to
        let c = 0;
        tiles.forEach((t, i) => { if (t.mru < tiles[c].mru) c = i; });

        // Minimized: a row of small thumbnails, sliding up from below the screen
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

        if (open) {                       // refreshed while open (a window went away)
            slots = tiles.map((t, i) => i);
            gridRects = gridFor();
            selected = Math.min(selected, Math.max(0, tiles.length - 1));
            if (tiles.length === 0)
                close("");
            return;
        }
        cur = c;
        slots = tiles.map((t, i) => i);
        gridRects = gridFor();
        loaded = true;
        target = "";
        query = "";
        if (mode === "grid") {
            selected = cur;
            present();
        } else if (mode === "film") {
            if (tiles.length === 0) {
                gesture = "";
                dragging = false;
                reset();
                return;
            }
            selected = cur;
            scroll = cur;
            vScroll = cur;
            drag(pendingDx);
            present();
        } else {
            pos = wrap(cur + pos);
            scroll = pos;
            vScroll = pos;
            selected = pos;
            if (tiles.length < 2)
                altReleased();             // nothing to switch to
            else if (commitPending)
                commit();
            else if (!hold.running || taps > 1)
                present();
        }
    }

    // Show the overlay; the windows start moving once their thumbnails are ready
    function present() {
        if (open)
            return;
        settling = false;
        progress = 0;
        ready = false;
        open = true;
        readyTimeout.restart();
        Qt.callLater(checkReady);
    }

    // Start moving only once the thumbnails have a picture: until then the overlay is
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
        // The film is there at once: the current frame is exactly over its window and the
        // others start off screen, so nothing is seen flying into place
        if (mode === "film") {
            anim.stop();
            progress = 1;
            return;
        }
        anim.to = 1;
        anim.restart();
    }

    // Grid keys that aren't text editing (the search field takes the rest: typing,
    // Backspace, Ctrl+A / C / V / X, Shift+arrows...). Left / Right move between tiles
    // only while nothing is typed, else they move the text cursor. Returns true if used.
    function gridKey(e) {
        const n = Math.max(1, tiles.length);
        if (e.key === Qt.Key_Escape && (query || searchField.engaged))
            searchField.clear();
        else if (e.key === Qt.Key_Escape)
            close(tiles[cur]?.addr ?? "");
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_Space && !query))
            pick();
        else if (e.key === Qt.Key_Left && !query)
            move(-1, 0);
        else if (e.key === Qt.Key_Right && !query)
            move(1, 0);
        else if (e.key === Qt.Key_Up)
            move(0, -1);
        else if (e.key === Qt.Key_Down)
            move(0, 1);
        else if (e.key === Qt.Key_Tab)
            selected = (selected + 1) % n;
        else if (e.key === Qt.Key_Backtab)
            selected = (selected - 1 + n) % n;
        else
            return false;
        e.accepted = true;
        return true;
    }

    // The keyboard goes to the search field in the grid, to the overlay otherwise
    function placeFocus() {
        if (open && mode === "grid")
            searchField.takeFocus();
        else
            content.forceActiveFocus();
    }
    onModeChanged: placeFocus()
    onOpenChanged: {
        searchField.clear();
        placeFocus();
    }

    // Arrow keys: nearest tile in that direction, by grid position
    function move(dx, dy) {
        const cur = gridRects[selected];
        if (!cur)
            return;
        const cx = cur.x + cur.w / 2, cy = cur.y + cur.h / 2;
        let best = -1, bestD = Infinity;
        gridRects.forEach((t, i) => {
            const tx = t.x + t.w / 2 - cx, ty = t.y + t.h / 2 - cy;
            const along = tx * dx + ty * dy;
            if (i === selected || along <= 1 || !tileMatches(tiles[i]))
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

    Connections {
        target: Touchpad
        function onBegin(fingers) {
            if (fingers === 3)
                root.gestureBegin();
        }
        function onUpdate(fingers, dx, dy) {
            if (fingers === 3)
                root.gestureUpdate(dx, dy);
        }
        function onEnd(fingers, cancelled) {
            if (fingers === 3)
                root.gestureEnd(cancelled);
        }
    }

    // How long Alt must be held after Alt+Tab before the strip shows
    Timer {
        id: hold
        interval: 160
        onTriggered: if (root.session && root.loaded) root.present()
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
        duration: root.mode === "film" ? root.settleMs : 260
        easing.type: Easing.OutCubic
        onFinished: {
            if (root.progress === 0 && !root.open)
                root.reset();
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
    GlobalShortcut {
        appid: "quickshell"
        name: "alttab"
        description: "Switch to the next window"
        onPressed: root.altTab(1)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-back"
        description: "Switch to the previous window"
        onPressed: root.altTab(-1)
    }
    GlobalShortcut {
        appid: "quickshell"
        name: "alttab-release"
        description: "Alt released (picks the window in the Alt+Tab strip)"
        // sent from a Hyprland timer, which may pass it as either
        onPressed: root.altReleased()
        onReleased: root.altReleased()
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
    margins.top: Theme.barReserved
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overview"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Wallpaper (hides the real windows), then a dim
    Image {
        anchors.fill: parent
        anchors.topMargin: -Theme.barReserved
        source: "file://" + root.home + "/.config/hypr/wallpapers/default.png"
        opacity: root.settleFade
        fillMode: Image.PreserveAspectCrop
        // opaque from the start: the thumbnails cover their windows exactly, so nothing
        // fades, the windows just start moving
        asynchronous: false
    }
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.4 * root.labels
    }

    Item {
        id: content
        anchors.fill: parent
        focus: true

        // Backup for the Alt watcher, while the strip has the keyboard
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Alt)
                root.altReleased();
        }
        Keys.onPressed: e => {
            if (root.mode !== "grid") {
                if (e.key === Qt.Key_Escape)
                    root.close(root.tiles[root.cur]?.addr ?? "");
                else if (root.mode === "film")
                    return;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    root.commit();
                else if (e.key === Qt.Key_Left)
                    root.altTab(-1);
                else if (e.key === Qt.Key_Right)
                    root.altTab(1);
                else
                    return;
                e.accepted = true;
                return;
            }
            // grid: the search field normally has the keyboard; if not, send it there
            if (root.gridKey(e))
                return;
            searchField.takeFocus();
            if (e.text && e.text.length === 1 && e.text >= " " && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                searchField.insert(e.text);
                e.accepted = true;
            }
        }

        // Click on empty space: back to the window that was active
        MouseArea {
            anchors.fill: parent
            onClicked: if (root.mode !== "film") root.close(root.tiles[root.cur]?.addr ?? "")
        }

        Repeater {
            id: minRep
            model: root.minimized

            WindowTile {
                ov: root
                required property var modelData
                required property int index
                info: modelData
                progress: root.progress
                goal: ({ x: modelData.gx, y: modelData.gy, w: modelData.gw, h: modelData.gh })
                visible: root.mode === "grid"
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
                ov: root
                required property var modelData
                required property int index
                info: modelData
                progress: root.settling && modelData.addr !== root.target ? 1 : root.progress
                fade: root.settling && modelData.addr !== root.target ? root.settleFade : 1
                goal: root.mode === "grid" ? (root.gridRects[index] ?? { x: 0, y: 0, w: 1, h: 1 })
                    : root.filmRect(modelData, index)
                selected: root.open && index === root.selected && root.mode === "grid" && root.tileMatches(modelData)
                faded: root.mode === "grid" && !root.tileMatches(modelData)
                draggable: root.mode === "grid" && root.open && !root.gesture
                // most recently used on top; the picked / dragged one above everything
                z: modelData.addr === root.target || dragging ? 1000 : root.tiles.length - modelData.mru
                onDragMoved: p => root.dragOver(index, p)
                onHoveredChanged: if (hovered && root.open && root.mode === "grid") root.selected = index
                onPaintedChanged: root.checkReady()
                onPicked: if (root.mode !== "film") root.close(modelData.addr)
                onCloseRequested: root.toplevelFor(modelData.addr)?.wayland?.close()
            }
        }
    }

    // Search: a pill at the top while typing (or a hint once the grid is up), apps that
    // match in a row under it
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        z: 2000
        spacing: 8
        visible: root.mode === "grid" && root.open
        opacity: Math.max(0, root.labels * 2 - 1)

        // typing anywhere in the grid lands here (it has the keyboard, see placeFocus)
        SearchField {
            id: searchField
            anchors.horizontalCenter: parent.horizontalCenter
            hint: "Type to search windows and apps"
            onKey: e => root.gridKey(e)
            onTextChanged: root.query = text
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: root.apps.length > 0

            Repeater {
                model: root.apps

                Rectangle {
                    id: app
                    required property var modelData
                    required property int index
                    // the first app is what Enter opens when no window matches
                    readonly property bool first: index === 0 && !root.tileMatches(root.tiles[root.selected] ?? {})
                    width: 92
                    height: 86
                    radius: 10
                    color: appMouse.containsMouse ? Theme.active : first ? Theme.hover : Theme.popupBg
                    border.color: first ? Qt.rgba(1, 1, 1, 0.6) : Theme.popupBorder

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 12
                        spacing: 6
                        IconImage {
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitSize: 40
                            source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: app.modelData.name
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                    }
                    MouseArea {
                        id: appMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.launch(app.modelData)
                    }
                }
            }
        }
    }

    // The bar's Apps button: get out of the way of the app drawer
    Connections {
        target: BarState
        function onOverviewDismiss() {
            root.close("");
        }
    }
}
