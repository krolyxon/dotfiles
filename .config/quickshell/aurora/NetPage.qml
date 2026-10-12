import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page
    property bool active: false
    onActiveChanged: Net.active = active
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: !Net.wifiEnabled ? "wi-fi is off"
                  : (Net.connected !== "" ? "connected  ·  " + Net.connected : "not connected")
            color: Net.connected !== "" && Net.wifiEnabled ? Theme.accent : Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
        IconBtn {
            icon: Theme.iRefresh
            active: Net.scanning
            onClicked: Net.rescan()
        }
        IconBtn {
            icon: Net.wifiEnabled ? Theme.iWifi : Theme.iWifiOff
            active: Net.wifiEnabled
            onClicked: Net.setWifi(!Net.wifiEnabled)
        }
    }

    Text {
        visible: Net.message !== ""
        Layout.fillWidth: true
        text: Net.message
        wrapMode: Text.WordWrap
        color: Theme.err
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
    }

    SectionLabel { text: Net.busy ? "working…" : "networks" }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        contentWidth: width
        contentHeight: list.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: list
            width: flick.width
            spacing: 2

            Repeater {
                model: Net.wifiEnabled ? Net.networks : []
                delegate: ColumnLayout {
                    id: item
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    ListRow {
                        icon: Theme.wifiIcon(item.modelData.signal)
                        title: item.modelData.ssid
                        subtitle: item.modelData.inUse ? "connected"
                                  : (item.modelData.saved ? "saved"
                                  : (item.modelData.security === "" ? "open" : item.modelData.security))
                        trailing: item.modelData.signal + "%"
                        current: item.modelData.inUse
                        onClicked: Net.connectTo(item.modelData)

                        IconBtn {
                            visible: item.modelData.inUse
                            icon: Theme.iClose
                            height: 26
                            onClicked: Net.disconnect()
                        }
                        IconBtn {
                            visible: item.modelData.saved
                            icon: Theme.iTrash
                            height: 26
                            onClicked: Net.forget(item.modelData.ssid)
                        }
                    }

                    Rectangle {
                        id: pwBox
                        visible: Net.askFor === item.modelData.ssid
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 34 : 0
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.accent
                        onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 4
                            TextInput {
                                id: pw
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.fg
                                selectionColor: Theme.accent
                                selectedTextColor: Theme.bg
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                clip: true
                                onAccepted: Net.connect(item.modelData.ssid, text)
                                Text {
                                    visible: !pw.text
                                    text: "password…"
                                    color: Theme.dim
                                    font: pw.font
                                }
                            }
                            IconBtn {
                                icon: Theme.iCheck
                                height: 26
                                onClicked: Net.connect(item.modelData.ssid, pw.text)
                            }
                        }
                    }
                }
            }
        }
    }
}
