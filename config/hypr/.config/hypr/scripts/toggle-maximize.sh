#!/usr/bin/env bash
# Maximize / restore the active window to fill the work area (below the top bar).
# Uses a real resize instead of Hyprland's "maximized" state, because maximized windows
# are drawn below floating ones, which breaks window switching.
set -eu
state="${XDG_RUNTIME_DIR:-/tmp}/toggle-maximize"
mkdir -p "$state"

read -r addr pid floating x y w h < <(hyprctl -j activewindow | python3 -c '
import sys, json
d = json.load(sys.stdin)
print(d.get("address", ""), d.get("pid", 0), int(d.get("floating", False)), *d["at"], *d["size"])') || exit 0
[[ -z "$addr" ]] && exit 0

# Saved sizes are keyed by address AND pid: Hyprland reuses window addresses, so a new
# window could otherwise inherit a closed window's size (a "restore" to a tiny popup).
# Forget saved sizes of windows that have been closed.
alive=$(hyprctl -j clients | python3 -c 'import sys, json; print(" ".join(c["address"] + "-" + str(c["pid"]) for c in json.load(sys.stdin)))')
for f in "$state"/*; do
    [[ -e $f && " $alive " != *" ${f##*/} "* ]] && rm -f "$f"
done

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

saved="$state/$addr-$pid"
# Maximized = filling the work area exactly (position and size). Anything else, including
# a full-size window that has been dragged aside, gets maximized.
d() { local v=$(( $1 - $2 )); echo $(( v < 0 ? -v : v )); }
if (( $(d "$x" "$tx") <= 4 && $(d "$y" "$ty") <= 4 && $(d "$w" "$tw") <= 4 && $(d "$h" "$th") <= 4 )); then
    sw=0 sh=0
    if [[ -f "$saved" ]]; then
        read -r sx sy sw sh < "$saved"
        rm -f "$saved"
    fi
    if (( sw >= tw - 4 && sh >= th - 4 )); then
        # Nothing smaller to go back to (opened full size, or a full-size window was
        # dragged aside before maximizing), so use a 65% popup, centered
        sw=$(( tw * 65 / 100 )) sh=$(( th * 65 / 100 ))
        sx=$(( tx + (tw - sw) / 2 )) sy=$(( ty + (th - sh) / 2 ))
    fi
    hyprctl dispatch "hl.dsp.window.resize({ x = $sw, y = $sh })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $sx, y = $sy })" >/dev/null
else
    echo "$x $y $w $h" > "$saved"
    hyprctl dispatch "hl.dsp.window.resize({ x = $tw, y = $th })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $tx, y = $ty })" >/dev/null
fi
hyprctl dispatch 'hl.dsp.window.bring_to_top()' >/dev/null
