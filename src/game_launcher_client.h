#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QString>

class Config;
class QNetworkReply;

// Thin client for the App game-process API. The server owns the actual
// Qt -> Godot -> Qt handoff so display and process lifecycle rules stay in one
// place instead of being duplicated in the HMI.
class GameLauncherClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
public:
    explicit GameLauncherClient(QObject *parent = nullptr);

    void configure(const Config &config);
    bool busy() const { return m_reply != nullptr; }
    QString lastError() const { return m_lastError; }

    Q_INVOKABLE bool launchGame(const QString &gameId);
    Q_INVOKABLE void cancel();

signals:
    void busyChanged();
    void lastErrorChanged();
    void launchAccepted(const QString &gameId);
    void launchFailed(const QString &gameId, const QString &message);

private:
    void setLastError(const QString &message);

    QNetworkAccessManager m_network;
    QString m_baseUrl;
    QString m_gameId;
    QString m_lastError;
    QNetworkReply *m_reply = nullptr;
};
