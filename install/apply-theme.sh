#!/usr/bin/env bash
# Apply the macOS-like look (WhiteSur + Inter). Run inside a graphical session.
set -euo pipefail
s=org.gnome.desktop.interface
gsettings set $s gtk-theme     'WhiteSur-Dark'
gsettings set $s icon-theme    'WhiteSur-dark'
gsettings set $s cursor-theme  'WhiteSur-cursors'
gsettings set $s font-name     'Inter 10'
gsettings set $s color-scheme  'prefer-dark'
command -v hyprctl >/dev/null && hyprctl setcursor WhiteSur-cursors 24 || true
