// CPU, RAM and network sampled once a second from /proc, always running so the graphs
// already have history when shown. `import qs`, then SysStats.cpu / .cpuHistory / ...
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property int historyLength: 60

    property real cpu: 0              // 0..1
    property real mem: 0              // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real rxRate: 0           // bytes/s, all interfaces but lo
    property real txRate: 0
    property var cpuHistory: []
    property var memHistory: []

    property var lastCpu: null        // [idle, total]
    property var lastNet: null        // [rx, tx, ms]

    function push(list, v) {
        const l = list.concat([v]);
        return l.length > historyLength ? l.slice(l.length - historyLength) : l;
    }

    // "1.2 MB/s"-style, 3 significant digits at most
    function rate(bps) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bps >= 1000 && i < units.length - 1) {
            bps /= 1024;
            i++;
        }
        return (bps >= 100 || i === 0 ? Math.round(bps) : bps.toFixed(1)) + " " + units[i];
    }

    function sample() {
        stat.reload();
        meminfo.reload();
        netdev.reload();

        // cpu  user nice system idle iowait irq softirq steal ...
        const f = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        if (f.length >= 5) {
            const idle = f[3] + f[4];
            const total = f.slice(0, 8).reduce((a, b) => a + b, 0);
            if (lastCpu && total > lastCpu[1])
                cpu = 1 - (idle - lastCpu[0]) / (total - lastCpu[1]);
            lastCpu = [idle, total];
        }

        const m = meminfo.text();
        const total = Number(/MemTotal:\s+(\d+)/.exec(m)?.[1] ?? 0);
        const avail = Number(/MemAvailable:\s+(\d+)/.exec(m)?.[1] ?? 0);
        if (total > 0) {
            mem = (total - avail) / total;
            memUsedGiB = (total - avail) / 1048576;
            memTotalGiB = total / 1048576;
        }

        let rx = 0, tx = 0;
        for (const line of netdev.text().split("\n").slice(2)) {
            const [name, rest] = line.split(":");
            if (!rest || name.trim() === "lo")
                continue;
            const n = rest.trim().split(/\s+/).map(Number);
            rx += n[0];
            tx += n[8];
        }
        const now = Date.now();
        if (lastNet && now > lastNet[2]) {
            rxRate = Math.max(0, (rx - lastNet[0]) * 1000 / (now - lastNet[2]));
            txRate = Math.max(0, (tx - lastNet[1]) * 1000 / (now - lastNet[2]));
        }
        lastNet = [rx, tx, now];

        cpuHistory = push(cpuHistory, cpu);
        memHistory = push(memHistory, mem);
    }

    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    FileView { id: netdev; path: "/proc/net/dev"; blockLoading: true }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: root.sample()
    }
}
