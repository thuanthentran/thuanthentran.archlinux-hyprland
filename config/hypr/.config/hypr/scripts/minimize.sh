#!/usr/bin/env bash
# Minimize / restore windows, macOS style. Minimized windows live in the hidden special
# workspace "magic".
#   minimize.sh minimize   hide the active window (title bar "-", Super+M)
#   minimize.sh restore    bring a minimized window back to the current workspace
#                          (Waybar button, Super+S); asks with rofi when there are several
#
# The move uses follow = false: without it Hyprland opens the special workspace to follow
# the window, so it stays on screen and minimize looks like it did nothing.
set -eu

special=special:magic

case ${1:-} in
  minimize)
    hyprctl dispatch "hl.dsp.window.move({ workspace = \"$special\", follow = false })" >/dev/null
    ;;

  restore)
    # "address<TAB>class: title" for each minimized window
    mapfile -t wins < <(hyprctl clients -j | python3 -I -c '
import json, sys
for c in json.load(sys.stdin):
    if c["workspace"]["name"] == sys.argv[1]:
        print(c["address"] + "\t" + c["class"] + ": " + c["title"])
' "$special")

    if ((${#wins[@]} == 0)); then
      notify-send -t 1500 "No minimized windows"
      exit 0
    elif ((${#wins[@]} == 1)); then
      pick=0
    else
      pkill rofi || true
      pick=$(printf '%s\n' "${wins[@]#*$'\t'}" | rofi -dmenu -i -p Restore -format i) || exit 0
    fi
    addr=${wins[$pick]%%$'\t'*}

    # Back to the regular workspace shown on the focused monitor; close the special
    # workspace if it is open so the restored window is not hidden behind it.
    read -r ws open < <(hyprctl monitors -j | python3 -I -c '
import json, sys
m = next(m for m in json.load(sys.stdin) if m["focused"])
print(m["activeWorkspace"]["id"], 1 if m["specialWorkspace"]["name"] else 0)')
    hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, follow = false, window = \"address:$addr\" })" >/dev/null
    ((open)) && hyprctl dispatch 'hl.dsp.workspace.toggle_special("magic")' >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$addr\" })" >/dev/null
    ;;

  *)
    echo "Usage: minimize.sh minimize|restore" >&2
    exit 1
    ;;
esac
