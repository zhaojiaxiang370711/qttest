#pragma once

#include "config.h"
#include "session_model.h"

#include <QCoreApplication>
#include <QJSEngine>
#include <QQmlEngine>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

struct ConfigQmlForeign {
    Q_GADGET
    QML_FOREIGN(Config)
    QML_NAMED_ELEMENT(Config)
    QML_SINGLETON
public:
    static Config *create(QQmlEngine *, QJSEngine *) {
        auto *config = new Config;
        config->parse(QCoreApplication::arguments().mid(1));
        return config;
    }
};

struct SessionModelQmlForeign {
    Q_GADGET
    QML_FOREIGN(SessionModel)
    QML_NAMED_ELEMENT(SessionModel)
    QML_SINGLETON
public:
    static SessionModel *create(QQmlEngine *, QJSEngine *) {
        auto *session = new SessionModel;
        auto *durationTimer = new QTimer(session);
        durationTimer->setInterval(1000);
        QObject::connect(durationTimer, &QTimer::timeout, session, &SessionModel::onTick);
        durationTimer->start();
        return session;
    }
};
