#!/usr/bin/env bash
# Lock the session with the Quickshell lock screen (modules/lock in the quickshell config).
# hypridle's lock_cmd, so `loginctl lock-session` (idle, lid, power menu, Super+Ctrl+Q) runs
# this. If Quickshell doesn't answer (not running, broken config), hyprlock locks instead:
# `qs ipc` exits 0 even when nothing handled the call, so check its answer.
if [[ $(timeout 3 qs ipc call lock lock 2>/dev/null) != locked ]]; then
    pidof hyprlock >/dev/null || hyprlock
fi
