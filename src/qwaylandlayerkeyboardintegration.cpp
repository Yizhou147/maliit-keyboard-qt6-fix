/*
 * Layer Shell keyboard integration - replaces inputpanel-shell.
 */
#include "qwaylandlayerkeyboardintegration.h"
#include "qwaylandlayerkeyboard.h"

#include <QtWaylandClient/private/qwaylandwindow_p.h>

QT_BEGIN_NAMESPACE

Q_LOGGING_CATEGORY(qLcLayerKbInteg, "qt.qpa.wayland.layerkeyboard")

namespace QtWaylandClient {

QWaylandLayerKeyboardIntegration::QWaylandLayerKeyboardIntegration()
    : QWaylandShellIntegration()
{
}

QWaylandLayerKeyboardIntegration::~QWaylandLayerKeyboardIntegration()
{
    if (m_layerShell) {
        zwlr_layer_shell_v1_destroy(m_layerShell);
        m_layerShell = nullptr;
    }
}

bool QWaylandLayerKeyboardIntegration::initialize(QWaylandDisplay *display)
{
    bool ok = QWaylandShellIntegration::initialize(display);
    if (!ok) return false;

    // Find zwlr_layer_shell_v1 in the registry
    const auto globals = display->globals();
    for (auto global : globals) {
        if (global.interface == QLatin1String("zwlr_layer_shell_v1")) {
            m_layerShell = static_cast<struct zwlr_layer_shell_v1 *>(
                wl_registry_bind(display->wl_registry(), global.id,
                                 &zwlr_layer_shell_v1_interface, 1));
            break;
        }
    }

    if (!m_layerShell) {
        qCWarning(qLcLayerKbInteg) << "zwlr_layer_shell_v1 not found in registry!";
        return false;
    }

    qCDebug(qLcLayerKbInteg) << "zwlr_layer_shell_v1 bound successfully";
    return true;
}

QWaylandShellSurface *QWaylandLayerKeyboardIntegration::createShellSurface(QWaylandWindow *window)
{
    if (!m_layerShell) {
        qCWarning(qLcLayerKbInteg) << "no layer shell, cannot create surface";
        return nullptr;
    }

    struct wl_surface *wlsurface = window->wlSurface();
    if (!wlsurface) {
        qCWarning(qLcLayerKbInteg) << "no wl_surface for window";
        return nullptr;
    }

    // Get the output (screen) for positioning - can be null (compositor chooses)
    struct wl_output *output = nullptr;

    qCDebug(qLcLayerKbInteg) << "creating layer keyboard surface";
    return new QWaylandLayerKeyboardSurface(wlsurface, m_layerShell, output, window);
}

} // namespace QtWaylandClient

QT_END_NAMESPACE
