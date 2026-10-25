import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// Prompt for the auth agents (Agents): a polkit password (Agents.flow) or a bluetooth pairing request
// (Agents.bt: confirm a passkey, type a PIN/passkey, or show one to type on the device). Polkit wins
// if both are pending. Overlay layer with exclusive keyboard on the focused monitor; Enter accepts,
// Esc cancels. Typed text is cleared after every attempt, never logged.
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
    implicitWidth: 420
    implicitHeight: col.implicitHeight + 32
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
        function onAuthenticationFailed() { win.error = "wrong password, try again"; win.reset() }
    }

    // keyboard for the button-only bluetooth prompts
    Item {
        id: keys
        Keys.onReturnPressed: win.accept()
        Keys.onEnterPressed: win.accept()
        Keys.onEscapePressed: win.cancel()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bgA
        border.width: 2
        border.color: win.error !== "" || (win.mode === "polkit" && win.flow && win.flow.supplementaryIsError) ? Theme.err : Theme.accent

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: win.mode === "bt" ? Theme.iBt : Theme.iLock
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 8
                }
                SectionLabel {
                    Layout.fillWidth: true
                    text: win.mode === "bt" ? "bluetooth pairing" : "authentication required"
                }
            }
            Text {
                Layout.fillWidth: true
                color: Theme.fg
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: {
                    if (win.mode === "polkit") return win.flow ? win.flow.message : ""
                    if (!win.bt) return ""
                    var a = win.bt.alias
                    switch (win.btMethod) {
                    case "RequestConfirmation": return "pair with " + a + "? check that it shows the same code:"
                    case "RequestPinCode": return "enter the PIN for " + a + " (often 0000 or 1234)"
                    case "RequestPasskey": return "enter the 6-digit passkey shown on " + a
                    case "DisplayPasskey":
                    case "DisplayPinCode": return "type this code on " + a + ", then press Enter there:"
                    case "RequestAuthorization": return "allow " + a + " to pair with this computer?"
                    case "AuthorizeService": return "allow " + a + " to use a service?"
                    }
                    return a
                }
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: win.mode === "polkit" ? (win.flow ? win.flow.actionId : "")
                      : (win.btMethod === "AuthorizeService" ? win.bt.uuid : "")
                color: Theme.dim
                elide: Text.ElideMiddle
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }

            // bluetooth passkey / PIN to compare or type on the device
            Text {
                Layout.fillWidth: true
                visible: win.mode === "bt" && win.btCode !== "" && !win.btInput
                horizontalAlignment: Text.AlignHCenter
                text: win.btCode
                color: Theme.accent
                font.family: Theme.font
                font.pixelSize: Theme.fontSize * 3
                font.bold: true
            }

            // more than one admin: pick who authenticates
            Flow {
                Layout.fillWidth: true
                visible: win.mode === "polkit" && win.flow !== null && win.flow.identities.length > 1
                spacing: 4
                Repeater {
                    model: win.mode === "polkit" && win.flow ? win.flow.identities : []
                    delegate: IconBtn {
                        required property var modelData
                        implicitHeight: 24
                        label: modelData.displayName || String(modelData)
                        active: win.flow && win.flow.selectedIdentity === modelData
                        onClicked: win.flow.selectedIdentity = modelData
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: win.needsInput
                implicitHeight: 32
                color: Theme.surface
                border.width: 1
                border.color: pass.activeFocus ? Theme.accent : Theme.line
                Text {
                    id: promptTxt
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: win.mode === "bt" ? (win.btMethod === "RequestPinCode" ? "PIN" : "passkey")
                          : (win.flow && win.flow.inputPrompt !== "" ? win.flow.inputPrompt.replace(/:\s*$/, "") : "password")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
                TextInput {
                    id: pass
                    anchors.fill: parent
                    anchors.leftMargin: promptTxt.implicitWidth + 22
                    anchors.rightMargin: 10
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: win.mode === "bt" || (win.flow && win.flow.responseVisible) ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    maximumLength: win.btMethod === "RequestPasskey" ? 6 : 256
                    validator: RegularExpressionValidator {
                        regularExpression: win.btMethod === "RequestPasskey" ? /[0-9]*/ : /.*/
                    }
                    enabled: !win.waiting
                    clip: true
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Keys.onReturnPressed: win.accept()
                    Keys.onEnterPressed: win.accept()
                    Keys.onEscapePressed: win.cancel()
                }
            }
            Text {
                Layout.fillWidth: true
                visible: win.mode === "polkit" && text !== ""
                text: win.waiting ? "checking…" : (win.error !== "" ? win.error : (win.flow ? win.flow.supplementaryMessage : ""))
                color: !win.waiting && (win.error !== "" || (win.flow && win.flow.supplementaryIsError)) ? Theme.err : Theme.dim
                wrapMode: Text.Wrap
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Item { Layout.fillWidth: true }
                IconBtn {
                    visible: !win.btDisplay
                    label: win.mode === "bt" ? "reject" : "cancel"
                    implicitHeight: 26
                    onClicked: win.cancel()
                }
                IconBtn {
                    label: win.btDisplay ? "close" : (win.mode === "bt" ? (win.btInput ? "pair" : "allow") : "authenticate")
                    implicitHeight: 26
                    active: true
                    onClicked: win.accept()
                }
            }
        }
    }
}
