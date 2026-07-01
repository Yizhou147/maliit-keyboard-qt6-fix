# maliit-keyboard-qt6-fix

Fix for maliit virtual keyboard not working on **KWin 6.x** with Plasma Mobile (DroidSpaces / Anland).

## Problem

The original `inputpanel-shell` Wayland shell integration plugin (from [maliit-framework PR #125](https://github.com/maliit/framework/pull/125)) uses the `input-panel-unstable-v1` protocol (`zwp_input_panel_v1`) to create the keyboard surface. **This protocol has been removed from wayland-protocols 1.47+ and is not supported by KWin 6.x.**

### Symptoms

- Virtual keyboard does not appear when tapping text fields
- Keyboard flashes briefly then disappears
- Keyboard flickers rapidly in some applications
- `WAYLAND_DEBUG` shows `zwp_input_panel_v1` is **not advertised** in the Wayland registry

### Root Cause

```
maliit's inputpanel-shell plugin → looks for zwp_input_panel_v1 in Wayland registry
                                     ↓
KWin 6.x → does NOT advertise zwp_input_panel_v1 (removed from wayland-protocols 1.47+)
                                     ↓
Plugin initialize() fails → panel object is null → keyboard surface cannot be created
```

## Solution

Replace the `input-panel-v1` based shell integration with a **wlr-layer-shell** based implementation.

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
libinputpanel-shell.so (this fix)
    ↓ uses zwlr_layer_shell_v1
KWin compositor
    ↓ positions keyboard at screen bottom (overlay layer)
Android display (via Anland / DroidSpaces)
```

### How the fix works

1. **Plugin key preserved**: The plugin keeps the key `"inputpanel-shell"` so Qt loads it automatically for keyboard windows
2. **Layer shell binding**: `zwlr_layer_shell_v1` is bound from the Wayland registry (KWin 6.x always advertises this)
3. **Surface creation**: Each keyboard window gets a `zwlr_layer_surface_v1` on the **overlay layer**, anchored to the **bottom** of the screen
4. **Configure events**: The compositor sends size/configure events; the plugin acknowledges them
5. **No keyword conflicts**: C++ `namespace` keyword conflict with the C protocol header is handled via `#define namespace wl_namespace`

## Build

### On arm64 Ubuntu 26 / Debian 13 with Qt6 dev packages

```bash
git clone https://github.com/Yizhou147/maliit-keyboard-qt6-fix.git
cd maliit-keyboard-qt6-fix
sudo ./build.sh
```

### Prerequisites

```bash
apt install build-essential cmake pkg-config git \
    qt6-base-dev qt6-base-dev-tools qt6-base-private-dev \
    qt6-declarative-dev qt6-declarative-private-dev \
    qt6-wayland-dev qt6-wayland-private-dev \
    wayland-protocols libwayland-dev \
    libglib2.0-dev libxkbcommon-dev \
    extra-cmake-modules devscripts debhelper
```

### Network issues (GitHub access)

If `git clone` or `curl` fails due to network issues in China:

```bash
# Use a GitHub mirror proxy
export https_proxy=http://127.0.0.1:YOUR_PORT
# Or edit build.sh to use a mirror URL for FRAMEWORK_REPO
```

The build script downloads the `wlr-layer-shell-unstable-v1.xml` protocol file automatically. If the download fails, manually place it at:
```
/usr/share/wayland-protocols/staging/ext-layer-shell/wlr-layer-shell-unstable-v1.xml
```

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

## Troubleshooting

### Keyboard doesn't appear

```bash
# Check if the plugin .so is installed
ls -la /usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/libinputpanel-shell.so

# Check if zwlr_layer_shell_v1 is available
WAYLAND_DEBUG=1 maliit6-server 2>&1 | grep "zwlr_layer_shell"

# Check maliit6-server logs
journalctl _PID=$(pidof maliit6-server) --no-pager -n 20
```

### Keyboard appears but in wrong position

The layer shell anchors the keyboard to the bottom of the screen. If positioning is wrong, check KWin's layer shell support:

```bash
WAYLAND_DEBUG=1 maliit6-server 2>&1 | grep "layer_surface"
```

### Reverting to original

```bash
sudo dpkg -r maliit-layer-keyboard
sudo apt install --reinstall maliit-keyboard-qt6
```

## Build Errors Reference

### `namespace` keyword conflict
The `wlr-layer-shell` C protocol header uses `namespace` as a parameter name, which is a C++ reserved keyword. Fixed via `#define namespace wl_namespace` before including the header.

### `qwayland-wlr-layer-shell-unstable-v1.h: No such file or directory`
The `ecm_add_qtwayland_client_protocol` macro generates a Qt wrapper that includes a nonexistent header. Fixed via a post-build symlink from `wayland-wlr-layer-shell-client-protocol.h` to `qwayland-wlr-layer-shell-unstable-v1.h`.

### `global.name` does not exist
The `QWaylandDisplay::RegistryGlobal` struct uses `global.id`, not `global.name`.

### `isEmbedded()` / `getPopup()` not overriding
These methods don't exist in this Qt version's `QWaylandShellSurface`. Removed from the subclass.

## Related Projects

- [DroidSpaces](https://github.com/MGHazz/Droidspaces) - Linux container runtime for Android
- [Anland](https://github.com/superturtlee/anland) - Wayland display protocol for Android
- [maliit-framework](https://github.com/maliit/framework) - Input method framework
- [maliit-keyboard](https://github.com/maliit/keyboard) - Virtual keyboard

## License

LGPL-2.1-only (same as maliit-framework)
