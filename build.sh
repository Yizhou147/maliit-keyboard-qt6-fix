#!/bin/bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/output}"
PREFIX="${PREFIX:-/usr}"
JOBS="${JOBS:-$(nproc)}"

FRAMEWORK_REPO="https://github.com/cordlandwehr/framework.git"
FRAMEWORK_BRANCH="qt6-support_v2"

export PATH="$PATH:/usr/lib/qt6/libexec"

echo "=== layer-shell keyboard builder ==="

# Install deps
echo ">>> Installing dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    build-essential cmake pkg-config git \
    qt6-base-dev qt6-base-dev-tools \
    qt6-base-private-dev \
    qt6-declarative-dev qt6-declarative-private-dev \
    qt6-wayland-dev qt6-wayland-private-dev \
    wayland-protocols libwayland-dev \
    libglib2.0-dev libxkbcommon-dev \
    extra-cmake-modules \
    devscripts debhelper \
    && rm -rf /var/lib/apt/lists/*

echo ">>> Cloning maliit-framework..."
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
[ -d "$BUILD_DIR/framework" ] || git clone --depth=1 -b "$FRAMEWORK_BRANCH" "$FRAMEWORK_REPO" "$BUILD_DIR/framework"

# ============================================================
# Replace inputpanel-shell with layer-shell keyboard
# ============================================================
echo ">>> Replacing shell integration sources..."
SHELL_DIR="$BUILD_DIR/framework/src/qt/plugins/shellintegration"

# Remove old input-panel sources
rm -f "$SHELL_DIR"/qwaylandinputpanelsurface.{cpp,h}
rm -f "$SHELL_DIR"/qwaylandinputpanelshellintegration.{cpp,h}
rm -f "$SHELL_DIR"/inputpanelshellplugin.cpp

# Copy new layer-shell sources
cp src/qwaylandlayerkeyboard.{cpp,h} "$SHELL_DIR/"
cp src/qwaylandlayerkeyboardintegration.{cpp,h} "$SHELL_DIR/"
cp src/layerkeyboardplugin.cpp "$SHELL_DIR/inputpanelshellplugin.cpp"
cp src/inputpanelshell.json "$SHELL_DIR/inputpanelshell.json"

# ============================================================
# Find the wlr-layer-shell protocol XML
# ============================================================
echo ">>> Finding layer-shell protocol..."
LAYER_SHELL_XML=""
for dir in /usr/share/wayland-protocols /usr/local/share/wayland-protocols; do
    found=$(find "$dir" -name "*.xml" -path "*layer-shell*" 2>/dev/null | head -1)
    if [ -n "$found" ]; then
        LAYER_SHELL_XML="$found"
        break
    fi
done

if [ -z "$LAYER_SHELL_XML" ]; then
    echo ">>> wlr-layer-shell protocol not found, downloading..."
    mkdir -p /usr/share/wayland-protocols/staging/ext-layer-shell
    curl -sL "https://raw.githubusercontent.com/swaywm/wlr-protocols/master/unstable/wlr-layer-shell-unstable-v1.xml" \
        -o "$LAYER_SHELL_XML"
    LAYER_SHELL_XML="/usr/share/wayland-protocols/staging/ext-layer-shell/wlr-layer-shell-unstable-v1.xml"
fi

echo ">>> Using protocol: $LAYER_SHELL_XML"

# ============================================================
# Patch CMakeLists.txt
# ============================================================
echo ">>> Patching CMakeLists.txt..."
FRAMEWORK_CMAKE="$BUILD_DIR/framework/CMakeLists.txt"

python3 - "$FRAMEWORK_CMAKE" "$LAYER_SHELL_XML" << 'PYEOF'
import re, sys

cmake_path = sys.argv[1]
layer_xml = sys.argv[2]

with open(cmake_path, 'r') as f:
    content = f.read()

old_pattern = re.compile(
    r'set\(INPUT_PANEL_SHELL_SOURCES.*?install\(TARGETS inputpanel-shell\n'
    r'\s+LIBRARY DESTINATION \$\{QT_PLUGINS_INSTALL_DIR\}/wayland-shell-integration\)',
    re.DOTALL
)

