import QtQuick

// catloop.sh, natively: frames A-E awake, G-N asleep. Faster with more CPU load,
// falls asleep after 4 idle cycles. Needs the "Waycat" font you already use.
Item {
    id: cat
    implicitWidth: Math.max(40, size * 2.6)
    property int size: 14                // the bar uses 14; the home screen draws it big

    property int idx: 0
    property bool sleeping: false
    property int low: 0
    readonly property var awake: ["A", "B", "C", "D", "E"]
    readonly property var asleep: ["G", "H", "I", "J", "K", "L", "M", "N"]
    readonly property var frames: sleeping ? asleep : awake

    Text {
        anchors.centerIn: parent
        text: cat.frames[cat.idx] || ""
        color: Theme.fg
        font.family: "Waycat"
        font.pixelSize: cat.size
        font.bold: true
    }

    Timer {
        id: tick
        running: true
        repeat: true
        interval: 250
        onTriggered: {
            var next = cat.idx + 1
            if (next >= cat.frames.length) {
                next = 0
                cat.low = SysStats.cpu < 0.02 ? cat.low + 1 : 0
                cat.sleeping = cat.low >= 4
            }
            cat.idx = next
            tick.interval = Math.round(Math.max(0.03, 1 / (4 + SysStats.cpu * 100)) * 1000)
        }
    }
}
