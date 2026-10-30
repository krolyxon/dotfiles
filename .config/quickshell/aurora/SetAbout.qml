import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// Settings app > About: what this machine is (one shell probe on open) + live memory / disks from SysStats.
Flickable {
    id: flick
    clip: true
    contentWidth: width
    contentHeight: col.implicitHeight
    boundsBehavior: Flickable.StopAtBounds

    property var info: []             // [[label, value]]
    function size(v) { return v >= 1000 ? (v / 1024).toFixed(1) + "T" : (v >= 100 ? Math.round(v) : v.toFixed(1)) + "G" }

    Process {
        running: true
        command: ["sh", "-c", [
            '. /etc/os-release 2>/dev/null; printf "system\\t%s\\n" "${PRETTY_NAME:-Linux}"',
            'printf "kernel\\t%s\\n" "$(uname -r)"',
            'printf "host\\t%s\\n" "$(cat /etc/hostname 2>/dev/null || uname -n)"',
            'printf "machine\\t%s\\n" "$(cat /sys/class/dmi/id/product_version 2>/dev/null) ($(cat /sys/class/dmi/id/product_name 2>/dev/null))"',
            'printf "cpu\\t%s (%s threads)\\n" "$(sed -n "s/^model name[^:]*: //p" /proc/cpuinfo | head -1)" "$(nproc)"',
            'command -v lspci >/dev/null && lspci | sed -n "s/.*\\(VGA\\|3D\\)[^:]*: //p" | sed "s/ (rev .*//" | while read -r g; do printf "gpu\\t%s\\n" "$g"; done',
            'printf "hyprland\\t%s\\n" "$(hyprctl version -j 2>/dev/null | sed -n "s/.*\\"tag\\": \\"\\([^\\"]*\\)\\".*/\\1/p")"',
            'printf "quickshell\\t%s\\n" "$(qs --version 2>/dev/null | head -1 | sed "s/^Quickshell //; s/ (.*//")"',
            'printf "shell\\t%s\\n" "$(basename "${SHELL:-sh}")"',
            'command -v pacman >/dev/null && printf "packages\\t%s (pacman)\\n" "$(pacman -Qq | wc -l)"'
        ].join("; ")]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [], l = text.split("\n")
                for (var i = 0; i < l.length; i++) {
                    var t = l[i].indexOf("\t")
                    if (t > 0) out.push([l[i].slice(0, t), l[i].slice(t + 1)])
                }
                flick.info = out
            }
        }
    }

    ColumnLayout {
        id: col
        width: flick.width
        spacing: 8

        RowLayout {
            spacing: 14
            Text {
                text: Theme.iArch
                color: Theme.fill
                font.family: Theme.ui
                font.pixelSize: 56
            }
            ColumnLayout {
                spacing: 2
                Text {
                    text: flick.info.length ? flick.info[0][1] : ""
                    color: Theme.fg
                    font.family: Theme.ui
                    font.pixelSize: 21
                    font.bold: true
                }
                Text {
                    text: Quickshell.env("USER") + "@" + (flick.info.length > 2 ? flick.info[2][1] : "")
                        + "  ·  up " + Theme.fmtTime(SysStats.uptime)
                    color: Theme.fgDim
                    font.family: Theme.ui
                    font.pixelSize: 15
                }
            }
        }

        SectionLabel { text: "system"; keywords: "kernel cpu gpu host hostname distro packages version uptime"; Layout.topMargin: 6 }
        Repeater {
            model: flick.info
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.preferredWidth: 150
                    text: modelData[0]
                    color: Theme.fill
                    font.family: Theme.ui
                    font.pixelSize: 15
                }
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 18
                    text: modelData[1]
                    color: Theme.fg
                    elide: Text.ElideRight
                    font.family: Theme.ui
                    font.pixelSize: 15
                }
            }
        }

        SectionLabel { text: "memory & storage"; keywords: "ram disk space drives usage"; Layout.topMargin: 6 }
        StatBar {
            label: "memory"
            frac: SysStats.memTotal > 0 ? SysStats.memUsed / SysStats.memTotal : 0
            valueText: flick.size(SysStats.memUsed) + " / " + flick.size(SysStats.memTotal)
        }
        Repeater {
            model: SysStats.disks
            delegate: StatBar {
                required property var modelData
                label: modelData.label
                frac: modelData.used / modelData.size
                fill: frac > 0.9 ? Theme.err : Theme.fill
                valueText: flick.size(modelData.used) + " / " + flick.size(modelData.size)
            }
        }

        SectionLabel { text: "credits"; keywords: "license glyph-rice fonts"; Layout.topMargin: 6 }
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            wrapMode: Text.WordWrap
            lineHeight: 1.3
            color: Theme.fgDim
            font.family: Theme.ui
            font.pixelSize: 14
            text: "The look follows Nothing OS through glyph-rice by Nebelung-cloud (GPL-3.0): its design language, "
                + "dot-matrix shaders and several components. Fonts: Doto, Space Grotesk, Space Mono (SIL OFL). "
                + "Colours: matugen (Material You). Nothing, Nothing OS and Glyph are trademarks of Nothing Technology Ltd; "
                + "this is a fan setup, not affiliated with Nothing."
        }
    }
}
