/*
 * Layer Shell keyboard plugin - replaces inputpanel-shell.
 * Uses zwlr_layer_shell_v1 to position the keyboard at the screen bottom.
 */
#include <QtWaylandClient/private/qwaylandshellintegrationplugin_p.h>
#include "qwaylandlayerkeyboardintegration.h"

QT_BEGIN_NAMESPACE

namespace QtWaylandClient {

class QWaylandLayerKeyboardPlugin : public QWaylandShellIntegrationPlugin
{
Q_OBJECT
    Q_PLUGIN_METADATA(IID QWaylandShellIntegrationFactoryInterface_iid FILE "inputpanelshell.json")

public:
    QWaylandShellIntegration *create(const QString &key, const QStringList &paramList) override;
};

QWaylandShellIntegration *QWaylandLayerKeyboardPlugin::create(const QString &key, const QStringList &paramList)
{
    Q_UNUSED(key);
    Q_UNUSED(paramList);
    return new QWaylandLayerKeyboardIntegration();
}

}

QT_END_NAMESPACE

#include "inputpanelshellplugin.moc"
