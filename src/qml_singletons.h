// ============================================================
// 【教学导读】把已有 C++ 类暴露给 QML 的 Qt 6 现代写法（QML_FOREIGN 方式）
// QML 里能写 "SessionModel.strikes"，靠的就是这套宏
//   + CMakeLists.txt 里 qt_add_qml_module 的 SOURCES 收录本文件
// 本文件演示的 Qt 概念：
//   1. Q_GADGET — 让非 QObject 的 struct 获得元对象能力，可挂 QML_* 宏
//   2. QML_FOREIGN(T) — 声明 QML 类型的真正实现是已存在的 C++ 类 T
//   3. QML_NAMED_ELEMENT / QML_SINGLETON — 指定 QML 侧名字、注册为单例
//   4. 单例工厂 create() — QML 引擎首次访问单例时调用
// 配套阅读：src/main.cpp（singletonInstance 取回单例）、CMakeLists.txt
// ============================================================
#pragma once

#include "config.h"
#include "ai_assistant_client.h"
#include "course_catalog.h"
#include "course_playback_controller.h"
#include "course_video_surface.h"
#include "dds_bridge.h"
#include "face_height_guide_client.h"
#include "game_launcher_client.h"
#include "session_model.h"
#include "stats_store.h"

#include <QCoreApplication>
#include <QJSEngine>
#include <QQmlEngine>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// 下面每个 struct 都是同一套模式，以第一个为例逐个宏讲解：
struct ConfigQmlForeign {
    // Q_GADGET：让非 QObject 的 struct 获得元对象能力，可挂 QML_* 宏
    Q_GADGET
    // QML_FOREIGN(Config)：声明 QML 类型的真正实现是已存在的类 Config
    QML_FOREIGN(Config)
    // QML_NAMED_ELEMENT(Config)：QML 里看到的名字就叫 Config
    QML_NAMED_ELEMENT(Config)
    // QML_SINGLETON：注册为 QML 单例，全局唯一实例
    QML_SINGLETON
public:
    // 单例工厂：QML 引擎首次访问该单例时调用；返回裸指针，所有权归 QML 引擎
    static Config *create(QQmlEngine *, QJSEngine *) {
        auto *config = new Config;
        config->parse(QCoreApplication::arguments().mid(1));
        return config;
    }
};

struct AiAssistantClientQmlForeign {
    Q_GADGET
    QML_FOREIGN(AiAssistantClient)
    QML_NAMED_ELEMENT(AiAssistantClient)
    QML_SINGLETON
public:
    static AiAssistantClient *create(QQmlEngine *, QJSEngine *) {
        return new AiAssistantClient;
    }
};

struct GameLauncherQmlForeign {
    Q_GADGET
    QML_FOREIGN(GameLauncherClient)
    QML_NAMED_ELEMENT(GameLauncher)
    QML_SINGLETON
public:
    static GameLauncherClient *create(QQmlEngine *, QJSEngine *) {
        return new GameLauncherClient;
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

struct FaceHeightGuideQmlForeign {
    Q_GADGET
    QML_FOREIGN(FaceHeightGuideClient)
    QML_NAMED_ELEMENT(FaceHeightGuide)
    QML_SINGLETON
public:
    static FaceHeightGuideClient *create(QQmlEngine *, QJSEngine *) {
        return new FaceHeightGuideClient;
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
        // 以 session 为父对象：Qt 的父子对象树会在父对象销毁时自动删除子对象，不用手动 delete
        auto *durationTimer = new QTimer(session);
        durationTimer->setInterval(1000);
        QObject::connect(durationTimer, &QTimer::timeout, session, &SessionModel::onTick);
        durationTimer->start();
        return session;
    }
};

// SQLite 统计存储：QML 里用 StatsStore.todayStrikes 等读取（见 stats_store.h）
struct StatsStoreQmlForeign {
    Q_GADGET
    QML_FOREIGN(StatsStore)
    QML_NAMED_ELEMENT(StatsStore)
    QML_SINGLETON
public:
    static StatsStore *create(QQmlEngine *, QJSEngine *) {
        return new StatsStore;
    }
};
