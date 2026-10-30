import QtQuick
import QtQuick.Layouts

// envycontrol mode pills with the two-click arm (SysPage, settings app > Power)
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
    spacing: 10
    SectionLabel { text: "graphics · envycontrol"; keywords: "gpu graphics mode nvidia hybrid integrated dgpu prime" }
    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: ["integrated", "hybrid", "nvidia"]
            delegate: IconBtn {
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: 44
                icon: Theme.iGpu
                label: root.armedGpu === modelData ? "sure?" : modelData
                active: Gpu.mode === modelData
                opacity: Gpu.busy ? 0.5 : 1
                onClicked: root.gpuClick(modelData)
            }
        }
    }
    Lb {
        visible: Gpu.pending !== "" || Gpu.message !== "" || Gpu.busy
        Layout.fillWidth: true
        Layout.leftMargin: 6
        wrapMode: Text.Wrap
        px: 10
        color: Gpu.message !== "" ? Theme.err : Theme.live
        text: Gpu.busy ? "switching…" : (Gpu.message !== "" ? Gpu.message : "queued: " + Gpu.pending + " · reboot to apply")
    }
}
