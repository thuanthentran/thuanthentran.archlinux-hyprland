#!/usr/bin/env bash
# Apply the macOS-like look (WhiteSur + Lexend, Cascadia Code). Run inside a graphical session.
set -euo pipefail
s=org.gnome.desktop.interface
gsettings set $s gtk-theme     'WhiteSur-Dark'
gsettings set $s icon-theme    'WhiteSur-dark'
# Accent for libadwaita (GTK4) apps: green, as in the desktop palette (Theme.qml)
gsettings set $s accent-color  'green'
gsettings set $s cursor-theme  'WhiteSur-cursors'
gsettings set $s font-name           'Lexend 10'
gsettings set $s document-font-name  'Lexend 11'
gsettings set $s monospace-font-name 'CaskaydiaCove Nerd Font 11'
# Subpixel + slight hinting, matching config/fontconfig; "manual" makes GTK4 honour it
gsettings set $s font-antialiasing   'rgba'
gsettings set $s font-hinting        'slight'
gsettings set $s font-rgba-order     'rgb'
gsettings set $s font-rendering      'manual'
# No minimize/maximize/close in app header bars (GTK, Firefox): the hyprbars title bar
# from hyprland.lua is the one set of window buttons. "appmenu:" keeps only the app menu.
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:'
gsettings set $s color-scheme  'prefer-dark'
command -v hyprctl >/dev/null && hyprctl setcursor WhiteSur-cursors 24 || true
