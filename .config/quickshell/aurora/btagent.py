#!/usr/bin/env python3
"""BlueZ pairing agent for aurora (Agents.qml runs it; Quickshell's Bluetooth module has none).

Exports org.bluez.Agent1 at /aurora/agent (capability KeyboardDisplay) and makes it the default
agent, again whenever bluetoothd restarts. Talks JSON lines:
  stdout  {"id": n, "method": "RequestConfirmation", "device": path, "alias": name, "passkey": "012345"}
          id 0 = display only (DisplayPasskey/DisplayPinCode), no reply expected
          {"event": "registered" | "cancel" | "error", "msg": ...}
  stdin   {"id": n, "ok": true|false, "value": "1234"}   (value for RequestPinCode/RequestPasskey)
Python stdlib + python-gobject only.
"""
import json
import sys

from gi.repository import Gio, GLib

PATH = "/aurora/agent"
XML = """<node><interface name="org.bluez.Agent1">
<method name="Release"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="Cancel"/>
</interface></node>"""

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
loop = GLib.MainLoop()
pending = {}  # id -> (invocation, method)
last_id = 0


def emit(**kw):
    print(json.dumps(kw), flush=True)


def dev_prop(path, name):
    try:
        v = bus.call_sync("org.bluez", path, "org.freedesktop.DBus.Properties", "Get",
                          GLib.Variant("(ss)", ("org.bluez.Device1", name)), GLib.VariantType("(v)"),
                          Gio.DBusCallFlags.NONE, 2000, None)
        return v.unpack()[0]
    except GLib.Error:
        return None


def alias(path):
    return dev_prop(path, "Alias") or path.rsplit("/", 1)[-1]


def ask(inv, method, dev, **extra):
    global last_id
    last_id += 1
    pending[last_id] = (inv, method)
    emit(id=last_id, method=method, device=dev, alias=alias(dev), **extra)


def on_call(conn, sender, path, iface, method, params, inv):
    a = params.unpack()
    if method == "Release":
        inv.return_value(None)
    elif method == "Cancel":
        for i, _ in pending.values():
            i.return_dbus_error("org.bluez.Error.Canceled", "cancelled")
        pending.clear()
        inv.return_value(None)
        emit(event="cancel")
    elif method == "DisplayPinCode":
        inv.return_value(None)
        emit(id=0, method=method, device=a[0], alias=alias(a[0]), pincode=a[1])
    elif method == "DisplayPasskey":
        inv.return_value(None)
        emit(id=0, method=method, device=a[0], alias=alias(a[0]), passkey="%06d" % a[1], entered=a[2])
    elif method == "AuthorizeService":
        # a device we already paired with / trust may use its services; anything else asks
        if dev_prop(a[0], "Paired") or dev_prop(a[0], "Trusted"):
            inv.return_value(None)
        else:
            ask(inv, method, a[0], uuid=a[1])
    elif method == "RequestConfirmation":
        ask(inv, method, a[0], passkey="%06d" % a[1])
    else:  # RequestPinCode, RequestPasskey, RequestAuthorization
        ask(inv, method, a[0])


def on_stdin(ch, cond):
    if cond & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    status, line, _, _ = ch.read_line()
    if status == GLib.IOStatus.EOF:
        loop.quit()
        return False
    try:
        r = json.loads(line)
    except (TypeError, ValueError):
        return True
    item = pending.pop(r.get("id"), None)
    if not item:
        return True
    inv, method = item
    if not r.get("ok"):
        inv.return_dbus_error("org.bluez.Error.Rejected", "rejected")
        return True
    v = r.get("value", "")
    try:
        if method == "RequestPinCode":
            inv.return_value(GLib.Variant("(s)", (str(v),)))
        elif method == "RequestPasskey":
            n = int(v)
            if not 0 <= n <= 999999:
                raise ValueError
            inv.return_value(GLib.Variant("(u)", (n,)))
        else:
            inv.return_value(None)
    except ValueError:
        inv.return_dbus_error("org.bluez.Error.Rejected", "bad value")
    return True


def register(*_):
    try:
        for m, args in (("RegisterAgent", GLib.Variant("(os)", (PATH, "KeyboardDisplay"))),
                        ("RequestDefaultAgent", GLib.Variant("(o)", (PATH,)))):
            bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", m, args, None,
                          Gio.DBusCallFlags.NONE, 5000, None)
        emit(event="registered")
    except GLib.Error as e:
        emit(event="error", msg=e.message)


def main():
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    bus.register_object_with_closures2(PATH, node.interfaces[0], on_call, None, None)
    Gio.bus_watch_name_on_connection(bus, "org.bluez", Gio.BusNameWatcherFlags.NONE, register, None)
    ch = GLib.IOChannel.unix_new(sys.stdin.fileno())
    GLib.io_add_watch(ch, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    loop.run()


if __name__ == "__main__":
    main()
