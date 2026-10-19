import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings app > Display: monitors (live, with a keep/revert countdown), kanshi profiles, brightness, night light.
// Monitor changes are runtime only: kanshi re-applies its profile on hotplug, persistent layouts live in its config.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    readonly property string kanshiFile: Quickshell.env("HOME") + "/.config/kanshi/config"
    property var monitors: []          // hyprctl monitors all -j
    property var revertSpec: null      // spec to restore if the change isn't kept
    property int countdown: 0
    property string message: ""

    function refresh() { monProc.running = true }
    Component.onCompleted: refresh()

    // monitor -> its current spec
    function specOf(m) {
        if (m.disabled) return { output: m.name, disabled: true }
        return { output: m.name, mode: m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2),
                 position: m.x + "x" + m.y, scale: m.scale }
    }
    // only characters a monitor name / mode / position can contain, so nothing can break out of the Lua string
    function q(s) { return '"' + String(s).replace(/[^A-Za-z0-9@x._\-]/g, "") + '"' }
    function lua(spec) {
        if (spec.disabled) return "hl.monitor({ output = " + q(spec.output) + ", disabled = true })"
        return "hl.monitor({ output = " + q(spec.output) + ", mode = " + q(spec.mode) + ", position = "
            + q(spec.position) + ", scale = " + Number(spec.scale) + " })"
    }
    function apply(m, change) {
        var spec
        if (change.disabled) spec = { output: m.name, disabled: true }
        else if (m.disabled) spec = { output: m.name, mode: "preferred", position: "auto", scale: 1 }
        else {
            spec = specOf(m)
            for (var k in change) spec[k] = change[k]
        }
        revertSpec = specOf(m)
        run(lua(spec))
        countdown = 15
        tick.restart()
    }
    function keep() { revertSpec = null; countdown = 0; tick.stop() }
    function revert() {
        if (revertSpec) run(lua(revertSpec))
        keep()
    }
    function run(code) {
        evalProc.command = ["hyprctl", "eval", code]
        evalProc.running = true
    }
    function enabledCount() {
        var n = 0
        for (var i = 0; i < monitors.length; i++) if (!monitors[i].disabled) n++
        return n
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: { if (--flick.countdown <= 0) flick.revert() }
    }
    Process {
        id: monProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: { try { flick.monitors = JSON.parse(text) } catch (e) {} }
        }
    }
    Process {
        id: evalProc
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim()
                flick.message = t === "" || t === "ok" ? "" : t
                refreshLater.restart()
            }
        }
    }
    Timer { id: refreshLater; interval: 600; onTriggered: flick.refresh() }

    // kanshi profiles: `profile NAME {` lines
    property var profiles: []
    FileView {
        path: flick.kanshiFile
        printErrors: false
        onLoaded: {
            var out = [], re = /^\s*profile\s+(\S+)\s*\{/gm, mm
            var t = text()
            while ((mm = re.exec(t)) !== null) out.push(mm[1])
            flick.profiles = out
        }
    }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        // keep / revert bar after a monitor change
        Rectangle {
            Layout.fillWidth: true
            visible: flick.countdown > 0
            implicitHeight: 40
            color: Theme.surface
            border.width: 1
            border.color: Theme.accent
            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                Text {
                    Layout.fillWidth: true
                    text: "keep this display setup? reverting in " + flick.countdown + "s"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                IconBtn { icon: Theme.iCheck; label: "keep"; active: true; onClicked: flick.keep() }
                IconBtn { icon: Theme.iRefresh; label: "revert"; onClicked: flick.revert() }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: flick.message !== ""
            text: flick.message
            color: Theme.err
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        Repeater {
            model: flick.monitors
            delegate: ColumnLayout {
                id: mon
                required property var modelData
                readonly property var m: modelData
                readonly property string curMode: m.width + "x" + m.height
                Layout.fillWidth: true
                spacing: 6

                SectionLabel { text: mon.m.name }
                Text {
                    Layout.fillWidth: true
                    text: mon.m.description + (mon.m.disabled ? "  ·  disabled"
                        : "  ·  " + mon.curMode + " @ " + mon.m.refreshRate.toFixed(2) + "Hz  ·  scale " + mon.m.scale
                          + "  ·  at " + mon.m.x + "," + mon.m.y)
                    color: Theme.dim
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                Switch {
                    label: "enabled"
                    hint: !mon.m.disabled && flick.enabledCount() <= 1 ? "the only active monitor can't be turned off" : ""
                    checked: !mon.m.disabled
                    onToggled: on => {
                        if (!on && flick.enabledCount() <= 1) return
                        flick.apply(mon.m, { disabled: !on })
                    }
                }
                Text {
                    visible: !mon.m.disabled
                    text: "mode"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                Flow {
                    Layout.fillWidth: true
                    visible: !mon.m.disabled
                    spacing: 4
                    Repeater {
                        model: mon.m.availableModes
                        delegate: IconBtn {
                            required property string modelData
                            readonly property string mode: modelData.replace("Hz", "")
                            readonly property real hz: parseFloat(mode.split("@")[1])
                            implicitHeight: 24
                            label: mode
                            active: mode.split("@")[0] === mon.curMode && Math.abs(hz - mon.m.refreshRate) < 0.02
                            onClicked: if (!active) flick.apply(mon.m, { mode: mode })
                        }
                    }
                }
                Choice {
                    visible: !mon.m.disabled
                    label: "scale"
                    options: [{ value: 1, label: "100%" }, { value: 1.25, label: "125%" }, { value: 1.5, label: "150%" },
                              { value: 1.75, label: "175%" }, { value: 2, label: "200%" }]
                    value: Math.round(mon.m.scale * 100) / 100
                    onPicked: x => flick.apply(mon.m, { scale: x })
                }
                Field {
                    visible: !mon.m.disabled
                    label: "position"
                    placeholder: "1920x0"
                    value: mon.m.x + "x" + mon.m.y
                    onSubmitted: x => {
                        if (/^-?\d+x-?\d+$/.test(x.trim())) flick.apply(mon.m, { position: x.trim() })
                        else flick.message = "position must look like 1920x0"
                    }
                }
            }
        }

        SectionLabel { text: "profiles (kanshi)" }
        Text {
            Layout.fillWidth: true
            text: "changes above are temporary: kanshi re-applies its profile when monitors are plugged in."
            color: Theme.dim
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: flick.profiles
                delegate: IconBtn {
                    required property string modelData
                    implicitHeight: 26
                    icon: Theme.iMonitor
                    label: modelData
                    onClicked: {
                        Quickshell.execDetached(["kanshictl", "switch", modelData])
                        refreshLater.restart()
                    }
                }
            }
            IconBtn {
                implicitHeight: 26
                icon: Theme.iConsole
                label: "edit config"
                onClicked: Quickshell.execDetached(["sh", "-c", 'exec foot -e "${EDITOR:-nvim}" "$1"', "sh", flick.kanshiFile])
            }
        }

        SectionLabel { text: "brightness & colour" }
        Knob {
            visible: Bright.available
            label: "laptop panel"
            unit: "%"
            from: 1
            to: 100
            value: Bright.percent
            onMoved: x => Bright.setPercent(x)
        }
        Switch {
            visible: Toggles.hasNightLight
            label: "night light"
            hint: "gammastep's warm colours (its schedule comes from ~/.config/gammastep)"
            checked: Toggles.nightLight
            onToggled: on => Toggles.setNightLight(on)
        }
        Text {
            visible: !Toggles.hasNightLight
            text: "night light: gammastep isn't running"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }
    }
}
