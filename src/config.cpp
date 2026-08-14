// ============================================================
// 【教学导读】配置解析：默认值 -> 环境变量 -> 命令行（优先级递增）
// parse() 的顺序体现优先级：先 resetDefaults，再读环境变量
// （PD02_DDS_* / QXZN_MEDIA_DIR），最后扫命令行参数，
// 所以 --xxx 命令行参数永远覆盖环境变量和默认值。
// 匿名命名空间（namespace { ... }）是 C++ 惯例：里面的函数只在本文件可见，
// 等价于 static，不会污染外部符号表。
// 配套阅读：src/config.h
// ============================================================
#include "config.h"

#include <QFile>
#include <QtGlobal>

namespace {

bool envBool(const char *name, bool fallback) {
    if (!qEnvironmentVariableIsSet(name))
        return fallback;
    const QString value = QString::fromUtf8(qgetenv(name)).trimmed().toLower();
    return value == QStringLiteral("1") || value == QStringLiteral("true") ||
           value == QStringLiteral("yes") || value == QStringLiteral("on");
}

QString envString(const char *name, const QString &fallback) {
    if (!qEnvironmentVariableIsSet(name))
        return fallback;
    const QString value = QString::fromUtf8(qgetenv(name)).trimmed();
    return value.isEmpty() ? fallback : value;
}

int envInt(const char *name, int fallback) {
    if (!qEnvironmentVariableIsSet(name))
        return fallback;
    bool ok = false;
    const int value = QString::fromUtf8(qgetenv(name)).trimmed().toInt(&ok);
    return ok ? value : fallback;
}

QString readSecretFile(const QString &path) {
    if (path.trimmed().isEmpty())
        return {};
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return {};
    return QString::fromUtf8(file.readAll()).trimmed();
}

} // namespace

Config::Config(QObject *parent) : QObject(parent) {}

void Config::resetDefaults() {
    m_wsUrl = QStringLiteral("ws://localhost:8000/ws");
    m_apiBase = QStringLiteral("http://localhost:8000");
    m_cloudApiBase = QStringLiteral("https://cloud.qxrobot.com");
    m_deviceSyncToken.clear();
    m_gameId = QStringLiteral("qxzn_hmi");
    m_difficulty = QStringLiteral("simple");
    m_maxFps = 60;
    m_windowed = false;
    m_initialNav = QStringLiteral("home");
    m_initialOverlay.clear();
    m_mediaRoot.clear();
    m_initialCourse = QStringLiteral("special_practice");
    m_initialSubgame.clear();
    m_ddsEnabled = true;
    m_ddsCoreLib.clear();
    m_ddsDomainId = 37;
    m_ddsMulticast = false;
    m_ddsInitialPeers = QStringLiteral("127.0.0.1");
    m_ddsParticipant = QStringLiteral("pd02-qt-hmi");
    m_ddsHitEventTopic = QStringLiteral("pd02/hit/event");
    m_ddsLedCommandTopic = QStringLiteral("pd02/led/command");
}

void Config::parse(const QStringList &args) {
    resetDefaults();

    // 第一步：读环境变量（PD02_DDS_* / QXZN_MEDIA_DIR）作为基础值
    m_mediaRoot = envString("QXZN_MEDIA_DIR", m_mediaRoot);
    m_cloudApiBase = envString("QXZN_CLOUD_API_BASE", m_cloudApiBase);
    m_deviceSyncToken = readSecretFile(envString("QXZN_DEVICE_SYNC_TOKEN_FILE", {}));
    if (m_deviceSyncToken.isEmpty())
        m_deviceSyncToken = envString("QXZN_DEVICE_SYNC_TOKEN", {});
    m_ddsEnabled = envBool("PD02_DDS_ENABLE", m_ddsEnabled);
    m_ddsCoreLib = envString("PD02_DDS_CORE_LIB", m_ddsCoreLib);
    const int environmentDomainId = envInt("PD02_DDS_DOMAIN_ID", m_ddsDomainId);
    if (environmentDomainId >= 0)
        m_ddsDomainId = environmentDomainId;
    m_ddsMulticast = envBool("PD02_DDS_MULTICAST", m_ddsMulticast);
    m_ddsInitialPeers = envString("PD02_DDS_INITIAL_PEERS", m_ddsInitialPeers);
    m_ddsParticipant = envString("PD02_DDS_PARTICIPANT_NAME", m_ddsParticipant);
    m_ddsHitEventTopic = envString("PD02_DDS_HIT_EVENT_TOPIC", m_ddsHitEventTopic);
    m_ddsLedCommandTopic = envString("PD02_DDS_LED_COMMAND_TOPIC", m_ddsLedCommandTopic);

    // 第二步：命令行参数覆盖环境变量，优先级更高
    for (int i = 0; i < args.size(); ++i) {
        const QString &a = args.at(i);
        auto next = [&]() -> QString { return (i + 1 < args.size()) ? args.at(++i) : QString(); };
        if (a == QStringLiteral("--ws-url")) m_wsUrl = next();
        else if (a == QStringLiteral("--api-base")) m_apiBase = next();
        else if (a == QStringLiteral("--cloud-api-base")) m_cloudApiBase = next();
        else if (a == QStringLiteral("--device-sync-token-file")) m_deviceSyncToken = readSecretFile(next());
        else if (a == QStringLiteral("--game-id")) m_gameId = next();
        else if (a == QStringLiteral("--difficulty")) m_difficulty = next();
        else if (a == QStringLiteral("--max-fps")) m_maxFps = next().toInt();
        else if (a == QStringLiteral("--windowed")) m_windowed = true;
        else if (a == QStringLiteral("--nav")) m_initialNav = next();
        else if (a == QStringLiteral("--overlay")) m_initialOverlay = next();
        else if (a == QStringLiteral("--media-root")) m_mediaRoot = next();
        else if (a == QStringLiteral("--course")) m_initialCourse = next();
        else if (a == QStringLiteral("--subgame")) m_initialSubgame = next();
        else if (a == QStringLiteral("--dds")) m_ddsEnabled = true;
        else if (a == QStringLiteral("--no-dds")) m_ddsEnabled = false;
        else if (a == QStringLiteral("--dds-core-lib")) m_ddsCoreLib = next();
        else if (a == QStringLiteral("--dds-domain-id")) {
            bool ok = false;
            const int value = next().toInt(&ok);
            if (ok && value >= 0)
                m_ddsDomainId = value;
        }
        else if (a == QStringLiteral("--dds-multicast")) m_ddsMulticast = true;
        else if (a == QStringLiteral("--no-dds-multicast")) m_ddsMulticast = false;
        else if (a == QStringLiteral("--dds-initial-peers")) m_ddsInitialPeers = next();
        else if (a == QStringLiteral("--dds-participant")) m_ddsParticipant = next();
        else if (a == QStringLiteral("--dds-hit-event-topic")) m_ddsHitEventTopic = next();
        else if (a == QStringLiteral("--dds-led-command-topic")) m_ddsLedCommandTopic = next();
        // unknown args ignored
    }
    // 解析完成后统一发一次变更通知（对应 config.h 里所有属性共用的 NOTIFY 信号）
    emit configChanged();
}
