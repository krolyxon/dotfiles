pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Removable drives (udisks) and phones (gvfs MTP). `udevadm monitor` triggers a rescan; a device that
// wasn't there before gets a notification with mount/open buttons (notify-send -A prints the clicked one).
// Mounting goes through `mounter DEV|URI` (LUKS passphrase in the runner, chown offer, its own
// notifications), so mounts land in /run/media/$USER like everywhere else. Nothing is automounted.
Singleton {
    id: root

    // {key, dev, disk, label, size, fstype, mount, locked, luksParent}: one per filesystem on a hotplug disk
    property var drives: []
    // {key, uri, name, mounted, path}
    property var phones: []
    property bool scanned: false
    readonly property string gvfs: (Quickshell.env("XDG_RUNTIME_DIR") || "/run/user/1000") + "/gvfs/"

    function title(d) { return d.label !== "" ? d.label : d.dev.replace("/dev/", "") }
    function phonePath(uri) { return gvfs + "mtp:host=" + uri.replace(/^mtp:\/\//, "").replace(/\/$/, "") }

    function rescan() { if (!scanProc.running) scanProc.running = true; else again.restart() }

    // ---- actions
    function mount(key, thenOpen) {
        run(["mounter", key], "", () => { if (thenOpen) openLater.key = key })
    }
    // a LUKS key (/dev/sda2) also matches its unlocked mapper, whose row replaces it after mounting
    function open(key) {
        for (var i = 0; i < drives.length; i++)
            if ((drives[i].key === key || drives[i].luksParent === key) && drives[i].mount !== "") { xdgOpen(drives[i].mount); return true }
        for (i = 0; i < phones.length; i++)
            if (phones[i].key === key && phones[i].mounted) { xdgOpen(phones[i].path); return true }
        return false
    }
    function xdgOpen(path) { Session.launch(["xdg-open", path]) }
    // unmount this filesystem and lock its LUKS container; the disk stays powered, so it can be mounted again
    function eject(key) {
        if (key.indexOf("mtp://") === 0) {
            run(["gio", "mount", "-u", key], "phone unmounted, safe to unplug", null)
            return
        }
        var d = null, steps = []
        for (var i = 0; i < drives.length; i++) if (drives[i].key === key) d = drives[i]
        if (!d) return
        if (d.mount !== "") steps.push("u:" + d.dev)
        if (d.luksParent !== "") steps.push("l:" + d.luksParent)
        if (steps.length === 0) return
        run(["sh", "-c", 'for a; do case $a in u:*) udisksctl unmount -b "${a#u:}" ;; l:*) udisksctl lock -b "${a#l:}" ;;'
             + ' esac >/dev/null || exit; done', "sh"].concat(steps),
            title(d) + (d.luksParent !== "" ? " locked" : " unmounted"), null)
    }
    // anything on the disk still mounted or unlocked
    function diskBusy(disk) {
        for (var i = 0; i < drives.length; i++)
            if (drives[i].disk === disk && (drives[i].mount !== "" || drives[i].luksParent !== "")) return true
        return false
    }
    // power the disk off (an image: detach it). It disappears until replugged.
    function powerOff(disk) {
        if (diskBusy(disk)) return
        run(["udisksctl", disk.indexOf("/dev/loop") === 0 ? "loop-delete" : "power-off", "-b", disk],
            "safe to unplug " + disk, null)
    }

    // run a command, notify its error output on failure (or `okMsg` on success), rescan
    function run(cmd, okMsg, then) {
        var p = runC.createObject(root, { cmd: cmd, okMsg: okMsg, then: then })
        p.running = true
    }
    Component {
        id: runC
        Process {
            id: rp
            property var cmd: []
            property string okMsg: ""
            property var then: null
            command: ["sh", "-c", 'out=$("$@" 2>&1); rc=$?; printf "%s\\n%d" "$out" "$rc"', "sh"].concat(cmd)
            stdout: StdioCollector {
                onStreamFinished: {
                    var l = text.split("\n"), rc = parseInt(l.pop())
                    if (rc !== 0 && rp.cmd[0] !== "mounter")   // mounter notifies its own errors
                        Quickshell.execDetached(["notify-send", "-a", "aurora", "-u", "critical", "-i", "drive-removable-media",
                                                 "device", l.join("\n").trim() || ("failed: " + rp.cmd.join(" "))])
                    else if (rc === 0 && rp.okMsg !== "")
                        Quickshell.execDetached(["notify-send", "-a", "aurora", "-i", "drive-removable-media", "device", rp.okMsg])
                    if (rc === 0 && rp.then) rp.then()
                    root.rescan()
                    rp.destroy()
                }
            }
        }
    }
    // open after mount: wait for the rescan that follows it
    QtObject {
        id: openLater
        property string key: ""
    }
    onDrivesChanged: if (openLater.key !== "" && open(openLater.key)) openLater.key = ""
    onPhonesChanged: if (openLater.key !== "" && open(openLater.key)) openLater.key = ""

    // ---- "new device" notification with buttons
    function announce(kind, key, text) {
        var acts = kind === "locked" ? ["-A", "mount=unlock"] : ["-A", "open=open", "-A", "mount=mount"]
        var p = askC.createObject(root, { key: key })
        p.command = ["notify-send", "-a", "aurora", "-i", kind === "phone" ? "phone" : "drive-removable-media"]
                    .concat(acts, [kind === "phone" ? "phone connected" : "drive connected", text])
        p.running = true
    }
    Component {
        id: askC
        Process {
            id: ap
            property string key: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    var a = text.trim()
                    if (a === "open") root.mount(ap.key, true)
                    else if (a === "mount") root.mount(ap.key, false)
                    ap.destroy()
                }
            }
        }
    }

    // ---- scanning
    Process {
        id: udev
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=block", "--subsystem-match=usb"]
        running: true
        stdout: SplitParser { onRead: _ => { debounce.restart(); late.restart() } }
    }
    Timer { id: debounce; interval: 700; onTriggered: root.rescan() }
    Timer { id: late; interval: 3000; onTriggered: root.rescan() }      // gvfs sees phones a bit later
    Timer { id: again; interval: 300; onTriggered: root.rescan() }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.rescan() }   // mounts done elsewhere

    Process {
        id: scanProc
        command: ["sh", "-c", "lsblk -Jpo NAME,TYPE,FSTYPE,SIZE,LABEL,MOUNTPOINT,HOTPLUG,RM; echo '\x1e'; "
                  + "gio mount -li 2>/dev/null; echo '\x1e'; gio mount -l 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }

    function truthy(v) { return v === true || v === "1" }
    function parse(text) {
        var parts = text.split("\x1e\n")
        if (parts.length < 3) return
        var nd = [], np = []
        var skip = ["swap", "LVM2_member", "linux_raid_member"], types = ["part", "disk", "rom", "crypt", "loop"]
        function walk(n, disk, hot, luks) {
            disk = disk || n.name
            hot = hot || truthy(n.hotplug) || truthy(n.rm) || n.type === "loop"   // loop: attached images (udisksctl loop-setup)
            var kids = n.children || []
            var isLuks = n.fstype === "crypto_LUKS"
            if (hot && n.fstype && types.indexOf(n.type) >= 0 && skip.indexOf(n.fstype) < 0 && !(isLuks && kids.length)) {
                nd.push({ key: n.name, dev: n.name, disk: disk, label: n.label || "", size: n.size || "",
                          fstype: (n.fstype || "").replace("crypto_", ""), mount: n.mountpoint || "",
                          locked: isLuks, luksParent: luks })
            }
            for (var i = 0; i < kids.length; i++) walk(kids[i], disk, hot, isLuks ? n.name : luks)
        }
        try {
            var bd = JSON.parse(parts[0]).blockdevices || []
            for (var i = 0; i < bd.length; i++) walk(bd[i], "", false, "")
        } catch (e) { return }

        // phones: "Volume(0): Pixel 7" ... "activation_root=mtp://Google_Pixel_7_XXXX/"; mounted ones: "Mount(0): Pixel 7 -> mtp://..."
        var name = "", l = parts[1].split("\n")
        for (i = 0; i < l.length; i++) {
            var m = l[i].match(/^\s*Volume\(\d+\): (.*)$/)
            if (m) { name = m[1]; continue }
            m = l[i].match(/^\s*activation_root=(mtp:\/\/.*)$/)
            if (m) np.push({ key: m[1], uri: m[1], name: name, mounted: false, path: phonePath(m[1]) })
        }
        l = parts[2].split("\n")
        for (i = 0; i < l.length; i++) {
            m = l[i].match(/-> (mtp:\/\/\S*)/)
            if (!m) continue
            for (var j = 0; j < np.length; j++) if (np[j].uri === m[1]) np[j].mounted = true
        }

        if (scanned) {
            var old = {}
            for (i = 0; i < drives.length; i++) old[drives[i].key] = true
            for (i = 0; i < phones.length; i++) old[phones[i].key] = true
            for (i = 0; i < nd.length; i++) {
                var d = nd[i]
                if (old[d.key] || d.mount !== "") continue
                announce(d.locked ? "locked" : "drive", d.key,
                         title(d) + "  " + d.size + "  (" + d.fstype + ")" + (d.locked ? ", encrypted" : ""))
            }
            for (i = 0; i < np.length; i++)
                if (!old[np[i].key] && !np[i].mounted) announce("phone", np[i].key, np[i].name)
        }
        if (JSON.stringify(nd) !== JSON.stringify(drives)) drives = nd
        if (JSON.stringify(np) !== JSON.stringify(phones)) phones = np
        scanned = true
    }
}
