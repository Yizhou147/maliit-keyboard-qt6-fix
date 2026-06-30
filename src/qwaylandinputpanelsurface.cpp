/*
 * Copyright (c) 2017 Jan Arne Petersen
 * SPDX-License-Identifier: LGPL-2.1-only
 *
 * FIX: applyConfigure() only calls set_toplevel() once.
 * The original code called set_toplevel() on every configure event,
 * causing an infinite configure loop with KWin (800%% CPU).
 */
#include "qwaylandinputpanelsurface.h"
#include <QtWaylandClient/private/qwaylandwindow_p.h>
#include <QtWaylandClient/private/qwaylandscreen_p.h>

QT_BEGIN_NAMESPACE
Q_LOGGING_CATEGORY(qLcQpaShellIntegration, "qt.qpa.wayland.shell")
namespace QtWaylandClient {

QWaylandInputPanelSurface::QWaylandInputPanelSurface(struct ::zwp_input_panel_surface_v1 *object,
                                                     QWaylandWindow *window)
    : QWaylandShellSurface(window)
    , QtWayland::zwp_input_panel_surface_v1(object)
    , m_toplevelSet(false)
{
    qCDebug(qLcQpaShellIntegration) << Q_FUNC_INFO;
    window->applyConfigureWhenPossible();
}

QWaylandInputPanelSurface::~QWaylandInputPanelSurface()
{
    qCDebug(qLcQpaShellIntegration) << Q_FUNC_INFO;
}

void QWaylandInputPanelSurface::applyConfigure()
{
    if (!m_toplevelSet) {
        m_toplevelSet = true;
        set_toplevel(window()->waylandScreen()->output(), position_center_bottom);
    }
}

}
QT_END_NAMESPACE
