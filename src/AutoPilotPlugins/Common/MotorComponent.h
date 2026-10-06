#pragma once

#include "VehicleComponent.h"

class MotorComponent : public VehicleComponent
{
    Q_OBJECT

public:
    explicit MotorComponent(Vehicle *vehicle, AutoPilotPlugin *autopilot, QObject *parent = nullptr);

    QStringList setupCompleteChangedTriggerList() const override { return QStringList(); }
    QString name() const override { return _name; }
    QString description() const override { return QStringLiteral("Проверка моторов вручную: управление и направление вращения."); }
    QString iconResource() const override { return QStringLiteral("/qmlimages/MotorComponentIcon.svg"); }
    bool requiresSetup() const override { return false; }
    bool setupComplete() const override { return true; }
    QUrl setupSource() const override { return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/Common/MotorComponent.qml")); }
    QUrl summaryQmlSource() const override { return QUrl(); }

private:
    const QString _name;
};
