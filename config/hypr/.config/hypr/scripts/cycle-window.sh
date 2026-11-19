#!/usr/bin/env bash
# Cycle focus between windows of the current workspace. Usage: cycle-window.sh next|prev
# Debounced: one trackpad swipe can fire the gesture several times, which would cycle
# through windows and land back on the same one.
set -u
state="${XDG_RUNTIME_DIR:-/tmp}/cycle-window.last"
now=$(date +%s%3N)
last=$(cat "$state" 2>/dev/null || echo 0)
(( now - last < 500 )) && exit 0
echo "$now" > "$state"

if [[ "${1:-next}" == "prev" ]]; then fwd=false; else fwd=true; fi
hyprctl dispatch "hl.dsp.window.cycle_next({ next = $fwd })" >/dev/null
hyprctl dispatch "hl.dsp.window.bring_to_top()" >/dev/null
