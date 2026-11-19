# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal Arch Linux + Hyprland setup for an ASUS TUF F16 (dual-boot with Windows). Goal: reinstall Arch, clone this repo, run a few commands, get the same desktop back. There is no build or test suite; the "code" is dotfiles, package lists and bash scripts. The repo is public on GitHub.

The machine this is checked out on is the target machine itself, running Hyprland, and the configs are already stowed into `~/.config`. Editing a file under `config/` changes the live desktop immediately (Hyprland reloads its config on save).

## Layout and how the pieces connect

- `config/<component>/.config/<component>/...` — GNU Stow packages. Each top-level dir in `config/` is one stow package whose contents mirror `$HOME`. Link with:
  ```sh
  stow -d config -t ~ <component>      # e.g. hypr, waybar, mako, rofi, nwg-dock-hyprland
  stow -d config -t ~ -R <component>   # restow after adding new files
  ```
  `~/.config/hypr` is a real directory (Stow linked its children individually), so a new file or dir added under `config/hypr/.config/hypr/` is not live until you restow `hypr`.
- `packages/*.txt` — one package per line, `#` comments. `base`, `hyprland-desktop`, `apps` and `hardware-<host>` come from the official repos; `aur.txt` from the AUR (via yay). When a config starts depending on a new program, add it to the right list. Find installed packages missing from the lists with `comm -23 <(pacman -Qqe | sort) <(sed -e 's/#.*//' -e '/^\s*$/d' packages/*.txt | sort)`.
- `system/etc/` (all machines) and `hosts/<host>/etc/` (one machine; default host `tuf-f16`) mirror `/etc` and are copied there by `setup.sh system`. The TUF F16 host has udev rules giving the GPUs stable names (`/dev/dri/igpu`, `/dev/dri/dgpu`), which `hyprland.lua` uses for `AQ_DRM_DEVICES`, and a mkinitcpio drop-in removing the `kms` hook for NVIDIA.
- `install/setup.sh` — post-install script, run as the normal user (uses sudo itself), idempotent. Steps: `mirrors packages aur dotfiles system services snapper plugins theme`; run a subset with `bash install/setup.sh dotfiles theme`, preview with `--dry-run`, pick a host with `SETUP_HOST=<name>` (or `none`). `plugins` and `theme` only work inside a Hyprland session. Check after editing: `bash -n install/setup.sh && bash install/setup.sh --dry-run`.
- `install/rank-mirrors.sh` — the `mirrors` step: ranks HTTPS mirrors in nearby countries by downloading part of a real ~100 MB package (not the small db file, which CDNs serve fast from cache even when packages crawl) and writes the top 8 to `/etc/pacman.d/mirrorlist`.
- `install/arch-install.sh` — installs the base system from the Arch live USB (Btrfs subvolumes `@ @home @log @pkg @snapshots`, shares the Windows ESP at `/efi` without formatting, GRUB + os-prober). Supports `--dry-run`; answers can be pre-set through `ARCH_*` env vars listed at the top of the file. It runs as root on the live ISO, so it can't be exercised on this machine beyond `bash -n` / `shellcheck` / reading the dry-run path.
- `install/apply-theme.sh` — called by `setup.sh theme`; applies the macOS-like look (WhiteSur GTK/icons/cursors, IBM Plex Sans UI font, CaskaydiaCove Nerd Font monospace, subpixel font rendering) via `gsettings`; run inside a graphical session. Font rendering for everything else is in `config/fontconfig` (subpixel RGB + hintslight; switch to bgr if text shows colour fringes); kitty has its own `text_composition_strategy`.
- `docs/` — docs in Vietnamese (why Arch, hardware notes, Windows prep, install walkthrough, repo plan, setup + rollback). `docs/05-repo-plan.md` holds default choices and open decisions; `docs/06-setup-and-rollback.md` the post-install checks and the manual snapshot rollback (`snapper rollback` does not work here because the kernel cmdline pins `rootflags=subvol=@`).

## Hyprland config is Lua, not hyprlang

`config/hypr/.config/hypr/hyprland.lua` uses Hyprland's Lua config API (Hyprland 0.57.x): `hl.monitor{}`, `hl.bind(...)`, `hl.dsp.exec_cmd(...)`, `hl.gesture{}`, `hl.exec_cmd(...)`. Dispatchers are also Lua expressions from the shell, e.g. `hyprctl dispatch "hl.dsp.window.cycle_next({ next = true })"`. Don't write classic `hyprland.conf` syntax (`bind = ...`, `exec-once = ...`). Syntax changes between Hyprland releases, so check the wiki for the installed version (`hyprctl version`) before adding options.

