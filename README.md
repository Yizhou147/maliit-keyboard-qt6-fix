# maliit-keyboard-qt6-fix

Fix for the `inputpanel-shell` Wayland shell integration plugin causing KWin 800% CPU loop on Droidspaces / Plasma Mobile.

## Problem

The original `inputpanel-shell` plugin (from maliit-framework PR #125) calls `set_toplevel()` in `applyConfigure()` on every configure event. This creates an infinite configure loop with KWin, causing 800% CPU usage and keyboard flickering.

## Fix

`applyConfigure()` now only calls `set_toplevel()` once (on first configure). Subsequent configure events are ignored, breaking the loop.

## Build

```bash
# On arm64 Ubuntu 26 with Qt6 dev packages
sudo ./build.sh
```

## Install

```bash
sudo dpkg -i maliit-keyboard-qt6-fix_*.deb
sudo reboot
```

## Prerequisites

- `maliit-keyboard-qt6` package installed
- `qt6-base-private-dev`, `qt6-wayland-dev`, `qt6-wayland-private-dev`
- Plasma Mobile with KWin
