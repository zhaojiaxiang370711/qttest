#include "game_launcher_client.h"

#include "config.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

GameLauncherClient::GameLauncherClient(QObject *parent) : QObject(parent) {}

void GameLauncherClient::configure(const Config &config) {
    m_baseUrl = config.apiBase().trimmed();
    while (m_baseUrl.endsWith('/'))
        m_baseUrl.chop(1);
}

bool GameLauncherClient::launchGame(const QString &gameId) {
    const QString id = gameId.trimmed();
    if (id != QStringLiteral("vr_beats_kit")) {
        const QString message = QStringLiteral("该游戏尚未接入启动服务");
        setLastError(message);
        emit launchFailed(id, message);
        return false;
    }
    if (busy()) {
        const QString message = QStringLiteral("游戏启动请求正在处理中");
        setLastError(message);
        emit launchFailed(id, message);
        return false;
    }

    const QUrl base(m_baseUrl);
    if (!base.isValid() || base.scheme().isEmpty() || base.host().isEmpty()) {
        const QString message = QStringLiteral("本地游戏服务地址无效");
        setLastError(message);
        emit launchFailed(id, message);
        return false;
    }

    setLastError({});
    m_gameId = id;
    QNetworkRequest request(QUrl(m_baseUrl + QStringLiteral("/api/v1/game/start")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/json");
    request.setTransferTimeout(8000);
    const QJsonObject payload{{QStringLiteral("game"), id}};
    m_reply = m_network.post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    emit busyChanged();

    connect(m_reply, &QNetworkReply::finished, this, [this]() {
        QNetworkReply *reply = m_reply;
        if (!reply)
            return;
        const QString gameId = m_gameId;
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(body, &parseError);
        const QJsonObject object = parseError.error == QJsonParseError::NoError && document.isObject()
            ? document.object() : QJsonObject{};
        m_reply = nullptr;
        m_gameId.clear();
        emit busyChanged();

        if (reply->error() == QNetworkReply::NoError && status >= 200 && status < 300) {
            setLastError({});
            emit launchAccepted(gameId);
        } else {
            QString message = object.value(QStringLiteral("message")).toString().trimmed();
            if (message.isEmpty())
                message = object.value(QStringLiteral("error")).toString().trimmed();
            if (message.isEmpty())
                message = reply->errorString();
            setLastError(message);
            emit launchFailed(gameId, message);
        }
        reply->deleteLater();
    });
    return true;
}

void GameLauncherClient::cancel() {
    if (!m_reply)
        return;
    QNetworkReply *reply = m_reply;
    m_reply = nullptr;
    m_gameId.clear();
    reply->disconnect(this);
    reply->abort();
    reply->deleteLater();
    emit busyChanged();
}

void GameLauncherClient::setLastError(const QString &message) {
    if (m_lastError == message)
        return;
    m_lastError = message;
    emit lastErrorChanged();
}
