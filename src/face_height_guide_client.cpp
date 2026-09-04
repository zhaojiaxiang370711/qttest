#include "face_height_guide_client.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QUuid>

namespace {

QString compactFailure(const QByteArray &output) {
    QString text = QString::fromUtf8(output).trimmed();
    text.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral(" "));
    if (text.size() > 300)
        text = text.left(297) + QStringLiteral("...");
    return text;
}

} // namespace

FaceHeightGuideClient::FaceHeightGuideClient(QObject *parent)
    : QObject(parent) {
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    m_timeout.setSingleShot(true);
    // The vision service may hold a start request while waiting for a person
    // to be detected; the helper's own call timeout is 20 s, so allow
    // comfortable headroom over helper startup plus that wait.
    m_timeout.setInterval(30000);

    connect(&m_timeout, &QTimer::timeout, this, [this]() {
        if (!m_busy)
            return;
        m_process.kill();
        complete(false, QStringLiteral("视觉服务响应超时"), QStringLiteral("error"));
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart && m_busy) {
            complete(false, QStringLiteral("无法启动高度引导通信程序：%1")
                                .arg(m_process.errorString()),
                     QStringLiteral("error"));
        }
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this](int exitCode, QProcess::ExitStatus exitStatus) {
        if (!m_busy)
            return;

        m_timeout.stop();
        const QByteArray output = m_process.readAll();
        const QString text = QString::fromUtf8(output);
        const QRegularExpression successPattern(
            QStringLiteral(R"((?:success\s*=\s*|success\s*:\s*)(true|false))"),
            QRegularExpression::CaseInsensitiveOption);
        const QRegularExpression messagePattern(
            QStringLiteral(R"((?:message\s*=\s*['"]([^'"]*)['"]|message\s*:\s*['"]?([^\r\n'"}]+)))"),
            QRegularExpression::CaseInsensitiveOption);
        const auto successMatch = successPattern.match(text);
        const auto messageMatch = messagePattern.match(text);

        if (exitStatus != QProcess::NormalExit || exitCode != 0 || !successMatch.hasMatch()) {
            QString failure = compactFailure(output);
            if (failure.isEmpty())
                failure = QStringLiteral("高度引导服务调用失败");
            complete(false, failure, QStringLiteral("error"));
            return;
        }

        const bool success = successMatch.captured(1).compare(
            QStringLiteral("true"), Qt::CaseInsensitive) == 0;
        QString responseMessage;
        if (messageMatch.hasMatch())
            responseMessage = messageMatch.captured(1).isEmpty()
                ? messageMatch.captured(2).trimmed()
                : messageMatch.captured(1).trimmed();
        if (responseMessage.isEmpty())
            responseMessage = success ? QStringLiteral("started") : QStringLiteral("服务拒绝请求");

        const bool noPerson = responseMessage.compare(QStringLiteral("no person"), Qt::CaseInsensitive) == 0;
        complete(success, responseMessage,
                 success ? QStringLiteral("started")
                         : (noPerson ? QStringLiteral("no_person") : QStringLiteral("error")));
    });
}

FaceHeightGuideClient::~FaceHeightGuideClient() {
    if (m_process.state() != QProcess::NotRunning) {
        m_process.kill();
        m_process.waitForFinished(1000);
    }
}

bool FaceHeightGuideClient::start(const QString &requestedId) {
    if (m_busy)
        return false;

    const QString helper = helperPath();
    if (helper.isEmpty()) {
        complete(false, QStringLiteral("缺少高度引导 ROS2 通信程序"), QStringLiteral("error"));
        return false;
    }

    QString effectiveId = requestedId.trimmed();
    if (effectiveId.isEmpty())
        effectiveId = QUuid::createUuid().toString(QUuid::WithoutBraces);

    setRequestId(effectiveId);
    setMessage(QStringLiteral("正在请求视觉服务"));
    setState(QStringLiteral("calling"));
    setBusy(true);

    m_process.setProcessEnvironment(QProcessEnvironment::systemEnvironment());
    m_process.setProgram(helper);
    m_process.setArguments({effectiveId});
    m_process.start();
    m_timeout.start();
    return true;
}

QString FaceHeightGuideClient::helperPath() const {
    const QString configured = QString::fromUtf8(qgetenv("QXZN_FACE_HEIGHT_GUIDE_HELPER")).trimmed();
    if (!configured.isEmpty() && QFileInfo(configured).isExecutable())
        return configured;

    const QString bundled = QCoreApplication::applicationDirPath() +
        QStringLiteral("/call_face_height_guide.sh");
    if (QFileInfo(bundled).isExecutable())
        return bundled;
    return QString();
}

void FaceHeightGuideClient::complete(bool success, const QString &message, const QString &state) {
    m_timeout.stop();
    setMessage(message);
    setState(state);
    setBusy(false);
    emit resultReceived(success, message, m_requestId);
}

void FaceHeightGuideClient::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void FaceHeightGuideClient::setState(const QString &state) {
    if (m_state == state)
        return;
    m_state = state;
    emit stateChanged();
}

void FaceHeightGuideClient::setMessage(const QString &message) {
    if (m_message == message)
        return;
    m_message = message;
    emit messageChanged();
}

void FaceHeightGuideClient::setRequestId(const QString &requestId) {
    if (m_requestId == requestId)
        return;
    m_requestId = requestId;
    emit requestIdChanged();
}
