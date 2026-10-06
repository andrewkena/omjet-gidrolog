#pragma once

#include "VehicleComponent.h"

class APMFlightModesComponent : public VehicleComponent
{
    Q_OBJECT

public:
    APMFlightModesComponent(Vehicle *vehicle, AutoPilotPlugin *autopilot, QObject *parent = nullptr);

    QStringList setupCompleteChangedTriggerList() const final { return QStringList(); }

    QString name() const final { return _name; }
    QString description() const final { return QStringLiteral("Назначение переключателей пульта и выбор режимов."); }
    QString iconResource() const final { return QStringLiteral("/qmlimages/FlightModesComponentIcon.png"); }
    bool requiresSetup() const final { return true; }
    bool setupComplete() const final { return true; }
    QUrl setupSource() const final { return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightModesComponent.qml")); }
    QUrl summaryQmlSource() const final { return QUrl::fromUserInput(QStringLiteral("qrc:/qml/QGroundControl/AutoPilotPlugins/APM/APMFlightModesComponentSummary.qml")); }

private:
    const QString _name = QStringLiteral("Режимы");
};
