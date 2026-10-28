import QtQuick
import QtQuick.Layouts

// Control panel > net (also the settings app's network section): wired / tethering, Wi-Fi radio + scan, networks.
// Click a row = connect (a new secured one asks for its password in a pill under it).
ColumnLayout {
    id: page
    property bool active: false
    onActiveChanged: Net.active = active
    // the settings app creates this page already active and destroys it when leaving the section
    Component.onCompleted: if (active) Net.active = true
    Component.onDestruction: if (active) Net.active = false
    spacing: 10

    // wired / usb tethering (read-only status, plus a disconnect button)
    ColumnLayout {
        visible: Net.wiredDevs.length > 0
        Layout.fillWidth: true
        spacing: 4
        SectionLabel { text: "wired" }
        Repeater {
            model: Net.wiredDevs
            delegate: ListRow {
                required property var modelData
                icon: modelData.usb ? Theme.iPhone : Theme.iEthernet
                title: modelData.name
                subtitle: Net.portal && Net.portalNet === modelData.name ? "sign in required"
                          : modelData.dev + (modelData.ip !== "" ? " · " + modelData.ip : "")
                trailing: modelData.usb ? "usb" : ""
                current: true
                IconBtn {
                    visible: Net.portal && Net.portalNet === modelData.name
                    icon: Theme.iLogin
                    implicitHeight: 32
                    onClicked: Net.openPortal()
                }
                IconBtn {
                    icon: Theme.iClose
                    implicitHeight: 32
                    onClicked: Net.disconnectDev(modelData.dev)
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 6
        spacing: 8
        Lb {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: !Net.wifiEnabled ? "wi-fi · off"
                  : (Net.connected !== "" ? "wi-fi · " + Net.connected : "wi-fi · not connected")
            color: Net.connected !== "" && Net.wifiEnabled ? Theme.fg : Theme.grey
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

    Lb {
        visible: Net.message !== ""
        Layout.fillWidth: true
        Layout.leftMargin: 6
        text: Net.message
        wrapMode: Text.WordWrap
        px: 10
        color: Theme.err
    }

    SectionLabel { text: Net.busy ? "working…" : "networks"; count: Net.busy || !Net.wifiEnabled ? "" : String(Net.networks.length) }

    Flickable {
        id: flick
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: list.implicitHeight
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
                    spacing: 4

                    ListRow {
                        id: row
                        icon: Theme.wifiIcon(item.modelData.signal)
                        title: item.modelData.ssid
                        readonly property bool portal: item.modelData.inUse && Net.portal && Net.portalNet === item.modelData.ssid
                        subtitle: portal ? "sign in required"
                                  : item.modelData.inUse ? "connected"
                                  : (item.modelData.saved ? "saved"
                                  : (item.modelData.security === "" ? "open" : item.modelData.security))
                        trailing: item.modelData.signal + "%"
                        current: item.modelData.inUse
                        onClicked: Net.connectTo(item.modelData)

                        IconBtn {
                            visible: row.portal
                            icon: Theme.iLogin
                            implicitHeight: 32
                            onClicked: Net.openPortal()
                        }
                        IconBtn {
                            visible: item.modelData.inUse
                            icon: Theme.iClose
                            implicitHeight: 32
                            onClicked: Net.disconnect()
                        }
                        IconBtn {
                            visible: item.modelData.saved
                            icon: Theme.iTrash
                            implicitHeight: 32
                            onClicked: Net.forget(item.modelData.ssid)
                        }
                    }

                    // password for a new secured network: a pill with white dots and the accent caret
                    Rectangle {
                        id: pwBox
                        visible: Net.askFor === item.modelData.ssid
                        Layout.fillWidth: true
                        Layout.preferredHeight: visible ? 52 : 0
                        radius: height / 2
                        color: Theme.s2
                        border.width: 1
                        border.color: pw.activeFocus ? Theme.fill : Theme.s3
                        onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }

                        TextInput {
                            id: pw
                            anchors.left: parent.left
                            anchors.leftMargin: 22
                            anchors.right: go.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            echoMode: TextInput.Password
                            passwordCharacter: "•"
                            color: Theme.fg
                            selectionColor: Theme.fill
                            selectedTextColor: Theme.fillFg
                            font.family: Theme.mono
                            font.pixelSize: 15
                            font.letterSpacing: 2
                            clip: true
                            cursorDelegate: Rectangle {
                                width: 2
                                color: Theme.live
                                visible: pw.activeFocus
                                Timer {
                                    running: pw.activeFocus
                                    interval: 500
                                    repeat: true
                                    onTriggered: parent.opacity = 1 - parent.opacity
                                }
                            }
                            onAccepted: Net.connect(item.modelData.ssid, text)
                            Lb {
                                visible: !pw.text
                                anchors.verticalCenter: parent.verticalCenter
                                text: "password"
                                color: Theme.mute
                            }
                        }
                        IconBtn {
                            id: go
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: 40
                            icon: Theme.iCheck
                            active: pw.text !== ""
                            onClicked: Net.connect(item.modelData.ssid, pw.text)
                        }
                    }
                }
            }
        }
    }
}
