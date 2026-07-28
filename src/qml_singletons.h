#pragma once

#include "config.h"
#include "course_catalog.h"
#include "course_playback_controller.h"
#include "course_video_surface.h"
#include "dds_bridge.h"
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

struct CourseCatalogQmlForeign {
    Q_GADGET
    QML_FOREIGN(CourseCatalog)
    QML_NAMED_ELEMENT(CourseCatalog)
    QML_SINGLETON
public:
    static CourseCatalog *create(QQmlEngine *, QJSEngine *) {
        return new CourseCatalog;
    }
};

struct CoursePlayerQmlForeign {
    Q_GADGET
    QML_FOREIGN(CoursePlaybackController)
    QML_NAMED_ELEMENT(CoursePlayer)
    QML_SINGLETON
public:
    static CoursePlaybackController *create(QQmlEngine *, QJSEngine *) {
        return new CoursePlaybackController;
    }
};

struct CourseVideoSurfaceQmlForeign {
    Q_GADGET
    QML_FOREIGN(CourseVideoSurface)
    QML_NAMED_ELEMENT(CourseVideoSurface)
};

struct DdsBridgeQmlForeign {
    Q_GADGET
    QML_FOREIGN(DdsBridge)
    QML_NAMED_ELEMENT(DdsBridge)
    QML_SINGLETON
public:
    static DdsBridge *create(QQmlEngine *, QJSEngine *) {
        return new DdsBridge;
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
