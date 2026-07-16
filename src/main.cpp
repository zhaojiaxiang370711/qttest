#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QFontDatabase>
#include <QQuickWindow>
#include <QTimer>
#include "config.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaShuHeiTi-Bold.ttf"));

    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    auto *config = engine.singletonInstance<Config *>(QStringLiteral("QxznHmi"), QStringLiteral("Config"));
    if (!config)
        return -1;

    QObject *root = engine.rootObjects().first();
    auto *window = qobject_cast<QQuickWindow *>(root);
    if (window) {
        if (config->windowed())
            window->show();
        else
            window->showFullScreen();
    }

    // smoke-test hook: quit after N ms if requested
    const auto args = QGuiApplication::arguments().mid(1);
    for (int i = 0; i + 1 < args.size(); ++i) {
        if (args.at(i) == QStringLiteral("--quit-after-ms")) {
            QTimer::singleShot(args.at(i + 1).toInt(), &app, &QGuiApplication::quit);
        }
    }
    return app.exec();
}
