/*
 * Copyright (c) 2017 Jan Arne Petersen
 * SPDX-License-Identifier: LGPL-2.1-only
 */
#pragma once
#include <QtWaylandClient/private/qwaylandshellsurface_p.h>
#include "qwayland-input-panel-unstable-v1.h"

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

class QWaylandInputPanelSurface : public QWaylandShellSurface, public QtWayland::zwp_input_panel_surface_v1
{
public:
    QWaylandInputPanelSurface(struct ::zwp_input_panel_surface_v1 *object, QWaylandWindow *window);
    ~QWaylandInputPanelSurface() override;
    void applyConfigure() override;
private:
    bool m_toplevelSet;
};

}
QT_END_NAMESPACE
