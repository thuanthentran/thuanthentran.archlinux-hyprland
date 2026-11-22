// The one order of windows, shared by the bar's taskbar, the 3-finger film, the overview
// grid and Alt+Tab (`import qs`, then WindowOrder.toplevels / .rank() / .moveTo()).
//
// Stable on purpose: focusing a window does not move it (most-recently-used order did, so
// the film was rebuilt after every switch and swiping right never had anything to show).
// New windows go to the end, closed ones drop out; dragging a taskbar button or an
// overview tile reorders. Kept in memory only: after a Quickshell restart it starts again
// from Hyprland's window list.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property var order: []                // window addresses, without 0x

    // Hyprland's toplevels in this order
    readonly property var toplevels: {
        const by = {};
        for (const t of Hyprland.toplevels.values)
            by[key(t.address)] = t;
        return order.map(a => by[a]).filter(t => t);
    }

    function key(addr) {
        return (addr ?? "").replace(/^0x/, "");
    }

    // The order as a ListModel (role `addr`), changed with move / insert / remove so the
    // views' delegates survive a reorder (a drag in progress isn't cut off)
    property ListModel model: ListModel {}

    function toplevel(addr) {
        const a = key(addr);
        return Hyprland.toplevels.values.find(t => key(t.address) === a) ?? null;
    }

    onOrderChanged: {
        const m = model;
        order.forEach((a, i) => {
            let j = -1;
            for (let k = i; k < m.count; k++)
                if (m.get(k).addr === a) {
                    j = k;
                    break;
                }
            if (j < 0)
                m.insert(i, { addr: a });
            else if (j !== i)
                m.move(j, i, 1);
        });
        if (m.count > order.length)
            m.remove(order.length, m.count - order.length);
    }

    // Position of a window in the order (for sorting); unknown ones last
    function rank(addr) {
        const i = order.indexOf(key(addr));
        return i < 0 ? 1e9 : i;
    }

    // Put window `addr` where window `target` is now (before it when moving left, after it
    // when moving right), like dragging an item over another one
    function moveTo(addr, target) {
        const a = key(addr), b = key(target);
        const from = order.indexOf(a), to = order.indexOf(b);
        if (from < 0 || to < 0 || from === to)
            return;
        const o = order.slice();
        o.splice(from, 1);
        o.splice(to, 0, a);
        order = o;
    }

    function sync() {
        const live = Hyprland.toplevels.values.map(t => key(t.address));
        const kept = order.filter(a => live.includes(a));
        const added = live.filter(a => !kept.includes(a));
        const next = kept.concat(added);
        if (next.join() !== order.join())
            order = next;
    }

    Connections {
        target: Hyprland.toplevels
        function onValuesChanged() {
            root.sync();
        }
    }
    Component.onCompleted: sync()
}
