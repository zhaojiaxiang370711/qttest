#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QQuickWindow>
#include <QTimer>
#include "config.h"
#include "course_playback_controller.h"
#include "dds_bridge.h"
#include "session_model.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaShuHeiTi-Bold.ttf"));
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaAgileVF-Thin.ttf"));

    QQmlApplicationEngine engine;
    engine.loadFromModule(QStringLiteral("QxznHmi"), QStringLiteral("Main"));
    if (engine.rootObjects().isEmpty())
        return -1;

    auto *config = engine.singletonInstance<Config *>(QStringLiteral("QxznHmi"), QStringLiteral("Config"));
    auto *ddsBridge = engine.singletonInstance<DdsBridge *>(QStringLiteral("QxznHmi"), QStringLiteral("DdsBridge"));
    auto *session = engine.singletonInstance<SessionModel *>(QStringLiteral("QxznHmi"), QStringLiteral("SessionModel"));
    auto *coursePlayer = engine.singletonInstance<CoursePlaybackController *>(QStringLiteral("QxznHmi"), QStringLiteral("CoursePlayer"));
    if (!config || !ddsBridge || !session || !coursePlayer)
        return -1;

    // CoursePlayer owns its GStreamer worker thread; configure media root +
    // decoder policy from the parsed Config and stop cleanly on quit so audio
    // and the worker thread never outlive the GUI.
    coursePlayer->configure(*config);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, coursePlayer, &CoursePlaybackController::stop);

    QObject::connect(ddsBridge, &DdsBridge::hitReceived, session,
                     [session](const QString &segment) { session->onSegment(segment); });
    QObject::connect(&app, &QCoreApplication::aboutToQuit, ddsBridge, &DdsBridge::stop);
    ddsBridge->start(*config);

    QObject *root = engine.rootObjects().first();
    auto *window = qobject_cast<QQuickWindow *>(root);
    if (window) {
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
        QTimer::singleShot(quitAfterMs, &app, &QGuiApplication::quit);
    return app.exec();
}
