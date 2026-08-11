// ============================================================
// 【教学导读】命令行/环境变量配置类
// 演示"多个属性共用一个 NOTIFY 信号 configChanged"的写法：
// 配置一次性解析完，发一次通知即可，不必每个属性各配一个信号
// 配套阅读：src/config.cpp（解析逻辑）、src/qml_singletons.h（暴露给 QML）
// ============================================================
#pragma once
#include <QObject>
#include <QString>
#include <QStringList>

class Config : public QObject {
    Q_OBJECT
    // 注意下面所有属性的 NOTIFY 都是同一个 configChanged：任一配置变化只发一次统一通知
    Q_PROPERTY(QString wsUrl READ wsUrl NOTIFY configChanged)
    Q_PROPERTY(QString apiBase READ apiBase NOTIFY configChanged)
    Q_PROPERTY(QString gameId READ gameId NOTIFY configChanged)
    Q_PROPERTY(QString difficulty READ difficulty NOTIFY configChanged)
    Q_PROPERTY(int maxFps READ maxFps NOTIFY configChanged)
    Q_PROPERTY(bool windowed READ windowed NOTIFY configChanged)
    Q_PROPERTY(QString initialNav READ initialNav NOTIFY configChanged)
    Q_PROPERTY(QString initialOverlay READ initialOverlay NOTIFY configChanged)
    Q_PROPERTY(QString mediaRoot READ mediaRoot NOTIFY configChanged)
    Q_PROPERTY(QString initialCourse READ initialCourse NOTIFY configChanged)
    Q_PROPERTY(QString initialSubgame READ initialSubgame NOTIFY configChanged)
    Q_PROPERTY(bool ddsEnabled READ ddsEnabled NOTIFY configChanged)
    Q_PROPERTY(QString ddsCoreLib READ ddsCoreLib NOTIFY configChanged)
    Q_PROPERTY(int ddsDomainId READ ddsDomainId NOTIFY configChanged)
    Q_PROPERTY(bool ddsMulticast READ ddsMulticast NOTIFY configChanged)
    Q_PROPERTY(QString ddsInitialPeers READ ddsInitialPeers NOTIFY configChanged)
    Q_PROPERTY(QString ddsParticipant READ ddsParticipant NOTIFY configChanged)
    Q_PROPERTY(QString ddsHitEventTopic READ ddsHitEventTopic NOTIFY configChanged)
    Q_PROPERTY(QString ddsLedCommandTopic READ ddsLedCommandTopic NOTIFY configChanged)
public:
    explicit Config(QObject *parent = nullptr);
    Q_INVOKABLE void parse(const QStringList &args);
    QString wsUrl() const { return m_wsUrl; }
    QString apiBase() const { return m_apiBase; }
    QString gameId() const { return m_gameId; }
    QString difficulty() const { return m_difficulty; }
    int maxFps() const { return m_maxFps; }
    bool windowed() const { return m_windowed; }
    QString initialNav() const { return m_initialNav; }
    QString initialOverlay() const { return m_initialOverlay; }
    QString mediaRoot() const { return m_mediaRoot; }
    QString initialCourse() const { return m_initialCourse; }
    QString initialSubgame() const { return m_initialSubgame; }
    bool ddsEnabled() const { return m_ddsEnabled; }
    QString ddsCoreLib() const { return m_ddsCoreLib; }
    int ddsDomainId() const { return m_ddsDomainId; }
    bool ddsMulticast() const { return m_ddsMulticast; }
    QString ddsInitialPeers() const { return m_ddsInitialPeers; }
    QString ddsParticipant() const { return m_ddsParticipant; }
    QString ddsHitEventTopic() const { return m_ddsHitEventTopic; }
    QString ddsLedCommandTopic() const { return m_ddsLedCommandTopic; }
signals:
    void configChanged();
private:
    void resetDefaults();

    QString m_wsUrl   = QStringLiteral("ws://localhost:8000/ws");
    QString m_apiBase = QStringLiteral("http://localhost:8000");
    QString m_gameId  = QStringLiteral("qxzn_hmi");
    QString m_difficulty = QStringLiteral("simple");
    int m_maxFps = 60;
    bool m_windowed = false;
    QString m_initialNav = QStringLiteral("home");
    QString m_initialOverlay;
    QString m_mediaRoot;
    QString m_initialCourse = QStringLiteral("special_practice");
    QString m_initialSubgame;
    bool m_ddsEnabled = true;
    QString m_ddsCoreLib;
    int m_ddsDomainId = 37;
    bool m_ddsMulticast = false;
    QString m_ddsInitialPeers = QStringLiteral("127.0.0.1");
    QString m_ddsParticipant = QStringLiteral("pd02-qt-hmi");
    QString m_ddsHitEventTopic = QStringLiteral("pd02/hit/event");
    QString m_ddsLedCommandTopic = QStringLiteral("pd02/led/command");
};
