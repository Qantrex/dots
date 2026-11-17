import QtQuick
import Quickshell
import qs.services
import qs.components

// The clock's popout: date and weather, a month calendar (deadline days get a
// dot), today's lessons, deadlines and to-dos. The school data comes from the
// homelab API (WebUntis, Moodle, the notes' due: dates, Home Assistant to-dos).
Column {
    id: root
    width: 360
    spacing: 12

    property date now: new Date()
    property int monthOffset: 0
    property var ticked: []             // to-dos clicked, until the refresh drops them

    Component.onCompleted: Homelab.refresh()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // --- Header: date + weather ------------------------------------------
    Column {
        width: parent.width
        spacing: 2
        Label { text: Qt.formatDate(root.now, "dddd"); muted: true; size: Theme.fontSmall }
        Label { text: Qt.formatDate(root.now, "d MMMM yyyy"); size: 20; bold: true }
        Label {
            visible: Homelab.weather !== null
            width: parent.width
            text: {
                const w = Homelab.weather;
                if (!w) return "";
                const it = w.items || [];
                const now = it.find(i => i.title === "Now"), day = it.find(i => i.title === "Today");
                return [now ? now.value : "", day ? day.value : "", w.subtitle || ""].filter(x => x).join("  ·  ");
            }
            muted: true
            size: Theme.fontSmall
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }

    // --- Month calendar ---------------------------------------------------
    Column {
        width: parent.width
        spacing: 4

        readonly property date first: new Date(root.now.getFullYear(), root.now.getMonth() + root.monthOffset, 1)
        readonly property int lead: (first.getDay() + 6) % 7               // Monday first
        readonly property int days: new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
        readonly property var dueDays: {
            const s = {};
            for (const d of Homelab.deadlines) s[d.dueDate.toDateString()] = d.days <= 1 ? 2 : 1;
            return s;
        }
        id: cal

        Item {
            width: parent.width
            height: 26
            Label { anchors.verticalCenter: parent.verticalCenter; leftPadding: 4; text: Qt.formatDate(cal.first, "MMMM yyyy"); bold: true }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                IconButton { size: 24; iconSize: 12; icon: "󰅁"; onClicked: root.monthOffset -= 1 }
                IconButton { size: 24; iconSize: 12; icon: "󰃭"; visible: root.monthOffset !== 0; onClicked: root.monthOffset = 0 }
                IconButton { size: 24; iconSize: 12; icon: "󰅂"; onClicked: root.monthOffset += 1 }
            }
        }

        Grid {
            columns: 7
            width: parent.width
            readonly property real cell: width / 7

            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: Label {
                    required property string modelData
                    width: parent.cell; height: 20
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    dim: true
                    size: 10
                }
            }
            Repeater {
                model: 42
                delegate: Item {
                    required property int index
                    readonly property int day: index - cal.lead + 1
                    readonly property date date: new Date(cal.first.getFullYear(), cal.first.getMonth(), day)
                    readonly property bool inMonth: day >= 1 && day <= cal.days
                    readonly property bool today: date.toDateString() === root.now.toDateString()
                    readonly property int due: cal.dueDays[date.toDateString()] ?? 0
                    visible: index < 35 || cal.lead + cal.days > 35
                    width: parent.cell; height: 30

                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26; radius: 13
                        color: parent.today ? Theme.accent : "transparent"
                    }
                    Label {
                        anchors.centerIn: parent
                        text: parent.date.getDate()
                        size: Theme.fontSmall + 1
                        bold: parent.today
                        color: parent.today ? Theme.inverse : (parent.inMonth ? (index % 7 >= 5 ? Theme.fgMuted : Theme.fg) : Theme.fgDim)
                    }
                    Rectangle {
                        visible: parent.due > 0 && parent.inMonth
                        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 1 }
                        width: 4; height: 4; radius: 2
                        color: parent.due === 2 ? Theme.gold : Theme.fgMuted
                    }
                }
            }
        }
    }

    // --- Lessons -----------------------------------------------------------
    Column {
        width: parent.width
        visible: Homelab.lessons.length > 0 && root.monthOffset === 0
        spacing: 1

        readonly property string hm: Qt.formatTime(root.now, "HH:mm")
        id: lessons

        SectionTitle {
            width: parent.width
            text: Homelab.today && Homelab.today.date && Homelab.today.date !== Qt.formatDate(root.now, "yyyy-MM-dd")
                  ? "Lessons · " + Homelab.today.date : "Lessons"
        }
        Repeater {
            model: Homelab.lessons
            delegate: ListRow {
                required property var modelData
                readonly property bool past: modelData.to && modelData.to <= lessons.hm
                readonly property bool current: modelData.from <= lessons.hm && !past
                width: parent.width
                implicitHeight: 24
                clickable: false
                title: modelData.subjects.join(" / ")
                titleColor: past ? Theme.fgDim : (modelData.changed ? Theme.gold : Theme.fg)
                value: modelData.time + (modelData.room ? "  " + modelData.room : "")
                valueColor: past ? Theme.fgDim : Theme.fgMuted
                highlighted: current
                icon: current ? "󰁔" : ""
            }
        }
    }

    // --- Deadlines -----------------------------------------------------------
    Column {
        width: parent.width
        visible: Homelab.deadlines.length > 0
        spacing: 1
        SectionTitle { width: parent.width; text: "Deadlines" }
        Repeater {
            model: Homelab.deadlines.slice(0, 5)
            delegate: ListRow {
                required property var modelData
                width: parent.width
                title: modelData.title
                // Notes rows repeat the title in the subtitle; Moodle rows put the course there.
                subtitle: modelData.subtitle && !modelData.title.includes(modelData.subtitle.slice(0, 12)) ? modelData.subtitle : ""
                value: Homelab.dayWord(modelData.days) + (modelData.hasTime ? " " + Qt.formatTime(modelData.dueDate, "HH:mm") : "")
                valueColor: modelData.days < 0 ? Theme.love : (modelData.days <= 1 ? Theme.gold : Theme.fgMuted)
                titleColor: modelData.days < 0 ? Theme.fgMuted : Theme.fg
                clickable: !!modelData.url
                onClicked: if (modelData.url) { Qt.openUrlExternally(modelData.url); Shell.close(); }
            }
        }
    }

    // --- To-dos ----------------------------------------------------------------
    Column {
        width: parent.width
        visible: Homelab.todos.length > 0
        spacing: 1
        SectionTitle { width: parent.width; text: "To-dos" }
        Repeater {
            model: Homelab.todos
            delegate: ListRow {
                required property var modelData
                readonly property bool done: root.ticked.includes(modelData.title)
                width: parent.width
                icon: done ? "󰄲" : "󰄱"
                title: modelData.title
                titleColor: done ? Theme.fgDim : Theme.fg
                value: modelData.subtitle && modelData.subtitle !== "to-do" ? modelData.subtitle : ""
                onClicked: if (!done) { root.ticked = root.ticked.concat([modelData.title]); Homelab.tick(modelData); }
            }
        }
    }

    // --- Footer --------------------------------------------------------------
    Item {
        width: parent.width
        height: 20
        Label {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            text: !Homelab.base ? "No homelab URL in ~/.config/homelab/api-url"
                  : (Homelab.loading ? "Updating…" : (Homelab.reachable ? "Homelab · " + Qt.formatTime(Homelab.fetched, "HH:mm")
                                                                         : "Homelab not reachable"))
            size: 10
            color: Homelab.reachable || Homelab.loading ? Theme.fgDim : Theme.gold
        }
        MouseArea {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: open.implicitWidth + 8; height: 20
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { Homelab.open("/"); Shell.close(); }
            Label { id: open; anchors.centerIn: parent; text: "Open chat"; size: 10; color: parent.containsMouse ? Theme.iris : Theme.fgDim }
        }
    }
}
