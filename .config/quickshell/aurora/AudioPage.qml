import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
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

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 4

        SectionLabel { text: "output device" }
        Repeater {
            model: flick.sinks
            delegate: ListRow {
                required property var modelData
                icon: flick.sinkIcon(modelData)
                title: flick.label(modelData)
                subtitle: current ? "default output" : ""
                current: Pipewire.defaultAudioSink === modelData
                trailing: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }

        SectionLabel { text: "input device"; Layout.topMargin: 10 }
        Repeater {
            model: flick.sources
            delegate: ListRow {
                required property var modelData
                icon: Theme.iMic
                title: flick.label(modelData)
                subtitle: current ? "default input" : ""
                current: Pipewire.defaultAudioSource === modelData
                trailing: modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : ""
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }

        SectionLabel { text: "applications"; Layout.topMargin: 10 }
        Text {
            visible: flick.streams.length === 0
            text: "no apps playing audio"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            Layout.leftMargin: 10
        }
        Repeater {
            model: flick.streams
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 0
                Text {
                    Layout.leftMargin: 4
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (modelData.properties && modelData.properties["application.name"])
                          ? modelData.properties["application.name"] : flick.label(modelData)
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                }
                SliderRow {
                    Layout.fillWidth: true
                    icon: Theme.volIcon(modelData.audio.volume, modelData.audio.muted)
                    value: modelData.audio.volume
                    muted: modelData.audio.muted
                    onMoved: v => modelData.audio.volume = v
                    onIconClicked: modelData.audio.muted = !modelData.audio.muted
                }
            }
        }
        Item { Layout.preferredHeight: 8 }
    }
}
