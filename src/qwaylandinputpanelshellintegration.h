/*
 * Copyright (c) 2017 Jan Arne Petersen
 * SPDX-License-Identifier: LGPL-2.1-only
 */
#pragma once
#include <QtWaylandClient/private/qwaylandshellintegration_p.h>
#include "qwayland-input-panel-unstable-v1.h"

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

class QWaylandInputPanelShellIntegration : public QWaylandShellIntegration
{
public:
    QWaylandInputPanelShellIntegration();
    ~QWaylandInputPanelShellIntegration() override;
    bool initialize(QWaylandDisplay *display) override;
    QWaylandShellSurface *createShellSurface(QWaylandWindow *window) override;
private:
    QScopedPointer<QtWayland::zwp_input_panel_v1> m_panel;
};

}
QT_END_NAMESPACE
