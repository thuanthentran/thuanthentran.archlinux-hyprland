// Which apps get opened (`import qs.services`, then AppUsage.record(entry) when launching
// one): how many times each, for the launcher's "Frequent" row, and the last ones, for the
// overview's "recent" row. Kept in Quickshell.statePath("launcher.json").
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property var counts: data.counts            // desktop id -> times opened
    readonly property var recentIds: data.recent         // most recent first

    function record(entry) {
        if (!entry)
            return;
        const c = Object.assign({}, data.counts);
        c[entry.id] = (c[entry.id] ?? 0) + 1;
        data.counts = c;
        data.recent = [entry.id].concat(data.recent.filter(id => id !== entry.id)).slice(0, 12);
    }

    // DesktopEntry objects, newest first (apps since uninstalled are skipped)
    function recent(n) {
        return recentIds.map(id => DesktopEntries.byId(id)).filter(e => e && !e.noDisplay).slice(0, n);
    }

    FileView {
        path: Quickshell.statePath("launcher.json")
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: data
            property var counts: ({})
            property var recent: []
        }
    }
}
