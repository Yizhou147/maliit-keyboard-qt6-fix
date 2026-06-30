/*
 * Copyright (c) 2017 Jan Arne Petersen
 * SPDX-License-Identifier: LGPL-2.1-only
 */
#include <QtWaylandClient/private/qwaylandshellintegrationplugin_p.h>
#include "qwaylandinputpanelshellintegration.h"

QT_BEGIN_NAMESPACE
namespace QtWaylandClient {

class QWaylandInputPanelShellIntegrationPlugin: public QWaylandShellIntegrationPlugin
{
Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QWaylandShellIntegrationFactoryInterface.5.0" FILE "inputpanelshell.json")
public:
    virtual QWaylandShellIntegration *create(const QString &key, const QStringList &paramList) override;
};

QWaylandShellIntegration *QWaylandInputPanelShellIntegrationPlugin::create(const QString &key, const QStringList &paramList)
{
    Q_UNUSED(key);
    Q_UNUSED(paramList);
    return new QWaylandInputPanelShellIntegration();
}

}
QT_END_NAMESPACE
#include "inputpanelshellplugin.moc"
