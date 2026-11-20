#!/usr/bin/env python3
"""Bluetooth pairing agent that asks through desktop notifications.

BlueZ needs an "agent" to confirm passkeys or ask for PINs while pairing. blueman-applet
used to be it; the Quickshell bar can pair devices but can't be one. This registers as
the default agent on the system bus and asks:

  - confirm a passkey (phones, laptops): notification with Pair / Cancel buttons
  - type a passkey on the device (keyboards): notification showing the number
  - enter a PIN (old devices): rofi prompt
  - a paired device asking for a service: accepted; unknown ones are asked

Uses Gio (python-gobject), no dbus-python. Started from the autostart in hyprland.lua.
"""
import sys

from gi.repository import Gio, GLib

AGENT_PATH = "/org/quickshell/btagent"
CAPABILITY = "KeyboardDisplay"
TIMEOUT_MS = 30000

XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg type="o" direction="in"/><arg type="u" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg type="o" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg type="o" direction="in"/><arg type="s" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""

bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
pending = []  # running notify-send / rofi processes, killed on Cancel


def device_prop(path, name):
    try:
        v = bus.call_sync("org.bluez", path, "org.freedesktop.DBus.Properties", "Get",
                          GLib.Variant("(ss)", ("org.bluez.Device1", name)),
                          GLib.VariantType("(v)"), Gio.DBusCallFlags.NONE, -1, None)
        return v.unpack()[0]
    except GLib.Error:
        return None


def device_name(path):
    return device_prop(path, "Alias") or device_prop(path, "Name") or path.rsplit("/", 1)[-1]


def run(argv, done):
    """Run argv, call done(stdout) when it exits (stdout '' on failure)."""
    proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE)
    pending.append(proc)

    def finished(p, res):
        try:
            _, out, _ = p.communicate_utf8_finish(res)
        except GLib.Error:
            out = ""
        if p in pending:
            pending.remove(p)
        done((out or "").strip())

    proc.communicate_utf8_async(None, None, finished)


def notify(summary, body, actions=None, wait=False, done=None):
    argv = ["notify-send", "-a", "Bluetooth", "-i", "bluetooth", "-t", str(TIMEOUT_MS)]
    for ident, label in actions or []:
        argv += ["-A", f"{ident}={label}"]
    if wait:
        argv.append("--wait")
    argv += [summary, body]
    run(argv, done or (lambda _out: None))


def reject(inv, why="Rejected"):
    inv.return_dbus_error(f"org.bluez.Error.{why}", why)


def ask_yes_no(inv, summary, body, yes="Pair"):
    def answered(out):
        if out == "yes":
            inv.return_value(None)
        else:
            reject(inv)
    notify(summary, body, [("yes", yes), ("no", "Cancel")], wait=True, done=answered)


def on_call(conn, sender, path, iface, method, params, inv):
    args = params.unpack()
    if method == "Release":
        inv.return_value(None)
        GLib.idle_add(loop.quit)
    elif method == "RequestConfirmation":
        dev, passkey = args
        ask_yes_no(inv, f"Pair with {device_name(dev)}?",
                   f"Check that {passkey:06d} is shown on the device.")
    elif method == "RequestAuthorization":
        dev = args[0]
        ask_yes_no(inv, f"Pair with {device_name(dev)}?", "The device asks to pair.")
    elif method == "AuthorizeService":
        dev, uuid = args
        if device_prop(dev, "Paired") or device_prop(dev, "Trusted"):
            inv.return_value(None)
        else:
            ask_yes_no(inv, f"Allow {device_name(dev)}?", f"It asks to use a service ({uuid}).", yes="Allow")
    elif method == "DisplayPasskey":
        dev, passkey, _entered = args
        notify(f"Pairing with {device_name(dev)}", f"Type {passkey:06d} on it, then press Enter.")
        inv.return_value(None)
    elif method == "DisplayPinCode":
        dev, pin = args
        notify(f"Pairing with {device_name(dev)}", f"Type {pin} on it, then press Enter.")
        inv.return_value(None)
    elif method in ("RequestPinCode", "RequestPasskey"):
        dev = args[0]

        def entered(out):
            if not out:
                reject(inv, "Canceled")
            elif method == "RequestPinCode":
                inv.return_value(GLib.Variant("(s)", (out,)))
            elif out.isdigit():
                inv.return_value(GLib.Variant("(u)", (int(out),)))
            else:
                reject(inv)
        run(["rofi", "-dmenu", "-p", f"PIN for {device_name(dev)}", "-lines", "0"], entered)
    elif method == "Cancel":
        for p in list(pending):
            p.force_exit()
        inv.return_value(None)
    else:
        inv.return_dbus_error("org.bluez.Error.Rejected", "Unknown method")


node = Gio.DBusNodeInfo.new_for_xml(XML)
bus.register_object(AGENT_PATH, node.interfaces[0], on_call, None, None)
try:
    for m in ("RegisterAgent", "RequestDefaultAgent"):
        params = GLib.Variant("(os)", (AGENT_PATH, CAPABILITY)) if m == "RegisterAgent" else GLib.Variant("(o)", (AGENT_PATH,))
        bus.call_sync("org.bluez", "/org/bluez", "org.bluez.AgentManager1", m, params,
                      None, Gio.DBusCallFlags.NONE, -1, None)
except GLib.Error as e:
    print(f"bt-agent: could not register with BlueZ: {e.message}", file=sys.stderr)
    sys.exit(1)

loop = GLib.MainLoop()
loop.run()
