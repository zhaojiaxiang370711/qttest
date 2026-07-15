#pragma once
#include <QObject>
#include <QString>
#include <QStringList>

class Config : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString wsUrl READ wsUrl NOTIFY configChanged)
    Q_PROPERTY(QString apiBase READ apiBase NOTIFY configChanged)
    Q_PROPERTY(QString gameId READ gameId NOTIFY configChanged)
    Q_PROPERTY(QString difficulty READ difficulty NOTIFY configChanged)
    Q_PROPERTY(int maxFps READ maxFps NOTIFY configChanged)
    Q_PROPERTY(bool windowed READ windowed NOTIFY configChanged)
public:
    explicit Config(QObject *parent = nullptr);
    Q_INVOKABLE void parse(const QStringList &args);
    QString wsUrl() const { return m_wsUrl; }
    QString apiBase() const { return m_apiBase; }
    QString gameId() const { return m_gameId; }
    QString difficulty() const { return m_difficulty; }
    int maxFps() const { return m_maxFps; }
    bool windowed() const { return m_windowed; }
signals:
    void configChanged();
private:
    QString m_wsUrl   = QStringLiteral("ws://localhost:8000/ws");
    QString m_apiBase = QStringLiteral("http://localhost:8000");
    QString m_gameId  = QStringLiteral("qxzn_hmi");
    QString m_difficulty = QStringLiteral("simple");
    int m_maxFps = 60;
    bool m_windowed = false;
};
