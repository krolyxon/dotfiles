import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Prompt for the auth agents (Agents): a polkit password (Agents.flow) or a bluetooth pairing request
// (Agents.bt: confirm a passkey, type a PIN/passkey, or show one to type on the device). Polkit wins
// if both are pending. Overlay layer with exclusive keyboard on the focused monitor; Enter accepts,
// Esc cancels. Typed text is cleared after every attempt, never logged.
// Looks like glyph's lock surface (github.com/Nebelung-cloud/glyph-rice, GPL-3.0, lock/LockSurface.qml): a lock in a ring
// of dots, the password in a pill as dots with the live caret; a wrong password shakes it.
PanelWindow {
    id: win
    readonly property var flow: Agents.flow
    readonly property var bt: Agents.bt
    readonly property string mode: Agents.polkitActive ? "polkit" : (Agents.btActive ? "bt" : "")
    readonly property bool opened: mode !== ""
    readonly property string btMethod: bt ? bt.method : ""
    // bluetooth: what the field / big code shows
    readonly property bool btInput: btMethod === "RequestPinCode" || btMethod === "RequestPasskey"
    readonly property string btCode: !bt ? "" : (bt.passkey ? bt.passkey.slice(0, 3) + " " + bt.passkey.slice(3) : (bt.pincode || ""))
    readonly property bool btDisplay: btMethod === "DisplayPasskey" || btMethod === "DisplayPinCode"
    readonly property bool needsInput: mode === "polkit" || btInput

    visible: opened
    implicitWidth: 480
    implicitHeight: col.implicitHeight + 60
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aurora-auth"
    WlrLayershell.keyboardFocus: opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property bool waiting: false      // submitted, polkit is checking
    property string error: ""         // Quickshell doesn't put failures in supplementaryMessage
    function reset() { pass.text = ""; waiting = false; if (needsInput) pass.forceActiveFocus(); else keys.forceActiveFocus() }
    function accept() {
        if (mode === "polkit") {
            if (!flow || !flow.isResponseRequired || waiting) return
            waiting = true
            error = ""
            flow.submit(pass.text)
            pass.text = ""
        } else if (mode === "bt") {
            if (btInput && pass.text === "") return
            Agents.btReply(true, pass.text)
            pass.text = ""
        }
    }
    function cancel() {
        if (mode === "polkit") { if (flow) flow.cancelAuthenticationRequest() }
        else if (mode === "bt") Agents.btReply(false)
    }

    onModeChanged: if (opened) { error = ""; reset() }
    onBtChanged: if (bt) reset()
    Connections {
        target: win.flow
        function onIsResponseRequiredChanged() { if (win.flow.isResponseRequired) win.reset() }
        // polkit asks again right after a failure (isResponseRequired goes true with failed set)
        function onAuthenticationFailed() { win.error = "wrong password, try again"; shake.restart(); win.reset() }
    }

    // keyboard for the button-only bluetooth prompts
    Item {
        id: keys
        Keys.onReturnPressed: win.accept()
        Keys.onEnterPressed: win.accept()
        Keys.onEscapePressed: win.cancel()
    }

    readonly property bool bad: win.error !== "" || (win.mode === "polkit" && win.flow && win.flow.supplementaryIsError)

    Rectangle {
        anchors.fill: parent
        radius: 36
        color: Theme.s1
        border.width: 1
        border.color: win.bad ? Theme.err : Theme.s2

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 30
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                Item {   // the lock / bluetooth glyph in a ring of dots
                    width: 64
                    height: 64
                    Ring { anchors.fill: parent; anchors.margins: 3; n: 24; dot: 3.5; on: win.bad ? Theme.err : Theme.fill }
                    Icon {
                        anchors.centerIn: parent
                        text: win.mode === "bt" ? Theme.iBt : Theme.iLock
                        font.pixelSize: 24
                        color: win.bad ? Theme.err : Theme.fg
                    }
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Lb { text: win.mode === "bt" ? "bluetooth pairing" : "authentication" }
                    Text {
                        width: parent.width
                        text: win.mode === "bt" ? (win.bt ? win.bt.alias : "") : "Required"
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.ui
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                color: Theme.fgDim
                wrapMode: Text.Wrap
                font.family: Theme.ui
                font.pixelSize: 15
                text: {
                    if (win.mode === "polkit") return win.flow ? win.flow.message : ""
                    if (!win.bt) return ""
                    var a = win.bt.alias
                    switch (win.btMethod) {
                    case "RequestConfirmation": return "Pair with " + a + "? Check that it shows the same code:"
                    case "RequestPinCode": return "Enter the PIN for " + a + " (often 0000 or 1234)"
                    case "RequestPasskey": return "Enter the 6-digit passkey shown on " + a
                    case "DisplayPasskey":
                    case "DisplayPinCode": return "Type this code on " + a + ", then press Enter there:"
                    case "RequestAuthorization": return "Allow " + a + " to pair with this computer?"
                    case "AuthorizeService": return "Allow " + a + " to use a service?"
                    }
                    return a
                }
            }
            Lb {
                Layout.fillWidth: true
                visible: text !== ""
                px: 10
                color: Theme.mute
                elide: Text.ElideMiddle
                text: win.mode === "polkit" ? (win.flow ? win.flow.actionId : "")
                      : (win.btMethod === "AuthorizeService" ? win.bt.uuid : "")
            }

            // bluetooth passkey / PIN to compare or type on the device
            Num {
                Layout.alignment: Qt.AlignHCenter
                visible: win.mode === "bt" && win.btCode !== "" && !win.btInput
                text: win.btCode
                font.pixelSize: 64
                color: Theme.fill
            }

            // more than one admin: pick who authenticates
            Flow {
                Layout.fillWidth: true
                visible: win.mode === "polkit" && win.flow !== null && win.flow.identities.length > 1
                spacing: 4
                Repeater {
                    model: win.mode === "polkit" && win.flow ? win.flow.identities : []
                    delegate: Chip {
                        required property var modelData
                        text: modelData.displayName || String(modelData)
                        selected: win.flow && win.flow.selectedIdentity === modelData
                        onClicked: win.flow.selectedIdentity = modelData
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                visible: win.needsInput
                implicitHeight: 56
                Rectangle {
                    id: field
                    width: parent.width
                    height: parent.height
                    radius: height / 2
                    color: Theme.s2
                    border.width: 1
                    border.color: win.bad ? Theme.err : pass.activeFocus ? Theme.fill : Theme.s3
                    SequentialAnimation on x {
                        id: shake
                        running: false
                        NumberAnimation { to: -12; duration: 50 }
                        NumberAnimation { to: 12; duration: 70 }
                        NumberAnimation { to: -8; duration: 70 }
                        NumberAnimation { to: 6; duration: 60 }
                        NumberAnimation { to: 0; duration: 50 }
                    }
                    Lb {
                        id: promptTxt
                        x: 22
                        anchors.verticalCenter: parent.verticalCenter
                        text: win.mode === "bt" ? (win.btMethod === "RequestPinCode" ? "pin" : "passkey")
                              : (win.flow && win.flow.inputPrompt !== "" ? win.flow.inputPrompt.replace(/:\s*$/, "") : "password")
                    }
                    TextInput {
                        id: pass
                        anchors.left: promptTxt.right
                        anchors.leftMargin: 16
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: win.mode === "bt" || (win.flow && win.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        maximumLength: win.btMethod === "RequestPasskey" ? 6 : 256
                        validator: RegularExpressionValidator {
                            regularExpression: win.btMethod === "RequestPasskey" ? /[0-9]*/ : /.*/
                        }
                        enabled: !win.waiting
                        clip: true
                        color: Theme.fg
                        selectionColor: Theme.fill
                        selectedTextColor: Theme.fillFg
                        font.family: Theme.mono
                        font.pixelSize: 16
                        font.letterSpacing: 3
                        cursorDelegate: Rectangle {
                            width: 2
                            color: Theme.live
                            visible: pass.activeFocus
                            Timer { running: pass.activeFocus; interval: 500; repeat: true; onTriggered: parent.opacity = 1 - parent.opacity }
                        }
                        Keys.onReturnPressed: win.accept()
                        Keys.onEnterPressed: win.accept()
                        Keys.onEscapePressed: win.cancel()
                    }
                }
            }
            Lb {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                visible: win.mode === "polkit" && text !== ""
                px: 10
                wrapMode: Text.Wrap
                text: win.waiting ? "checking…" : (win.error !== "" ? win.error : (win.flow ? win.flow.supplementaryMessage : ""))
                color: !win.waiting && win.bad ? Theme.err : Theme.grey
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Item { Layout.fillWidth: true }
                IconBtn {
                    visible: !win.btDisplay
                    label: win.mode === "bt" ? "reject" : "cancel"
                    implicitHeight: 44
                    onClicked: win.cancel()
                }
                IconBtn {
                    label: win.btDisplay ? "close" : (win.mode === "bt" ? (win.btInput ? "pair" : "allow") : "authenticate")
                    implicitHeight: 44
                    active: true
                    onClicked: win.accept()
                }
            }
        }
    }
}
