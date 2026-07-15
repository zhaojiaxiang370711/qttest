#include "config.h"

Config::Config(QObject *parent) : QObject(parent) {}

void Config::parse(const QStringList &args) {
    for (int i = 0; i < args.size(); ++i) {
        const QString &a = args.at(i);
        auto next = [&]() -> QString { return (i + 1 < args.size()) ? args.at(++i) : QString(); };
        if (a == QStringLiteral("--ws-url")) m_wsUrl = next();
        else if (a == QStringLiteral("--api-base")) m_apiBase = next();
        else if (a == QStringLiteral("--game-id")) m_gameId = next();
        else if (a == QStringLiteral("--difficulty")) m_difficulty = next();
        else if (a == QStringLiteral("--max-fps")) m_maxFps = next().toInt();
        else if (a == QStringLiteral("--windowed")) m_windowed = true;
        // unknown args ignored
    }
}
