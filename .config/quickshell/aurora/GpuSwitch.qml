import QtQuick
import QtQuick.Layouts

// envycontrol mode buttons with the two-click arm (SysPage, settings app > Power)
ColumnLayout {
    id: root
    // two-click arm before switching (needs a reboot to apply)
    property string armedGpu: ""
    Timer { id: disarm; interval: 3000; onTriggered: root.armedGpu = "" }
    function gpuClick(m) {
        if (Gpu.mode === m || Gpu.busy) return
        if (armedGpu !== m) { armedGpu = m; disarm.restart(); return }
        armedGpu = ""
        Gpu.set(m)
    }
    visible: Gpu.mode !== ""
    Layout.fillWidth: true
    spacing: 8
    SectionLabel { text: "graphics  ·  envycontrol" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: ["integrated", "hybrid", "nvidia"]
            delegate: IconBtn {
                required property string modelData
                Layout.fillWidth: true
                icon: Theme.iGpu
                label: root.armedGpu === modelData ? "sure?" : modelData
                active: Gpu.mode === modelData
                opacity: Gpu.busy ? 0.5 : 1
                onClicked: root.gpuClick(modelData)
            }
        }
    }
    Text {
        visible: Gpu.pending !== "" || Gpu.message !== "" || Gpu.busy
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Gpu.message !== "" ? Theme.err : Theme.accent
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
        text: Gpu.busy ? "switching…" : (Gpu.message !== "" ? Gpu.message : "queued: " + Gpu.pending + "  ·  reboot to apply")
    }
}
