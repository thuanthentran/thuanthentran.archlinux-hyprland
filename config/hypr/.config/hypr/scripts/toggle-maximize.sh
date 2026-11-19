#!/usr/bin/env bash
# Maximize / restore the active window to fill the work area (below Waybar).
# Uses a real resize instead of Hyprland's "maximized" state, because maximized windows
# are drawn below floating ones, which breaks window switching.
set -eu
state="${XDG_RUNTIME_DIR:-/tmp}/toggle-maximize"
mkdir -p "$state"

read -r addr floating x y w h < <(hyprctl -j activewindow | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(d.get("address", ""), int(d.get("floating", False)), *d["at"], *d["size"])') || exit 0
[[ -z "$addr" ]] && exit 0

# Tiled windows: use the normal maximized state.
if [[ "$floating" != 1 ]]; then
    hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })' >/dev/null
    exit 0
fi

read -r tx ty tw th < <(hyprctl -j monitors | python3 -c '
import sys, json
m = json.load(sys.stdin)[0]
rt, rb, rl, rr = m["reserved"][1], m["reserved"][3], m["reserved"][0], m["reserved"][2]
bar, border = 30, 1   # hyprbars bar height, window border
W, H = int(m["width"] / m["scale"]), int(m["height"] / m["scale"])
print(rl + border, rt + bar + border, W - rl - rr - 2 * border, H - rt - rb - bar - 2 * border)')

saved="$state/$addr"
if (( w >= tw - 4 && h >= th - 4 )) && [[ -f "$saved" ]]; then
    read -r sx sy sw sh < "$saved"
    hyprctl dispatch "hl.dsp.window.resize({ x = $sw, y = $sh })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $sx, y = $sy })" >/dev/null
    rm -f "$saved"
else
    echo "$x $y $w $h" > "$saved"
    hyprctl dispatch "hl.dsp.window.resize({ x = $tw, y = $th })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $tx, y = $ty })" >/dev/null
fi
hyprctl dispatch 'hl.dsp.window.bring_to_top()' >/dev/null
