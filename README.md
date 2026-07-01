# maliit-keyboard-qt6-fix

Fix for maliit virtual keyboard not working on **KWin 6.x** with Plasma Mobile (DroidSpaces / Anland).

## Problem

The original `inputpanel-shell` Wayland shell integration plugin (from [maliit-framework PR #125](https://github.com/maliit/framework/pull/125)) uses the `input-panel-unstable-v1` protocol (`zwp_input_panel_v1`) to create the keyboard surface. **This protocol has been removed from wayland-protocols 1.47+ and is not supported by KWin 6.x.**

Symptoms:
- Virtual keyboard does not appear when tapping text fields
- Keyboard flashes briefly then disappears
- Keyboard flickers rapidly in some applications
- `WAYLAND_DEBUG` shows `zwp_input_panel_v1` is **not advertised** in the Wayland registry

## Solution

Replace the `input-panel-v1` based shell integration with a **wlr-layer-shell** based implementation:

| | Old (broken) | New (this fix) |
|---|---|---|
| Protocol | `zwp_input_panel_v1` | `zwlr_layer_shell_v1` |
| KWin 6.x support | ❌ Removed | ✅ Supported |
| Keyboard positioning | `set_toplevel()` (broken) | Layer shell anchor (bottom) |
| Surface type | Input panel surface | Overlay layer surface |

The `zwlr_layer_shell_v1` protocol is part of [wlr-protocols](https://github.com/swaywm/wlr-protocols) and is supported by KWin 6.x, Sway, and other wlroots-based compositors.

## Architecture

```
maliit6-server
    ↓ creates QML keyboard window
Qt Wayland platform plugin
    ↓ loads "inputpanel-shell" shell integration
libinputpanel-shell.so (our fix)
    ↓ uses zwlr_layer_shell_v1
KWin compositor
    ↓ positions keyboard at screen bottom
Android display (via Anland)
```

## Build

### On arm64 Ubuntu 26 with Qt6 dev packages

```bash
sudo ./build.sh
```

### Prerequisites

- `maliit-keyboard-qt6` package installed
- `qt6-base-private-dev`, `qt6-wayland-dev`, `qt6-wayland-private-dev`
- `qt6-declarative-dev`, `qt6-declarative-private-dev`
- `extra-cmake-modules`
- `libwayland-dev`, `libxkbcommon-dev`
- `wayland-protocols` (with wlr-layer-shell protocol)
- Plasma Mobile with KWin 6.x

### Using Docker (CI)

```bash
docker build -f Dockerfile.build -t maliit-layer-keyboard .
docker cp maliit-layer-keyboard:/output/*.deb .
```

## Install

```bash
sudo dpkg -i maliit-layer-keyboard_2.0.0_arm64.deb
sudo reboot
```

The deb replaces `/usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/libinputpanel-shell.so` with the layer-shell version. The plugin key remains `"inputpanel-shell"` so Qt loads it automatically.

## How It Works

1. **Plugin loading**: Qt's Wayland platform plugin looks for a shell integration with key `"inputpanel-shell"` when creating the keyboard window
2. **Layer shell init**: The plugin binds `zwlr_layer_shell_v1` from the Wayland registry
3. **Surface creation**: For each keyboard window, the plugin creates a `zwlr_layer_surface_v1` on the **overlay layer**, anchored to the **bottom** of the screen
4. **Configure events**: The compositor sends size/configure events; the plugin acknowledges them
5. **Keyboard input**: The surface has keyboard interactivity enabled for on-demand input

## Troubleshooting

### Keyboard doesn't appear

```bash
# Check if the plugin is loaded
WAYLAND_DEBUG=1 maliit6-server 2>&1 | grep -i "layer\|inputpanel\|shell"

# Verify zwlr_layer_shell_v1 is available
WAYLAND_DEBUG=1 maliit6-server 2>&1 | grep "zwlr_layer_shell"

# Check if the .so exists
ls -la /usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/libinputpanel-shell.so
```

### Keyboard appears but in wrong position

The layer shell anchors the keyboard to the bottom of the screen. If it's not positioned correctly, check that KWin's layer shell implementation is working:

```bash
# Test with a simple layer-shell client
apt install wlr-randr  # or similar tool
```

### Reverting to original

```bash
sudo dpkg -r maliit-layer-keyboard
# Then reinstall the original maliit-keyboard-qt6 package
sudo apt install --reinstall maliit-keyboard-qt6
```

## Related Projects

- [DroidSpaces](https://github.com/MGHazz/Droidspaces) - Linux container runtime for Android
- [Anland](https://github.com/superturtlee/anland) - Wayland display protocol for Android
- [maliit-framework](https://github.com/maliit/framework) - Input method framework
- [maliit-keyboard](https://github.com/maliit/keyboard) - Virtual keyboard

## License

LGPL-2.1-only (same as maliit-framework)
