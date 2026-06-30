/*
 * Copyright (c) 2017 Jan Arne Petersen
 * SPDX-License-Identifier: LGPL-2.1-only
 */
#include "qwaylandinputpanelshellintegration.h"
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include "qwaylandinputpanelsurface.h"

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

QWaylandInputPanelShellIntegration::QWaylandInputPanelShellIntegration()
    : QWaylandShellIntegration()
{
}

QWaylandInputPanelShellIntegration::~QWaylandInputPanelShellIntegration()
{
}

bool QWaylandInputPanelShellIntegration::initialize(QWaylandDisplay *display)
{
    auto result = QWaylandShellIntegration::initialize(display);
    const auto globals = display->globals();
    for (auto global: globals) {
        if (global.interface == QLatin1String("zwp_input_panel_v1")) {
            m_panel.reset(new QtWayland::zwp_input_panel_v1(display->wl_registry(), global.id, 1));
            break;
        }
    }
    return result;
}

QWaylandShellSurface *
QWaylandInputPanelShellIntegration::createShellSurface(QWaylandWindow *window)
{
    struct zwp_input_panel_surface_v1 *ip_surface = m_panel->get_input_panel_surface(window->wlSurface());
    return new QWaylandInputPanelSurface(ip_surface, window);
}

}
QT_END_NAMESPACE
