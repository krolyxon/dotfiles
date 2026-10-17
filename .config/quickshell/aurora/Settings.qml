pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User knobs persisted to ~/.config/aurora/settings.json (outside the shell dir, so syncing the
// config never clobbers it). Written on every change, re-read when edited by hand.
Singleton {
    id: root
    readonly property string file: Quickshell.env("HOME") + "/.config/aurora/settings.json"

    // defaults live here; reset() puts them back
    readonly property var defaults: ({
        fontSize: 12, wsFontSize: 11, barHeight: 22, barAlpha: 1.0, panelAlpha: 0.88, accentIndex: 14,
        osdTimeout: 1500, desktopClock: true, desktopViz: true, vizBars: 64,
        dock: true, dockPinned: ["foot", "librewolf", "pcmanfm", "obsidian"], wallFolder: "dusky-dark"
    })

    property alias fontSize: a.fontSize
    property alias wsFontSize: a.wsFontSize
    property alias barHeight: a.barHeight
    property alias barAlpha: a.barAlpha
    property alias panelAlpha: a.panelAlpha
    property alias accentIndex: a.accentIndex
    property alias osdTimeout: a.osdTimeout
    property alias desktopClock: a.desktopClock
    property alias desktopViz: a.desktopViz
    property alias vizBars: a.vizBars
    property alias dock: a.dock
    property alias dockPinned: a.dockPinned
    property alias wallFolder: a.wallFolder

    function reset() {
        for (var k in defaults) a[k] = defaults[k]
    }
    function togglePin(id) {
        var l = dockPinned.slice(), i = l.indexOf(id)
        if (i >= 0) l.splice(i, 1); else l.push(id)
        dockPinned = l
    }

    FileView {
        id: fv
        path: root.file
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}"', "sh", root.file])
            writeLater.start()
        }
        adapter: JsonAdapter {
            id: a
            property int fontSize: 12
            property int wsFontSize: 11
            property int barHeight: 22
            property real barAlpha: 1.0
            property real panelAlpha: 0.88
            property int accentIndex: 14
            property int osdTimeout: 1500
            property bool desktopClock: true
            property bool desktopViz: true
            property int vizBars: 64
            property bool dock: true
            property list<string> dockPinned: ["foot", "librewolf", "pcmanfm", "obsidian"]
            property string wallFolder: "dusky-dark"
        }
    }
    // first run: create the file once the directory exists
    Timer { id: writeLater; interval: 300; onTriggered: fv.writeAdapter() }
}
