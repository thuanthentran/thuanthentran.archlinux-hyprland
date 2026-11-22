// Synced lyrics from LRCLIB (https://lrclib.net) for Players.active, fetched only when
// asked (the player panel calls request() when it opens), cached on disk by track.
// Sends the cleaned-up title / artist (or the query typed in the panel) to lrclib.net;
// nothing else. `import qs`, then Lyrics.lines / .current / .status.
//
// A search keeps up to 6 candidates (synced ones first, closest in length to the track
// first); the panel can step through them, nudge the timing, or search with its own
// words. The choice, the offset and the query are remembered per track.
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var lines: []            // [{ t: seconds, text }]
    property string plain: ""         // unsynced lyrics when that's all there is
    property string status: ""        // "", "loading", "ok", "plain", "none", "error"
    property string forTrack: ""
    property var cache: ({})          // track key -> entry (see entry())
    property var entry: null          // the current track's entry

    readonly property var candidates: entry?.candidates ?? []
    readonly property int pick: entry?.pick ?? 0
    readonly property real offset: entry?.offset ?? 0
    readonly property string query: entry?.query ?? ""

    // Index of the line being sung (-1 before the first)
    readonly property int current: {
        const pos = Players.position + 0.3 + offset;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].t <= pos; k++)
            i = k;
        return i;
    }

    // "Song - Artist | Live at ... (Official MV) ft. X" -> "Song Artist"
    function autoQuery() {
        const p = Players.active;
        let t = (p?.trackTitle ?? "").replace(/\s*[|｜•].*$/, "");
        t = t.replace(/[(\[【][^)\]】]*[)\]】]/g, "");                  // anything in brackets
        t = t.replace(/\b(official|lyrics?|lyric video|m\/?v|music video|audio|visuali[sz]er|live at .*|ft\.? .*|feat\.? .*)\b/gi, "");
        t = t.replace(/\s+/g, " ").trim();
        const artist = (p?.trackArtist ?? "").replace(/\s*-\s*Topic$/, "").replace(/VEVO$/i, "");
        return / [-–—] /.test(t) || !artist ? t.replace(/ [-–—] /, " ") : t + " " + artist;
    }

    function parse(lrc) {
        const out = [];
        for (const line of (lrc ?? "").split("\n")) {
            const m = /^\[(\d+):(\d+(?:\.\d+)?)\](.*)$/.exec(line.trim());
            if (m)
                out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3].trim() });
        }
        return out;
    }

    function show() {
        const c = candidates[pick];
        lines = parse(c?.synced);
        plain = c?.plain ?? "";
        status = lines.length > 0 ? "ok" : plain ? "plain" : "none";
    }

    function update(changes) {
        entry = Object.assign({}, entry, changes);
        cache[forTrack] = entry;
        save();
    }

    function request() {
        const k = Players.track;
        if (!k || k === forTrack)
            return;
        forTrack = k;
        lines = [];
        plain = "";
        entry = cache[k]?.candidates ? cache[k] : null;   // older cache entries had no candidates
        if (entry)
            show();
        else
            search(autoQuery());
    }

    // Search (again) with this query, replacing the candidates
    function search(q) {
        const k = forTrack;
        status = "loading";
        lines = [];
        get("https://lrclib.net/api/search?q=" + encodeURIComponent(q), results => {
            if (k !== root.forTrack)
                return;
            const len = Players.length;
            const near = r => len > 0 ? Math.abs(r.duration - len) : 0;
            const synced = results.filter(r => r.syncedLyrics).sort((a, b) => near(a) - near(b));
            const plainOnly = results.filter(r => !r.syncedLyrics && r.plainLyrics);
            const list = synced.concat(plainOnly).slice(0, 6).map((r, i) => ({
                id: r.id,
                name: r.trackName,
                artist: r.artistName,
                duration: r.duration,
                // lyrics kept only for the picked one; others are fetched by id
                synced: i === 0 ? (r.syncedLyrics ?? "") : null,
                plain: i === 0 ? (r.plainLyrics ?? "") : null
            }));
            root.update({ query: q, candidates: list, pick: 0, offset: root.entry?.offset ?? 0 });
            root.show();
        });
    }

    // Step to another candidate (+1 / -1), fetching its lyrics if not cached
    function choose(dir) {
        const n = candidates.length;
        if (n < 2)
            return;
        const i = (pick + dir + n) % n;
        const list = candidates.slice();
        const k = forTrack;
        const apply = () => {
            root.update({ candidates: list, pick: i });
            root.show();
        };
        if (list[i].synced !== null) {
            apply();
            return;
        }
        status = "loading";
        get("https://lrclib.net/api/get/" + list[i].id, r => {
            if (k !== root.forTrack)
                return;
            list[i] = Object.assign({}, list[i], { synced: r.syncedLyrics ?? "", plain: r.plainLyrics ?? "" });
            apply();
        });
    }

    function nudge(seconds) {
        if (entry)
            update({ offset: Math.round((offset + seconds) * 10) / 10 });
    }

    function get(url, done) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", "quickshell-bar");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status !== 200 || data === null) {
                root.status = "error";
                return;
            }
            done(data);
        };
        xhr.send();
    }

    function save() {
        const keys = Object.keys(cache);
        if (keys.length > 200)
            for (const k of keys.slice(0, keys.length - 200))
                delete cache[k];
        store.setText(JSON.stringify(cache));
    }

    FileView {
        id: store
        path: Quickshell.cachePath("lyrics.json")
        blockLoading: true
        printErrors: false            // missing until the first lookup
        onLoaded: {
            try {
                root.cache = JSON.parse(text()) ?? {};
            } catch (e) {
                root.cache = {};
            }
        }
    }
}
