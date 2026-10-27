pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery care: charge limit and low-battery warnings.
// The Legion firmware only has a fixed cap ("conservation mode", sysfs charge_types Long_Life). UPower
// switches it without sudo (EnableChargeThreshold, polkit allow_active) but Quickshell's UPower doesn't
// expose that, hence busctl. Settings.chargeMode:
//   off           normal charging
//   conservation  firmware cap on all the time (stops at ~80%, kept by the EC, works without aurora)
// (anything else that isn't "off", like the old "limit80", counts as conservation)
Singleton {
    id: root

    property string path: ""            // the battery's UPower object, found with `upower -e`
    property bool supported: false      // ChargeThresholdSupported
    property bool capOn: false          // ChargeThresholdEnabled (conservation mode right now)
    readonly property bool ready: path !== ""
    // UPower reports 0% for a moment at startup: no decisions before this
    property bool started: false
    Timer { interval: 4000; running: true; onTriggered: { root.started = true; root.evaluate(); root.checkLow(); root.applyAuto() } }

    readonly property var bat: UPower.displayDevice
    readonly property bool hasBat: bat !== null && bat.isPresent
    readonly property int pct: hasBat ? Math.round(bat.percentage > 1 ? bat.percentage : bat.percentage * 100) : 100
    readonly property bool onAc: !UPower.onBattery
    // plugged in but not charging because of the cap
    readonly property bool held: hasBat && onAc && capOn && bat.state !== UPowerDeviceState.Charging

    // ---- charge limit
    function busctl(args) {
        return ["busctl", "--system"].concat(args.slice(0, 1), ["org.freedesktop.UPower", root.path,
                                                                "org.freedesktop.UPower.Device"], args.slice(1))
    }
    function setCap(on) {
        if (!ready || !supported || setProc.running) return
        setProc.want = on
        setProc.command = busctl(["call", "EnableChargeThreshold", "b", on ? "true" : "false"])
        setProc.running = true
    }
    // keep the firmware cap in line with the setting
    function evaluate() {
        if (!started || !ready || !supported || !hasBat) return
        var want = Settings.chargeMode !== "off"
        if (want !== capOn) setCap(want)
    }

    onPctChanged: checkLow()
    onOnAcChanged: { checkLow(); applyAuto() }
    Connections {
        target: Settings
        function onChargeModeChanged() { root.evaluate() }
        function onBatLowChanged() { root.checkLow() }
        function onBatCriticalChanged() { root.checkLow() }
        function onBatCriticalActionChanged() { root.warnedCritical = false; root.checkLow() }
    }

    Process {
        command: ["upower", "-e"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.split("\n")
                for (var i = 0; i < l.length; i++)
                    if (l[i].indexOf("/battery_") >= 0) { root.path = l[i].trim(); break }
                if (root.ready) getProc.running = true
            }
        }
    }
    // "b true\nb false"
    Process {
        id: getProc
        command: root.busctl(["get-property", "ChargeThresholdSupported", "ChargeThresholdEnabled"])
        stdout: StdioCollector {
            onStreamFinished: {
                var l = text.trim().split("\n")
                if (l.length < 2) return
                root.supported = l[0].trim() === "b true"
                root.capOn = l[1].trim() === "b true"
                root.evaluate()
            }
        }
    }
    Process {
        id: setProc
        property bool want: false
        stderr: StdioCollector { id: setErr }
        onExited: code => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "battery", "charge limit",
                                         "couldn't switch conservation mode: " + setErr.text.trim()])
            getProc.running = true   // read back the real state
        }
    }

    // ---- power-profiles-daemon present? (Quickshell's PowerProfiles has no "available" flag)
    // Don't touch PowerProfiles before it is: reading it D-Bus-activates ppd and blocks the whole shell until it
    // runs, and ppd is After=multi-user.target (which waits on network-online), so that can be 30s+ after login.
    property bool hasProfiles: false
    readonly property bool hasPerf: hasProfiles && PowerProfiles.hasPerformanceProfile
    property int ppdTries: 0
    Process {
        id: ppdCheck
        command: ["busctl", "--system", "status", "org.freedesktop.UPower.PowerProfiles"]
        running: true
        stdout: StdioCollector {}
        onExited: code => { root.ppdTries++; root.hasProfiles = code === 0; root.applyAuto() }
    }
    // keep looking for ~2 min after start
    Timer {
        interval: 5000
        repeat: true
        running: !root.hasProfiles && root.ppdTries < 24
        onTriggered: if (!ppdCheck.running) ppdCheck.running = true
    }

    // ---- power profile: saver | balanced | performance (set in ppd, which remembers it), or auto =
    // Settings.powerAc / powerBat, switched when the power source changes
    readonly property string profile: Settings.powerAuto ? "auto" : hasProfiles ? nameOf(PowerProfiles.profile) : "balanced"
    function nameOf(p) {
        return p === PowerProfile.PowerSaver ? "saver" : p === PowerProfile.Performance ? "performance" : "balanced"
    }
    function profileOf(name) {
        if (name === "saver") return PowerProfile.PowerSaver
        if (name === "performance" && hasPerf) return PowerProfile.Performance
        return PowerProfile.Balanced
    }
    function setProfile(name) {
        Settings.powerAuto = name === "auto"
        if (name === "auto") applyAuto()
        else if (hasProfiles) PowerProfiles.profile = profileOf(name)
    }
    function applyAuto() {
        if (!started || !hasProfiles || !Settings.powerAuto) return
        var p = profileOf(onAc ? Settings.powerAc : Settings.powerBat)
        if (PowerProfiles.profile !== p) PowerProfiles.profile = p
    }
    Connections {
        target: Settings
        function onPowerAutoChanged() { root.applyAuto() }
        function onPowerAcChanged() { root.applyAuto() }
        function onPowerBatChanged() { root.applyAuto() }
    }

    // ---- low battery: one warning per level per discharge, then the critical action after 60s
    property bool warnedLow: false
    property bool warnedCritical: false
    function checkLow() {
        if (!started || (hasBat && pct <= 0)) return
        if (!hasBat || onAc) {
            warnedLow = warnedCritical = false
            if (critical.running) { critical.stop(); critNote.running = false }
            return
        }
        // re-arm once above a level again (a threshold changed in settings)
        if (pct > Settings.batLow) warnedLow = false
        if (pct > Settings.batCritical) {
            warnedCritical = false
            if (critical.running) { critical.stop(); critNote.running = false }
        }
        if (pct <= Settings.batCritical && !warnedCritical) {
            warnedCritical = warnedLow = true
            var act = Settings.batCriticalAction
            if (act === "none") {
                Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "-i", "battery-caution",
                                         "battery critical", pct + "% left, plug in now"])
            } else {
                critNote.command = ["notify-send", "-a", "aurora", "-u", "critical", "-i", "battery-caution",
                                    "-A", "cancel=cancel", "battery critical",
                                    pct + "% left: " + (act === "suspend" ? "suspending" : "powering off")
                                    + " in 60s unless plugged in"]
                critNote.running = true
                critical.restart()
            }
        } else if (pct <= Settings.batLow && !warnedLow) {
            warnedLow = true
            Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "-i", "battery-caution",
                                     "battery low", pct + "% left"])
        }
    }

    Timer {
        id: critical
        interval: 60000
        onTriggered: {
            critNote.running = false
            Session.run(Settings.batCriticalAction === "suspend" ? "sleep" : "shutdown")
        }
    }
    // the critical warning's "cancel" button
    Process {
        id: critNote
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "cancel") critical.stop()
        }
    }
}
