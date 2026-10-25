pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

// Privacy indicators for the bar: who records the mic, uses the camera or shares the screen.
//   mic     Pipewire input streams linked to an audio source (not a sink monitor, so cava/visualizers don't count)
//   camera  processes holding /dev/video* open (mpv, browsers without the camera portal) + Pipewire
//           video streams fed by a v4l2/libcamera node
//   screen  Hyprland's `screencast` event (xdg-desktop-portal-hyprland) + the apps consuming its video node.
//           wf-recorder (Rec) uses screencopy instead and has its own bar pill.
Singleton {
    id: root
    readonly property bool enabled: Settings.privacyIndicators
    readonly property var ignore: ["quickshell", "qs", "cava"]

    function appName(n) {
        var p = n.properties
        return p["application.name"] || p["application.process.binary"] || n.name
    }
    // apps whose `streamCls` streams are linked to a node of class `srcCls`*, filtered by keep(source)
    function captures(srcCls, streamCls, keep) {
        var out = [], l = Pipewire.linkGroups.values
        for (var i = 0; i < l.length; i++) {
            var s = l[i].source, t = l[i].target
            if (!s || !t) continue
            if ((s.properties["media.class"] || "").indexOf(srcCls) !== 0) continue
            if ((t.properties["media.class"] || "") !== streamCls) continue
            if (ignore.indexOf(t.properties["application.process.binary"] || "") >= 0) continue
            if (keep && !keep(s)) continue
            var a = appName(t)
            if (out.indexOf(a) < 0) out.push(a)
        }
        return out
    }
    function isCam(n) {
        var api = n.properties["device.api"] || ""
        return api === "v4l2" || api === "libcamera"
    }

    readonly property var micApps: enabled ? captures("Audio/Source", "Stream/Input/Audio", null) : []
    readonly property var pwCamApps: enabled ? captures("Video/Source", "Stream/Input/Video", isCam) : []
    readonly property var shareApps: enabled ? captures("Video/Source", "Stream/Input/Video", n => !isCam(n)) : []
    property var devCamApps: []      // from the /proc scan
    property bool casting: false     // Hyprland screencast event

    readonly property var camApps: {
        var out = pwCamApps.slice()
        for (var i = 0; i < devCamApps.length; i++) if (out.indexOf(devCamApps[i]) < 0) out.push(devCamApps[i])
        return out
    }
    readonly property bool mic: micApps.length > 0
    readonly property bool cam: camApps.length > 0
    readonly property bool screen: enabled && (casting || shareApps.length > 0)

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "screencast") root.casting = ev.data.split(",")[0] === "1"
        }
    }

    // /dev/video* holders. Only our own processes are readable, which is every app that matters here.
    // pipewire/wireplumber holding it means a portal client: that one shows up in pwCamApps instead.
    Timer {
        interval: 3000
        running: root.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!camProc.running) camProc.running = true
    }
    Process {
        id: camProc
        command: ["sh", "-c", "find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' 2>/dev/null"
                  + " | cut -d/ -f3 | sort -u | while read -r p; do cat \"/proc/$p/comm\" 2>/dev/null; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var c = l[i].trim()
                    if (c === "" || c === "pipewire" || c === "wireplumber" || out.indexOf(c) >= 0) continue
                    out.push(c)
                }
                if (out.join() !== root.devCamApps.join()) root.devCamApps = out
            }
        }
    }
    onEnabledChanged: if (!enabled) { devCamApps = []; casting = false }
}
