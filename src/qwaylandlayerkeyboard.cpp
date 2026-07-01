/*
 * Layer Shell keyboard surface - replaces input-panel-v1.
 * Anchors the keyboard at the bottom of the screen using zwlr_layer_shell_v1.
 */
#include "qwaylandlayerkeyboard.h"

#include <QtWaylandClient/private/qwaylandwindow_p.h>

QT_BEGIN_NAMESPACE

Q_LOGGING_CATEGORY(qLcLayerKb, "qt.qpa.wayland.layerkeyboard")

namespace QtWaylandClient {

const struct zwlr_layer_surface_v1_listener QWaylandLayerKeyboardSurface::s_listener = {
    .configure = handleConfigure,
    .closed = handleClosed,
};

void QWaylandLayerKeyboardSurface::handleConfigure(void *data,
        struct zwlr_layer_surface_v1 *surface,
        uint32_t serial, uint32_t width, uint32_t height)
{
    auto *self = static_cast<QWaylandLayerKeyboardSurface *>(data);
    qCDebug(qLcLayerKb) << "layer surface configure:" << width << "x" << height
                         << "serial=" << serial;

    self->m_width = width;
    self->m_height = height;
    self->m_configured = true;

    // Acknowledge the configure - this is REQUIRED, but do NOT commit here
    // Qt's window system handles surface commits automatically
    // Committing here causes an infinite loop:
    //   configure → ack + commit → compositor sends configure again → ...
    zwlr_layer_surface_v1_ack_configure(surface, serial);
}

void QWaylandLayerKeyboardSurface::handleClosed(void *data,
        struct zwlr_layer_surface_v1 *surface)
{
    Q_UNUSED(data);
    Q_UNUSED(surface);
    qCDebug(qLcLayerKb) << "layer surface closed";
}

QWaylandLayerKeyboardSurface::QWaylandLayerKeyboardSurface(
        struct wl_surface *surface,
        struct zwlr_layer_shell_v1 *layerShell,
        struct wl_output *output,
        QWaylandWindow *window)
    : QWaylandShellSurface(window)
{
    qCDebug(qLcLayerKb) << "creating layer surface for keyboard";

    // Create a layer surface on the overlay layer, anchored to the bottom
    m_layerSurface = zwlr_layer_shell_v1_get_layer_surface(
        layerShell, surface, output,
        ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,  // overlay layer (on top of everything)
        "maliit-keyboard"                    // namespace
    );

    if (!m_layerSurface) {
        qCWarning(qLcLayerKb) << "failed to create layer surface!";
        return;
    }

    zwlr_layer_surface_v1_add_listener(m_layerSurface, &s_listener, this);

    // Anchor to the bottom of the screen
    zwlr_layer_surface_v1_set_anchor(m_layerSurface,
        ZWLR_LAYER_SURFACE_V1_ANCHOR_BOTTOM |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_LEFT |
        ZWLR_LAYER_SURFACE_V1_ANCHOR_RIGHT);

    // Set exclusive zone -1 means no exclusive zone (keyboard floats over content)
    zwlr_layer_surface_v1_set_exclusive_zone(m_layerSurface, -1);

    // Set keyboard interactivity
    zwlr_layer_surface_v1_set_keyboard_interactivity(m_layerSurface,
        ZWLR_LAYER_SURFACE_V1_KEYBOARD_INTERACTIVITY_ON_DEMAND);

    // Set size: full width (0 = compositor decides), ~300px height
    zwlr_layer_surface_v1_set_size(m_layerSurface, 0, 300);

    // Set margin
    zwlr_layer_surface_v1_set_margin(m_layerSurface, 0, 0, 0, 0);

    // Commit the initial state
    wl_surface_commit(surface);

    qCDebug(qLcLayerKb) << "layer surface created, anchored to bottom";
}

QWaylandLayerKeyboardSurface::~QWaylandLayerKeyboardSurface()
{
    qCDebug(qLcLayerKb) << "destroying layer surface";
    if (m_layerSurface) {
        zwlr_layer_surface_v1_destroy(m_layerSurface);
        m_layerSurface = nullptr;
    }
}

void QWaylandLayerKeyboardSurface::applyConfigure()
{
    if (m_configured) {
        qCDebug(qLcLayerKb) << "applyConfigure: size" << m_width << "x" << m_height;
    }
}

} // namespace QtWaylandClient

QT_END_NAMESPACE
