// Synced lyrics from LRCLIB (https://lrclib.net) for Players.active, fetched only when
// asked (the player panel calls request() when it opens), cached on disk by track.
// Sends the cleaned-up title / artist to lrclib.net; nothing else.
// `import qs`, then Lyrics.lines / .current / .status.
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
    property var cache: ({})          // track key -> { synced, plain }

    // Index of the line being sung (-1 before the first)
    readonly property int current: {
        const pos = Players.position + 0.3;
        let i = -1;
        for (let k = 0; k < lines.length && lines[k].t <= pos; k++)
            i = k;
        return i;
    }

    function key() {
        return Players.track;
    }

    // "Song - Artist | Live at ... (Official MV)" -> "Song Artist"
    function query() {
        const p = Players.active;
        let t = (p?.trackTitle ?? "").replace(/\s*[|｜].*$/, "");
        t = t.replace(/[(\[][^)\]]*(official|lyric|audio|video|live|m\/?v|visuali[sz]er)[^)\]]*[)\]]/gi, "");
        t = t.replace(/\b(official|lyrics?|m\/?v)\b/gi, "").trim();
        const artist = (p?.trackArtist ?? "").replace(/\s*-\s*Topic$/, "");
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

    function show(entry) {
        lines = parse(entry?.synced);
        plain = entry?.plain ?? "";
        status = lines.length > 0 ? "ok" : plain ? "plain" : "none";
    }

    function request() {
        const k = key();
        if (!k || k === forTrack)
            return;
        forTrack = k;
        lines = [];
        plain = "";
        if (cache[k]) {
            show(cache[k]);
            return;
        }
        status = "loading";
        search(query(), true);
    }

    function search(q, retry) {
        const k = forTrack;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", "https://lrclib.net/api/search?q=" + encodeURIComponent(q));
        xhr.setRequestHeader("Lrclib-Client", "quickshell-bar");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || k !== root.forTrack)
                return;
            if (xhr.status !== 200) {
                root.status = "error";
                return;
            }
            let results = [];
            try {
                results = JSON.parse(xhr.responseText);
            } catch (e) {}
            // Retry once with just the title when "title artist" finds nothing
            if (results.length === 0 && retry) {
                const title = (Players.active?.trackTitle ?? "").replace(/\s*[|｜].*$/, "").replace(/ [-–—] .*$/, "");
                if (title && title !== q) {
                    root.search(title, false);
                    return;
                }
            }
            const len = Players.length;
            const synced = results.filter(r => r.syncedLyrics);
            if (len > 0)
                synced.sort((a, b) => Math.abs(a.duration - len) - Math.abs(b.duration - len));
            const best = synced[0] ?? results.find(r => r.plainLyrics);
            const entry = { synced: best?.syncedLyrics ?? "", plain: best?.plainLyrics ?? "" };
            root.cache[k] = entry;
            root.save();
            root.show(entry);
        };
        xhr.send();
    }

    function save() {
        const keys = Object.keys(cache);
        if (keys.length > 300)
            for (const k of keys.slice(0, keys.length - 300))
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
