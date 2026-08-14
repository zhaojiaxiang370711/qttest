#pragma once

#include <QHash>
#include <QNetworkAccessManager>
#include <QObject>
#include <QString>
#include <QVariantMap>

class Config;
class QNetworkReply;

// Low-frequency HTTPS client for the cloud AI broker. It sends only the
// revocable device token; the model provider key always stays on the server.
class AiAssistantClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool configured READ configured NOTIFY configuredChanged)
public:
    explicit AiAssistantClient(QObject *parent = nullptr);

    void configure(const Config &config);
    bool configured() const;

    Q_INVOKABLE void requestReply(const QString &requestId,
                                  const QString &userText,
                                  const QString &localReply,
                                  const QVariantMap &intake);
    Q_INVOKABLE void cancelAll();

signals:
    void configuredChanged();
    void replyReady(const QString &requestId, const QString &text);
    void requestFailed(const QString &requestId, const QString &message);

private:
    QNetworkAccessManager m_network;
    QString m_baseUrl;
    QString m_deviceToken;
    QHash<QNetworkReply *, QString> m_requests;
};
