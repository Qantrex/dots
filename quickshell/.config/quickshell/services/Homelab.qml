pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The homelab agent's Companion API (GET /api/v1/state), the same data the iOS
// app shows: deadlines (notes + Moodle), to-dos, today's lessons, weather,
// problems and pending approvals. Reached over the tailnet; `tailscale serve`
// adds the login header, so no token is needed on the laptop or the PC.
//
// The base URL is private and lives outside the dotfiles, in
// ~/.config/homelab/api-url (one line, e.g. https://<host>.<tailnet>.ts.net).
Singleton {
    id: root

    readonly property string base: urlFile.text().trim()
    property bool reachable: false
    property bool loading: false
    property date fetched
    property var state: null

    readonly property var cards: {
        const m = {};
        for (const c of (state?.cards ?? [])) m[c.id] = c;
        return m;
    }

    readonly property var problems: state?.problems ?? []
    readonly property var pending: state?.pending ?? []
    readonly property bool healthy: reachable && (state?.status ?? "ok") === "ok" && problems.length === 0

    // Deadlines, soonest first, with whole days left (negative = overdue).
    readonly property var deadlines: (cards.deadlines?.items ?? []).map(d => {
        const due = parseDue(d.due);
        return Object.assign({}, d, { dueDate: due, days: daysUntil(due), hasTime: (d.due || "").includes("T") });
    }).sort((a, b) => a.dueDate - b.dueDate)
    // The bar's hint: the soonest one due today, tomorrow or the day after.
    readonly property var urgent: deadlines.find(d => d.days >= 0 && d.days <= 2) ?? null

    readonly property var todos: (cards.todos?.items ?? []).filter(t => !t.done)
    readonly property var weather: cards.weather ?? null
    readonly property var today: cards.today ?? null

    // Lessons, merged per time slot (parallel groups share one row).
    readonly property var lessons: {
        const slots = [];
        for (const l of (cards.lessons?.items ?? [])) {
            const last = slots[slots.length - 1];
            if (last && last.time === l.value) {
                if (!last.subjects.includes(l.title)) last.subjects.push(l.title);
                last.changed = last.changed || !!l.tint;
            } else {
                const [from, to] = (l.value || "").split("–");
                slots.push({ time: l.value, from, to, subjects: [l.title], room: (l.subtitle || "").split(" · ")[0],
                             changed: !!l.tint });
            }
        }
        return slots;
    }

    function parseDue(s) {
        if (!s) return new Date(8640000000000000);
        const [d, t] = s.split("T");
        const [y, mo, da] = d.split("-").map(Number);
        const [h, mi] = (t || "23:59").split(":").map(Number);
        return new Date(y, mo - 1, da, h, mi);
    }
    function daysUntil(due) {
        const now = new Date();
        const a = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const b = new Date(due.getFullYear(), due.getMonth(), due.getDate());
        return Math.round((b - a) / 86400000);
    }
    function dayWord(days) {
        if (days < -1) return -days + " days ago";
        if (days === -1) return "yesterday";
        if (days === 0) return "today";
        if (days === 1) return "tomorrow";
        return "in " + days + " d";
    }
    // "ITP — Risikobewertung und Konzept" -> "ITP"; Moodle rows put the course in the subtitle.
    function shortTitle(d) {
        const t = d.title || "";
        if (t.includes(" — ")) return t.split(" — ")[0];
        return t.length > 22 ? t.slice(0, 21) + "…" : t;
    }

    function refresh() {
        if (!base || fetcher.running) return;
        loading = true;
        fetcher.running = true;
    }
    function open(path) { if (base) Qt.openUrlExternally(base + (path || "/")); }

    // Runs an app action (POST /api/v1/actions/<name>), then refreshes.
    function action(name, arg, payload) {
        if (!base) return;
        const body = JSON.stringify({ arg: arg || "", payload: payload || {} });
        Quickshell.execDetached(["sh", "-c",
            'curl -fsS -m 30 -H "Content-Type: application/json" -d "$1" "$2" >/dev/null && qs ipc call homelab refresh',
            "action", body, base + "/api/v1/actions/" + name]);
    }
    function tick(todo) { if (todo.action) action(todo.action.name, todo.action.arg, todo.action.payload); }

    FileView {
        id: urlFile
        path: Host.home + "/.config/homelab/api-url"
        blockLoading: true
        printErrors: false
    }

    Process {
        id: fetcher
        command: ["curl", "-fsS", "-m", "10", root.base + "/api/v1/state"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.state = JSON.parse(text);
                    root.reachable = true;
                    root.fetched = new Date();
                } catch (e) {
                    root.reachable = false;
                }
            }
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0) root.reachable = false;
        }
    }

    // Every 5 minutes, plus when a popout that shows this data opens.
    Timer {
        interval: 300000
        running: root.base !== ""
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "homelab"
        function refresh(): void { root.refresh(); }
    }
}
