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
        fontSize: 12, wsFontSize: 11, barHeight: 22, barAlpha: 1.0, panelAlpha: 0.88, matuScheme: "scheme-tonal-spot", matuContrast: 0.0,
        osdTimeout: 1500, desktopClock: true, desktopViz: true, vizBars: 64,
        dock: true, dockPinned: ["foot", "librewolf", "pcmanfm", "obsidian"], wallFolder: "dusky-dark",
        notifSound: true, notifVolume: 0.7,
        idleDim: 150, idleOff: 330, idleLock: 600, idleSuspend: 0, charTone: 0, portalAutoOpen: true,
        chargeMode: "off", batLow: 15, batCritical: 5, batCriticalAction: "none",
        privacyIndicators: true
    })

    property alias fontSize: a.fontSize
    property alias wsFontSize: a.wsFontSize
    property alias barHeight: a.barHeight
    property alias barAlpha: a.barAlpha
    property alias panelAlpha: a.panelAlpha
    property alias matuScheme: a.matuScheme
    property alias matuContrast: a.matuContrast
    property alias osdTimeout: a.osdTimeout
    property alias desktopClock: a.desktopClock
    property alias desktopViz: a.desktopViz
    property alias vizBars: a.vizBars
    property alias dock: a.dock
    property alias dockPinned: a.dockPinned
    property alias wallFolder: a.wallFolder
    property alias notifSound: a.notifSound
    property alias notifVolume: a.notifVolume
    property alias idleDim: a.idleDim
    property alias idleOff: a.idleOff
    property alias idleLock: a.idleLock
    property alias idleSuspend: a.idleSuspend
    property alias charTone: a.charTone
    property alias portalAutoOpen: a.portalAutoOpen
    property alias chargeMode: a.chargeMode
    property alias batLow: a.batLow
    property alias batCritical: a.batCritical
    property alias batCriticalAction: a.batCriticalAction
    property alias privacyIndicators: a.privacyIndicators

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
        blockLoading: true      // loaded before first use (e.g. Wall.random() right after startup)
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
            property string matuScheme: "scheme-tonal-spot"   // matugen -t (Wall.qml), accent = its primary
            property real matuContrast: 0.0                    // matugen --contrast, -1..1
            property int osdTimeout: 1500
            property bool desktopClock: true
            property bool desktopViz: true
            property int vizBars: 64
            property bool dock: true
            property list<string> dockPinned: ["foot", "librewolf", "pcmanfm", "obsidian"]
            property string wallFolder: "dusky-dark"
            property bool notifSound: true
            property real notifVolume: 0.7
            property int idleDim: 150          // hypridle timeouts in seconds, 0 = never (Idle.qml)
            property int idleOff: 330
            property int idleLock: 600
            property int idleSuspend: 0
            property int charTone: 0           // glyph picker emoji skin tone, 0 = none, 1-5 light..dark
            property bool portalAutoOpen: true // open captive portal login pages in $BROWSER (Net.qml)
            property string chargeMode: "off"  // off | conservation (Battery.qml)
            property int batLow: 15            // low battery warning, %
            property int batCritical: 5
            property string batCriticalAction: "none"   // none | suspend | poweroff
            property bool privacyIndicators: true       // mic/camera/screen-share icons in the bar (Privacy.qml)
        }
    }
    // first run: create the file once the directory exists
    Timer { id: writeLater; interval: 300; onTriggered: fv.writeAdapter() }
}