new_block = f'''set(INPUT_PANEL_SHELL_SOURCES
            src/qt/plugins/shellintegration/inputpanelshellplugin.cpp
            src/qt/plugins/shellintegration/qwaylandlayerkeyboardintegration.cpp
            src/qt/plugins/shellintegration/qwaylandlayerkeyboardintegration.h
            src/qt/plugins/shellintegration/qwaylandlayerkeyboard.cpp
            src/qt/plugins/shellintegration/qwaylandlayerkeyboard.h)

    ecm_add_qtwayland_client_protocol(INPUT_PANEL_SHELL_SOURCES PROTOCOL {layer_xml} BASENAME wlr-layer-shell)
    # Fix: the Qt wrapper includes a nonexistent header. Create a symlink after generation.
    add_custom_command(TARGET inputpanel-shell POST_BUILD
        COMMAND ${{CMAKE_COMMAND}} -E create_symlink
            ${{CMAKE_BINARY_DIR}}/wayland-wlr-layer-shell-client-protocol.h
            ${{CMAKE_BINARY_DIR}}/qwayland-wlr-layer-shell-unstable-v1.h
        COMMENT "Creating protocol header symlink"
    )

    add_library(inputpanel-shell MODULE ${{INPUT_PANEL_SHELL_SOURCES}})
    target_link_libraries(inputpanel-shell Qt${{QT_VERSION_MAJOR}}::WaylandClient PkgConfig::XKBCOMMON Wayland::Client)
    if (Qt6_FOUND)
      target_link_libraries(inputpanel-shell Qt${{QT_VERSION_MAJOR}}::WaylandGlobalPrivate)
      target_include_directories(inputpanel-shell PRIVATE ${{Qt6WaylandClient_PRIVATE_INCLUDE_DIRS}} ${{Qt6WaylandGlobalPrivate_PRIVATE_INCLUDE_DIRS}} ${{Qt6XkbCommonSupport_PRIVATE_INCLUDE_DIRS}} ${{CMAKE_BINARY_DIR}})
    else()
      target_include_directories(inputpanel-shell PRIVATE ${{Qt5WaylandClient_PRIVATE_INCLUDE_DIRS}} ${{Qt5XkbCommonSupport_PRIVATE_INCLUDE_DIRS}} ${{CMAKE_BINARY_DIR}})
    endif()
endif()

if(enable-examples)
    find_package(Qt${{QT_VERSION_MAJOR}} REQUIRED COMPONENTS Widgets)

    install(TARGETS inputpanel-shell
            LIBRARY DESTINATION ${{QT_PLUGINS_INSTALL_DIR}}/wayland-shell-integration)'''

if old_pattern.search(content):
    content = old_pattern.sub(new_block, content)
    print("CMakeLists.txt patched successfully")
else:
    print("ERROR: Could not find INPUT_PANEL_SHELL_SOURCES block")
    sys.exit(1)

with open(cmake_path, 'w') as f:
    f.write(content)
PYEOF

# Copy private headers
echo ">>> Copying private headers..."
qt6_inc="/usr/include/$(uname -m)-linux-gnu/qt6"
for module_dir in "$qt6_inc"/*/; do
    module_name=$(basename "$module_dir")
    for versioned_dir in "$module_dir"/6.*/"$module_name"/*/; do
        if [ -d "$versioned_dir" ]; then
            subdir_name=$(basename "$versioned_dir")
            mkdir -p "$module_dir/$subdir_name"
            cp -a "$versioned_dir"* "$module_dir/$subdir_name/" 2>/dev/null || true
        fi
    done
done

# ============================================================
# Build
# ============================================================
echo ">>> Building inputpanel-shell (layer-shell replacement)..."
mkdir -p "$BUILD_DIR/build"
cd "$BUILD_DIR/build"

cmake "$BUILD_DIR/framework" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_WITH_QT6=ON \
    -DQtWaylandScanner_EXECUTABLE=/usr/lib/qt6/libexec/qtwaylandscanner \
    -Denable-inputcontext-qt4=OFF \
    -Denable-input-context-link=OFF \
    -Denable-wayland-gtk=OFF \
    -Denable-xcb=OFF \
    -Denable-hwkeyboard=OFF \
    -Denable-docs=OFF \
    -Denable-tests=OFF \
    -Denable-examples=OFF

make -j"$JOBS" inputpanel-shell

echo ">>> Packaging..."
pkg_dir="$BUILD_DIR/pkg"
rm -rf "$pkg_dir"
mkdir -p "$pkg_dir/DEBIAN"
mkdir -p "$pkg_dir/usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration"

cp "$BUILD_DIR/build/libinputpanel-shell.so" \
   "$pkg_dir/usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/"

cat > "$pkg_dir/DEBIAN/control" << EOF
Package: maliit-layer-keyboard
Version: 2.0.0
Section: utils
Priority: optional
Architecture: arm64
Depends: maliit-keyboard-qt6
Maintainer: Layer Keyboard Builder
Description: Layer-shell based inputpanel-shell for KWin 6.x
 Replaces the input-panel-v1 based inputpanel-shell plugin with a
 wlr-layer-shell implementation. Anchors the keyboard at the screen
 bottom. Fixes keyboard on KWin 6.x which no longer supports
 input-panel-unstable-v1 protocol.
Conflicts: maliit-keyboard-qt6-fix
Replaces: maliit-keyboard-qt6-fix
EOF

cat > "$pkg_dir/DEBIAN/postinst" << 'POSTEOF'
#!/bin/bash
chmod 644 /usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/libinputpanel-shell.so
echo "inputpanel-shell replaced with layer-shell version. Reboot or restart maliit6-server."
POSTEOF
chmod 755 "$pkg_dir/DEBIAN/postinst"

dpkg-deb --build "$pkg_dir" "$OUTPUT_DIR/maliit-layer-keyboard_2.0.0_arm64.deb"
echo "=== Build complete: $OUTPUT_DIR/maliit-layer-keyboard_2.0.0_arm64.deb ==="
