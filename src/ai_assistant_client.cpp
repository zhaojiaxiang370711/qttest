#include "ai_assistant_client.h"

#include "config.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

AiAssistantClient::AiAssistantClient(QObject *parent) : QObject(parent) {}

void AiAssistantClient::configure(const Config &config) {
    const bool wasConfigured = configured();
    m_baseUrl = config.cloudApiBase().trimmed();
    while (m_baseUrl.endsWith('/'))
        m_baseUrl.chop(1);
    m_deviceToken = config.deviceSyncToken().trimmed();
    if (wasConfigured != configured())
        emit configuredChanged();
}

bool AiAssistantClient::configured() const {
    const QUrl url(m_baseUrl);
    return url.isValid() && !url.host().isEmpty() && !m_deviceToken.isEmpty();
}

void AiAssistantClient::requestReply(const QString &requestId,
                                     const QString &userText,
                                     const QString &localReply,
                                     const QVariantMap &intake) {
    const QString id = requestId.trimmed();
    if (id.isEmpty()) {
        emit requestFailed(id, QStringLiteral("请求编号为空"));
        return;
    }
    if (!configured()) {
        emit requestFailed(id, QStringLiteral("未配置云端设备凭证"));
        return;
    }

    QJsonObject intakeJson;
    for (auto it = intake.cbegin(); it != intake.cend(); ++it)
        intakeJson.insert(it.key(), QJsonValue::fromVariant(it.value()));
    const QJsonObject payload{
        {QStringLiteral("request_id"), id},
        {QStringLiteral("user_text"), userText},
        {QStringLiteral("local_reply"), localReply},
        {QStringLiteral("intake"), intakeJson},
    };

    QNetworkRequest request(QUrl(m_baseUrl + QStringLiteral("/api/v1/ai/training-assistant")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("Accept", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + m_deviceToken.toUtf8());
    request.setTransferTimeout(30000);
    auto *reply = m_network.post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    m_requests.insert(reply, id);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const QString requestId = m_requests.take(reply);
        const QByteArray body = reply->readAll();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto document = QJsonDocument::fromJson(body);
        const auto object = document.object();
        if (reply->error() == QNetworkReply::NoError && status >= 200 && status < 300) {
            const QString text = object.value(QStringLiteral("text_result")).toString().trimmed();
            if (!text.isEmpty())
                emit replyReady(requestId, text);
            else
                emit requestFailed(requestId, QStringLiteral("云端返回了空回复"));
        } else {
            QString message = object.value(QStringLiteral("message")).toString().trimmed();
            if (message.isEmpty())
                message = reply->errorString();
            emit requestFailed(requestId, message);
        }
        reply->deleteLater();
    });
}

void AiAssistantClient::cancelAll() {
    const auto replies = m_requests.keys();
    m_requests.clear();
    for (QNetworkReply *reply : replies) {
        reply->disconnect(this);
        reply->abort();
        reply->deleteLater();
    }
}
