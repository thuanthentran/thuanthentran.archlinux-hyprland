# Maximize / restore the active window to fill the work area (below the top bar).
# Uses a real resize instead of Hyprland's "maximized" state, because maximized windows
# are drawn below floating ones, which breaks window switching.
# A maximized window carries the tag `maximized`: a window rule in hyprland.lua drops its
# hyprbars title bar, border and rounding, and the Quickshell top bar shows its title and
# buttons instead. keep_on_screen (hyprland.lua) takes the tag off when the window is moved
# or resized away from the work area.
set -eu
state="${XDG_RUNTIME_DIR:-/tmp}/toggle-maximize"
mkdir -p "$state"

read -r addr pid floating maxed x y w h < <(hyprctl -j activewindow | python3 -c '
import sys, json
d = json.load(sys.stdin)
maxed = int(any(t.rstrip("*") == "maximized" for t in d.get("tags", [])))
print(d.get("address", ""), d.get("pid", 0), int(d.get("floating", False)), maxed, *d["at"], *d["size"])') || exit 0
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

# Work area: maximized (no title bar, no border) and, for the 65% fallback, with them
read -r tx ty tw th < <(hyprctl -j monitors | python3 -c '
import sys, json
m = next(m for m in json.load(sys.stdin) if m["focused"])
rl, rt, rr, rb = m["reserved"]
W, H = int(m["width"] / m["scale"]), int(m["height"] / m["scale"])
print(m["x"] + rl, m["y"] + rt, W - rl - rr, H - rt - rb)')
bar=20 border=1    # hyprbars bar_height, general.border_size (hyprland.lua)

# Everything in one dispatch, so keep_on_screen never sees the tag with the old size
apply() {   # tag x y w h
    hyprctl dispatch "(function()
        hl.dispatch(hl.dsp.window.tag({ tag = \"$1maximized\", window = \"address:$addr\" }))
        hl.dispatch(hl.dsp.window.resize({ x = $4, y = $5, window = \"address:$addr\" }))
        hl.dispatch(hl.dsp.window.move({ x = $2, y = $3, window = \"address:$addr\" }))
        hl.dispatch(hl.dsp.window.bring_to_top())
    end)" >/dev/null
}

saved="$state/$addr-$pid"
if (( maxed )); then
    sw=0 sh=0
    if [[ -f "$saved" ]]; then
        read -r sx sy sw sh < "$saved"
        rm -f "$saved"
    fi
    # area a window with a title bar can use
    aw=$(( tw - 2 * border )) ah=$(( th - bar - 2 * border ))
    if (( sw <= 0 || (sw >= aw - 4 && sh >= ah - 4) )); then
        # Nothing smaller to go back to (opened full size, or maximized by an older
        # version of this script): a 65% window, centred
        sw=$(( aw * 65 / 100 )) sh=$(( ah * 65 / 100 ))
        sx=$(( tx + (tw - sw) / 2 )) sy=$(( ty + bar + border + (ah - sh) / 2 ))
    fi
    apply - "$sx" "$sy" "$sw" "$sh"
else
    echo "$x $y $w $h" > "$saved"
    apply + "$tx" "$ty" "$tw" "$th"
fi
# the top bar reads the tag from Hyprland's window list
qs ipc call windows refresh >/dev/null 2>&1 || true
