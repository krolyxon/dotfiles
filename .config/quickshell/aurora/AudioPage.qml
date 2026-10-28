import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

// Control panel > sound (also the settings app's sound section): output / input levels, devices, per-app volume.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    implicitHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    function mediaClass(n) {
        return (n.properties && n.properties["media.class"]) ? String(n.properties["media.class"]) : ""
    }
    function label(n) { return n.description || n.nickname || n.name }

    // kind: "sink" | "source" | "stream"
    function nodes(kind) {
        var l = Pipewire.nodes.values, out = []
        for (var i = 0; i < l.length; i++) {
            var n = l[i]
            if (!n.audio) continue
            if (kind === "sink" && !n.isStream && n.isSink) out.push(n)
            else if (kind === "source" && !n.isStream && !n.isSink) out.push(n)
            else if (kind === "stream" && n.isStream && mediaClass(n).indexOf("Output") >= 0) out.push(n)
        }
        return out
    }
    function sinkIcon(n) {
        var s = (n.name + " " + n.description).toLowerCase()
        return (s.indexOf("bluez") >= 0 || s.indexOf("head") >= 0) ? Theme.iHeadphones : Theme.iSpeaker
    }

    readonly property var sinks: nodes("sink")
    readonly property var sources: nodes("source")
    readonly property var streams: nodes("stream")
    readonly property var out: Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var inp: Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 6

        SectionLabel { text: "levels" }
        SliderRow {
            Layout.fillWidth: true
            Layout.topMargin: 4
            icon: Theme.volIcon(flick.out ? flick.out.volume : 0, flick.out ? flick.out.muted : true)
            value: flick.out ? flick.out.volume : 0
            muted: flick.out ? flick.out.muted : false
            onMoved: v => { if (flick.out) flick.out.volume = v }
            onIconClicked: if (flick.out) flick.out.muted = !flick.out.muted
        }
        SliderRow {
            Layout.fillWidth: true
            Layout.topMargin: 6
            icon: flick.inp && !flick.inp.muted ? Theme.iMic : Theme.iMicOff
            value: flick.inp ? flick.inp.volume : 0
            muted: flick.inp ? flick.inp.muted : false
            onMoved: v => { if (flick.inp) flick.inp.volume = v }
            onIconClicked: if (flick.inp) flick.inp.muted = !flick.inp.muted
        }

        SectionLabel { text: "output"; count: String(flick.sinks.length); Layout.topMargin: 14 }
        Repeater {
            model: flick.sinks
            delegate: ListRow {
                required property var modelData
                icon: flick.sinkIcon(modelData)
                title: flick.label(modelData)
                subtitle: current ? "default" : ""
                current: Pipewire.defaultAudioSink === modelData
                trailing: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        SectionLabel { text: "input"; count: String(flick.sources.length); Layout.topMargin: 14 }
        Repeater {
            model: flick.sources
            delegate: ListRow {
                required property var modelData
                icon: Theme.iMic
                title: flick.label(modelData)
                subtitle: current ? "default" : ""
                current: Pipewire.defaultAudioSource === modelData
                trailing: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        SectionLabel { text: "apps"; count: String(flick.streams.length); Layout.topMargin: 14 }
        Lb {
            visible: flick.streams.length === 0
            Layout.leftMargin: 6
            text: "no app is playing"
            color: Theme.mute
        }
        Repeater {
            model: flick.streams
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                Lb {
                    Layout.leftMargin: 6
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    px: 10
                    text: (modelData.properties && modelData.properties["application.name"])
                          ? modelData.properties["application.name"] : flick.label(modelData)
                }
                SliderRow {
                    Layout.fillWidth: true
                    implicitHeight: 44
                    icon: Theme.volIcon(modelData.audio.volume, modelData.audio.muted)
                    value: modelData.audio.volume
                    muted: modelData.audio.muted
                    onMoved: v => modelData.audio.volume = v
                    onIconClicked: modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
        Item { Layout.preferredHeight: 4 }
    }
}
