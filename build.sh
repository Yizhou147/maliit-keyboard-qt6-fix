#!/bin/bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-$(pwd)/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$(pwd)/output}"
PREFIX="${PREFIX:-/usr}"
JOBS="${JOBS:-$(nproc)}"

FRAMEWORK_REPO="https://github.com/cordlandwehr/framework.git"
FRAMEWORK_BRANCH="qt6-support_v2"

export PATH="$PATH:/usr/lib/qt6/libexec"

echo "=== inputpanel-shell fix builder ==="

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
    devscripts debhelper \
    && rm -rf /var/lib/apt/lists/*

echo ">>> Cloning maliit-framework..."
mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
[ -d "$BUILD_DIR/framework" ] || git clone --depth=1 -b "$FRAMEWORK_BRANCH" "$FRAMEWORK_REPO" "$BUILD_DIR/framework"

# Apply fix
echo ">>> Applying inputpanel-shell fix..."
cp src/qwaylandinputpanelsurface.cpp "$BUILD_DIR/framework/src/qt/plugins/shellintegration/"
cp src/qwaylandinputpanelsurface.h "$BUILD_DIR/framework/src/qt/plugins/shellintegration/"

# Copy private headers (same as maliit-keyboard-qt6-builder)
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

# Patch moc IID
shell_plugin="$BUILD_DIR/framework/src/qt/plugins/shellintegration/inputpanelshellplugin.cpp"
sed -i 's|Q_PLUGIN_METADATA(IID QWaylandShellIntegrationFactoryInterface_iid|Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QWaylandShellIntegrationFactoryInterface.5.0"|' "$shell_plugin"

# Install input-panel protocol (removed from wayland-protocols 1.47+)
echo ">>> Installing input-panel-unstable-v1 protocol..."
PROTOCOL_DIR="/usr/share/wayland-protocols/unstable/input-panel"
mkdir -p "$PROTOCOL_DIR"
cp "$(dirname "$0")/src/input-panel-unstable-v1.xml" "$PROTOCOL_DIR/"

# Patch CMakeLists.txt to generate input-panel protocol bindings
echo ">>> Patching CMakeLists.txt for input-panel protocol..."
FRAMEWORK_CMAKE="$BUILD_DIR/framework/CMakeLists.txt"
sed -i '/ecm_add_qtwayland_client_protocol(INPUT_PANEL_SHELL_SOURCES PROTOCOL.*input-method-unstable-v1.xml/a\  ecm_add_qtwayland_client_protocol(INPUT_PANEL_SHELL_SOURCES PROTOCOL ${WAYLANDPROTOCOLS_PATH}\/unstable\/input-panel\/input-panel-unstable-v1.xml BASENAME input-panel-unstable-v1)' "$FRAMEWORK_CMAKE"

echo ">>> Building inputpanel-shell..."
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

cp "$BUILD_DIR/build/libinputpanel-shell.so" "$pkg_dir/usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/"

cat > "$pkg_dir/DEBIAN/control" << EOF
Package: maliit-keyboard-qt6-fix
Version: 1.0.0
Section: utils
Priority: optional
Architecture: arm64
Depends: maliit-keyboard-qt6
Maintainer: Droidspaces Builder
Description: Fix for inputpanel-shell KWin CPU loop
 Fixes applyConfigure() infinite loop in the inputpanel-shell
 Wayland shell integration plugin that caused KWin to spin at 800%% CPU.
EOF

# postinst to set correct permissions
cat > "$pkg_dir/DEBIAN/postinst" << 'POSTEOF'
#!/bin/bash
chmod 644 /usr/lib/aarch64-linux-gnu/qt6/plugins/wayland-shell-integration/libinputpanel-shell.so
POSTEOF
chmod 755 "$pkg_dir/DEBIAN/postinst"

dpkg-deb --build "$pkg_dir" "$OUTPUT_DIR/maliit-keyboard-qt6-fix_1.0.0_arm64.deb"
echo "=== Build complete: $OUTPUT_DIR/maliit-keyboard-qt6-fix_1.0.0_arm64.deb ==="
