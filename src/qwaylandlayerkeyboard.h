/*
 * Layer Shell keyboard surface - replaces input-panel-v1.
 * Uses zwlr_layer_shell_v1 to anchor the keyboard at the screen bottom.
 */
#pragma once

#include <QtWaylandClient/private/qwaylandshellsurface_p.h>
#include <wayland-wlr-layer-shell-client-protocol.h>

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

class QWaylandLayerKeyboardSurface : public QWaylandShellSurface
{
public:
    QWaylandLayerKeyboardSurface(struct wl_surface *surface,
                                  struct zwlr_layer_shell_v1 *layerShell,
                                  struct wl_output *output,
                                  QWaylandWindow *window);
    ~QWaylandLayerKeyboardSurface() override;

    void applyConfigure() override;
    bool isEmbedded() const override { return false; }
    Popup *getPopup() override { return nullptr; }

private:
    struct zwlr_layer_surface_v1 *m_layerSurface = nullptr;
    bool m_configured = false;
    uint32_t m_width = 0;
    uint32_t m_height = 0;

    static void handleConfigure(void *data,
                                 struct zwlr_layer_surface_v1 *surface,
                                 uint32_t serial, uint32_t width, uint32_t height);
    static void handleClosed(void *data,
                              struct zwlr_layer_surface_v1 *surface);

    static const struct zwlr_layer_surface_v1_listener s_listener;
};

}
QT_END_NAMESPACE
