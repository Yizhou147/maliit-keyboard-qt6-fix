/*
 * Layer Shell keyboard integration - replaces inputpanel-shell.
 * Uses zwlr_layer_shell_v1 instead of zwp_input_panel_v1.
 */
#pragma once

#include <QtWaylandClient/private/qwaylandshellintegration_p.h>

#define namespace wl_namespace
#include <wayland-wlr-layer-shell-client-protocol.h>
#undef namespace

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

class QWaylandLayerKeyboardIntegration : public QWaylandShellIntegration
{
public:
    QWaylandLayerKeyboardIntegration();
    ~QWaylandLayerKeyboardIntegration() override;

    bool initialize(QWaylandDisplay *display) override;
    QWaylandShellSurface *createShellSurface(QWaylandWindow *window) override;

private:
    struct zwlr_layer_shell_v1 *m_layerShell = nullptr;
};

}
QT_END_NAMESPACE
