#!/usr/bin/env python3
"""Write the desktop palette into every config that can't read it itself.

The source is config/quickshell/.config/quickshell/config/palette.json (Quickshell reads it
live through Theme.qml). Each target holds a block between `palette:begin` / `palette:end`
marker lines, rewritten from the JSON; everything outside the markers is left alone, and
the configs refer to the variables the block defines.

    python3 install/palette.py           # rewrite the blocks
    python3 install/palette.py --check   # exit 1 if a block is out of date

Afterwards: Hyprland reloads by itself, rofi reads it on its next start, kitty on
`kill -USR1 $(pidof kitty)` or a new window, the greeter after `setup.sh greeter`, the
wallpaper with install/make-wallpaper.py.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = REPO / "config/quickshell/.config/quickshell/config/palette.json"


def hexes(p):
    """name -> 'rrggbb' for every colour entry"""
    return {k: v.lstrip("#").lower() for k, v in p.items() if isinstance(v, str) and v.startswith("#")}


def lua(p):
    h = hexes(p)
    width = max(map(len, h))
    lines = ["local P = {   -- hex without '#'"]
    lines += [f'    {k:<{width}} = "{v}",' for k, v in h.items()]
    lines.append("}")
    return lines


def rasi(p):
    h = hexes(p)
    rgb = lambda k: ", ".join(str(int(h[k][i:i + 2], 16)) for i in (0, 2, 4))
    return [
        f"bg:      rgba({rgb('surface')}, 0.94);",
        "bg-sel:  rgba(255, 255, 255, 0.10);",
        f"accent:  #{h['accent']};",
        f"fg:      #{h['fg']};",
        f"fg-dim:  rgba({rgb('fg')}, 0.5);",
    ]


def kitty(p):
    h = hexes(p)
    return [
        f"background            #{h['bg']}",
        f"foreground            #{h['fgTerm']}",
        f"cursor                #{h['accent']}",
        f"cursor_text_color     #{h['accentText']}",
        f"selection_background  #{h['selection']}",
        "selection_foreground  none",
        f"url_color             #{h['accent']}",
        f"color2                #{h['accentDim']}",
        f"color10               #{h['accent']}",
    ]


def hyprlang(p):
    return [f"${k} = {v}" for k, v in hexes(p).items()]


QS = "config/quickshell/.config/quickshell"
TARGETS = [
    ("config/hypr/.config/hypr/hyprland.lua", "--", lua),
    ("extras/greeter/hyprland.lua", "--", lua),
    ("config/rofi/.config/rofi/spotlight.rasi", "/*", rasi),
    ("config/kitty/.config/kitty/kitty.conf", "#", kitty),
    ("config/hypr/.config/hypr/hyprlock.conf", "#", hyprlang),
]


def marker(comment, word):
    """the begin line only has to start with this (a note may follow); the end line is it"""
    if comment == "/*":
        return "/* palette:begin" if word == "begin" else "/* palette:end */"
    return f"{comment} palette:{word}"


def main():
    check = "--check" in sys.argv[1:]
    p = json.loads(SOURCE.read_text())
    stale = []
    for rel, comment, gen in TARGETS:
        path = REPO / rel
        text = path.read_text()
        begin, end = marker(comment, "begin"), marker(comment, "end")
        m = re.search(rf"^([ \t]*){re.escape(begin)}.*?\n(.*?)^[ \t]*{re.escape(end)}", text, re.S | re.M)
        if not m:
            sys.exit(f"{rel}: no '{begin}' ... '{end}' block")
        indent = m.group(1)
        head = text[m.start():text.index("\n", m.start()) + 1]
        body = "".join(f"{indent}{l}\n" if l else "\n" for l in gen(p))
        new = text[:m.start()] + head + body + indent + end + text[m.end():]
        if new != text:
            stale.append(rel)
            if not check:
                path.write_text(new)
    if check and stale:
        print("out of date:", *stale)
        sys.exit(1)
    for rel in stale:
        print("wrote", rel)


if __name__ == "__main__":
    main()
