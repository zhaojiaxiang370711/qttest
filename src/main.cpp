// ============================================================
// 【教学导读】Qt Quick 应用的标准入口（main 函数）
// 标准四步：QGuiApplication → QQmlApplicationEngine 加载 QML
//   → C++ 与 QML 对象互相连接 → app.exec() 进入事件循环
// 本文件演示的 Qt 概念：
//   1. QGuiApplication — 每个 Qt GUI 程序有且只有一个的应用对象
//   2. qrc 内嵌资源 — ":/" 前缀路径（对应 CMakeLists 的 qt_add_resources）
//   3. loadFromModule — 按 QML 模块 URI 加载入口 QML
//   4. 信号槽 connect — C++ 侧连接 QML 单例对象的信号
//   5. QTimer::singleShot — 一次性延迟执行
// 配套阅读：CMakeLists.txt（QxznHmi 模块定义）、qml/Main.qml、src/qml_singletons.h
// ============================================================
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QQuickWindow>
#include <QTimer>
#include "config.h"
#include "course_playback_controller.h"
#include "dds_bridge.h"
#include "session_model.h"
#include "stats_store.h"

int main(int argc, char *argv[]) {
    // 每个 Qt GUI 程序有且只有一个 QGuiApplication：管理事件循环和应用级状态
    QGuiApplication app(argc, argv);
    app.setApplicationVersion(QStringLiteral(QXZN_HMI_VERSION));
    // 应用名/组织名决定 QStandardPaths 数据目录（SQLite 数据库就放在那里）：
    // ~/.local/share/qxzn/qxzn_hmi/
    app.setOrganizationName(QStringLiteral("qxzn"));
    app.setApplicationName(QStringLiteral("qxzn_hmi"));

    // ":/" 前缀表示 qrc 内嵌资源（对应 CMakeLists.txt 的 qt_add_resources），
    // 这里把编译进二进制的字体注册给 Qt，QML 里即可按字体名使用
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaShuHeiTi-Bold.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaAgileVF-Thin.ttf"));

    QQmlApplicationEngine engine;
    // 按"模块 URI + 类型名"加载 QML 入口：即 CMakeLists.txt 中 URI QxznHmi 模块里的 Main.qml
    engine.loadFromModule(QStringLiteral("QxznHmi"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty())
        return -1;

    // 从 C++ 取回 QML 单例对象（这些单例由 src/qml_singletons.h 注册），
    // 让 C++ 和 QML 操作同一个实例
    auto *config = engine.singletonInstance<Config *>(QStringLiteral("QxznHmi"), QStringLiteral("Config"));
    auto *ddsBridge = engine.singletonInstance<DdsBridge *>(QStringLiteral("QxznHmi"), QStringLiteral("DdsBridge"));
    auto *session = engine.singletonInstance<SessionModel *>(QStringLiteral("QxznHmi"), QStringLiteral("SessionModel"));
    auto *coursePlayer = engine.singletonInstance<CoursePlaybackController *>(QStringLiteral("QxznHmi"), QStringLiteral("CoursePlayer"));
    auto *stats = engine.singletonInstance<StatsStore *>(QStringLiteral("QxznHmi"), QStringLiteral("StatsStore"));
    if (!config || !ddsBridge || !session || !coursePlayer || !stats)
        return -1;

    // SQLite 统计接线：每次有效击打（键盘或 DDS 都会经过 SessionModel）记一笔；
    // 会话在启动时开一行、退出时补全时长与击打数
    stats->beginSession();
    QObject::connect(session, &SessionModel::strikesChanged, stats, [stats]() { stats->recordHit(); });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, stats,
                     [stats, session]() { stats->endSession(session->duration(), session->strikes()); });

    // CoursePlayer owns its GStreamer worker thread; configure media root +
    // decoder policy from the parsed Config and stop cleanly on quit so audio
    // and the worker thread never outlive the GUI.
    coursePlayer->configure(*config);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, coursePlayer, &CoursePlaybackController::stop);

    // 信号槽连接：ddsBridge 发出 hitReceived 时 lambda 会被调用——这是 Qt 最核心
    // 的对象通信机制；此处也演示了用 lambda 作为槽
    QObject::connect(ddsBridge, &DdsBridge::hitReceived, session,
                     [session](const QString &segment) { session->onSegment(segment); });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, ddsBridge, &DdsBridge::stop);
    ddsBridge->start(*config);

    QObject *root = engine.rootObjects().first();
    auto *window = qobject_cast<QQuickWindow *>(root);
    if (window) {
        // kiosk 全屏与调试窗口两种模式：默认 showFullScreen 全屏，--windowed 时 show 普通窗口
        if (config->windowed())
            window->show();
        else
            window->showFullScreen();
    }

    // smoke-test hooks: optional screenshot and/or quit after N ms
    const auto args = QGuiApplication::arguments().mid(1);
    QString screenshotPath;
    int quitAfterMs = -1;
    for (int i = 0; i + 1 < args.size(); ++i) {
        if (args.at(i) == QStringLiteral("--quit-after-ms"))
            quitAfterMs = args.at(i + 1).toInt();
        else if (args.at(i) == QStringLiteral("--screenshot"))
            screenshotPath = args.at(i + 1);
    }
    if (window && !screenshotPath.isEmpty()) {
        // grab shortly before the quit timer fires so pages/callouts have rendered
        const int grabDelay = quitAfterMs > 250 ? quitAfterMs - 150 : 800;
        QTimer::singleShot(grabDelay, window, [window, screenshotPath]() {
            window->grabWindow().save(screenshotPath);
        });
    }
    if (quitAfterMs > 0)
        // QTimer::singleShot：一次性定时器，常用于延迟执行（这里用于冒烟测试自动退出）
        QTimer::singleShot(quitAfterMs, &app, &QGuiApplication::quit);
    // 进入事件循环：程序在此阻塞，不断分发事件（输入、定时器、信号槽等），直到退出
    return app.exec();
}