Unlike `hyprland.lua`, `hyprlock.conf`, `hypridle.conf` and `hyprpaper.conf` (hyprpaper 0.8 block syntax) still use hyprlang; they are started from the autostart block in `hyprland.lua`, as is `cliphist`. The wallpaper is `wallpapers/default.png` in the same Stow package. The `hyprbars` plugin is built by `hyprpm` and must be rebuilt (`hyprpm update`) after every Hyprland upgrade; its config is wrapped in `pcall` so a missing plugin doesn't break the config.

Window buttons: the `hyprbars` title bar is the only set of min/max/close buttons; app-drawn ones are hidden (`button-layout 'appmenu:'` in `apply-theme.sh` for GTK/Firefox, `window.controlsStyle: hidden` in `config/code` for VS Code). Minimized windows live in `special:magic`; `scripts/minimize.sh minimize|restore` handles it. Moves into a special workspace need `follow = false`, otherwise Hyprland opens the special workspace and the window stays on screen. `scripts/toggle-maximize.sh` resizes floating windows to the work area instead of using Hyprland's maximized state; it restores only when the window fills the work area exactly (position and size), otherwise it maximizes.

Focus is click-to-focus (`follow_mouse = 2`) with `cursor.no_warps`, so keyboard/gesture focus changes don't move the pointer. A 150 ms `hl.timer` in `hyprland.lua` (`keep_on_screen`) pushes the active floating window back when its title bar ends up under Waybar or off screen, once the drag has stopped. Don't use `release = true` binds on mouse buttons: they swallow the release even with `non_consuming`, so apps think the button is still held.

Scrolling: Hyprland only scales speed (`scroll_factor` for the mouse and `touchpad.scroll_factor`); inertia is client-side on Wayland, so it is set per app: kitty `momentum_scroll` (touchpad only), VS Code `*.smoothScrolling`, and Firefox prefs in `extras/firefox/user.js` (not a Stow package, since profile dirs have random names; `setup.sh dotfiles` symlinks it into each profile). GTK apps glide on the touchpad by themselves; nothing adds inertia to the mouse wheel system-wide.

Helper scripts live in `config/hypr/.config/hypr/scripts/` and are referenced from the Lua config as `$HOME/.config/hypr/scripts/<name>.sh`, so they must be executable and stowed. Validate after editing:
```sh
hyprctl configerrors        # Lua/config errors in the running session
hyprctl reload
```

The desktop aims to be mouse-friendly and macOS/Ubuntu-like: Waybar top bar, nwg-dock-hyprland dock, nwg-drawer app grid, rofi as Spotlight (`SUPER+space`) and window switcher, mako notifications, fcitx5-unikey for Vietnamese Telex input, kitty, thunar. Custom widgets are written in Quickshell (QML) and run alongside Waybar rather than replacing it at once.

Quickshell: `config/quickshell/.config/quickshell/shell.qml` is the entry point, widgets live in `widgets/` (one `PascalCase.qml` per type, imported with `import "widgets"`). `~/.config/quickshell` is a single Stow symlink to the repo dir, so new files are live without restowing, and Quickshell reloads on save. It is started as `qs` from the autostart block. Waybar, keybinds and scripts talk to it through `IpcHandler`s: `qs ipc show` lists targets, `qs ipc call shell ping` is the smoke test. Debug with `qs log` (or run `qs` in a terminal after `pkill qs`).

Hybrid GPU: the session renders on the Intel iGPU; the NVIDIA dGPU (open driver) drives the HDMI port and runs apps via `prime-run`. The laptop has a MUX: `eDP-1` is the panel on Intel, `eDP-2` the same panel on NVIDIA.

## Conventions

- Line endings are forced to LF via `.gitattributes` (the repo was originally edited on Windows). Keep the executable bit on scripts in git (`git update-index --chmod=+x` if needed).
- Machine-specific files go in `hosts/<host>/` and `packages/hardware-<host>.txt`; inside `hyprland.lua` guard them so other machines skip them (see the `/dev/dri/igpu` check).
- There is no passwordless sudo here: write root-level changes into `setup.sh`/`system/`/`hosts/` and let the user run them.
- Never commit secrets (SSH keys, tokens, Wi-Fi passwords).
- Commit messages are short imperative English ("Add Waybar config and autostart"); docs and README are written in Vietnamese.
- README's "Trạng thái" / "Lộ trình" sections track progress and go stale; update them when a milestone lands.
- `TODO.md` is the backlog (Vietnamese, ordered by priority). Tick items (`[x]`) in the same commit that does them, and add new follow-ups there instead of leaving them only in chat.
