#include "dds_bridge.h"

#include "config.h"
#include "segment_input.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDebug>
#include <QElapsedTimer>
#include <QLibrary>
#include <QTimer>
#include <algorithm>
#include <cstring>

#if QXZN_HMI_DDS
#include "dds_bridge_api.h"
#ifndef QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB
#define QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB ""
#endif
#endif

namespace {

#if QXZN_HMI_DDS

template <std::size_t Size>
QString fixedString(const char (&value)[Size]) {
    std::size_t length = 0;
    while (length < Size && value[length] != '\0')
        ++length;
    return QString::fromUtf8(value, int(length));
}

template <std::size_t Size>
void writeFixed(char (&target)[Size], const QString &value) {
    std::memset(target, 0, Size);
    const QByteArray utf8 = value.toUtf8();
    const std::size_t length = std::min<std::size_t>(Size - 1, std::size_t(utf8.size()));
    std::memcpy(target, utf8.constData(), length);
}

QString errorString(const char *error, std::size_t size) {
    std::size_t length = 0;
    while (length < size && error[length] != '\0')
        ++length;
    return QString::fromUtf8(error, int(length));
}

#endif

} // namespace

class DdsBridge::Impl {
public:
    explicit Impl(DdsBridge *owner)
        : q(owner) {
#if QXZN_HMI_DDS
        initializeTimers();
        processSessionId = QStringLiteral("pd02-qt-hmi-%1-%2")
            .arg(QCoreApplication::applicationPid())
            .arg(QDateTime::currentMSecsSinceEpoch());
#endif
    }

#if QXZN_HMI_DDS
    Impl(DdsBridge *owner, const DdsApi &injectedApi)
        : q(owner), api(injectedApi), injected(true) {
        initializeTimers();
        processSessionId = QStringLiteral("pd02-qt-hmi-%1-%2")
            .arg(QCoreApplication::applicationPid())
            .arg(QDateTime::currentMSecsSinceEpoch());
    }
#endif

    void setEnabled(bool value) {
        if (enabled == value)
            return;
        enabled = value;
        emit q->enabledChanged();
    }

    void setState(const QString &value) {
        if (state == value)
            return;
        state = value;
        emit q->stateChanged();
    }

    void setReady(bool value) {
        if (ready == value)
            return;
        ready = value;
        emit q->readyChanged();
    }

    void setLastError(const QString &value) {
        if (lastError == value)
            return;
        lastError = value;
        emit q->lastErrorChanged();
    }

    void setLastHit(const QString &segment, qint64 receivedAtMs) {
        if (lastHitSegment != segment) {
            lastHitSegment = segment;
            emit q->lastHitSegmentChanged();
        }
        if (lastHitAtMs != receivedAtMs) {
            lastHitAtMs = receivedAtMs;
            emit q->lastHitAtMsChanged();
        }
    }

    void start(const Config &config) {
#if QXZN_HMI_DDS
        retryTimer.stop();
        closeTransport();
        coreLib = config.ddsCoreLib();
        domainId = config.ddsDomainId();
        multicast = config.ddsMulticast();
        initialPeers = config.ddsInitialPeers();
        participant = config.ddsParticipant();
        hitEventTopic = config.ddsHitEventTopic();
        ledCommandTopic = config.ddsLedCommandTopic();
        retryDelayMs = 2000;
        consecutivePublishFailures = 0;
        setEnabled(config.ddsEnabled());
        if (!enabled) {
            setLastError(QString());
            setState(QStringLiteral("disabled"));
            return;
        }
        attemptOpen();
#else
        Q_UNUSED(config);
        setEnabled(false);
        setReady(false);
        setLastError(QString());
        setState(QStringLiteral("disabled"));
#endif
    }

    void shutdown() {
#if QXZN_HMI_DDS
        retryTimer.stop();
        receivingTimer.stop();
        closeTransport();
#endif
        setReady(false);
        setState(QStringLiteral("disabled"));
    }

#if QXZN_HMI_DDS
    void initializeTimers() {
        pollTimer.setInterval(10);
        retryTimer.setSingleShot(true);
        receivingTimer.setSingleShot(true);
        receivingTimer.setInterval(2000);
        QObject::connect(&pollTimer, &QTimer::timeout, q, [this]() { pollHits(); });
        QObject::connect(&retryTimer, &QTimer::timeout, q, [this]() { attemptOpen(); });
        QObject::connect(&receivingTimer, &QTimer::timeout, q, [this]() {
            if (ready && state == QStringLiteral("receiving"))
                setState(QStringLiteral("ready"));
        });
    }

    bool loadDynamicApi(QString *failure) {
        api = {};
        if (library.isLoaded())
            library.unload();

        QStringList candidates;
        if (!coreLib.isEmpty()) {
            candidates.append(coreLib);
        } else {
            candidates.append(QCoreApplication::applicationDirPath() +
                              QStringLiteral("/libqxzn_pd02_dds_core.so"));
            const QString development = QString::fromUtf8(QXZN_HMI_DDS_DEVELOPMENT_CORE_LIB);
            if (!development.isEmpty() && !candidates.contains(development))
                candidates.append(development);
        }

        QStringList errors;
        for (const QString &candidate : candidates) {
            library.setFileName(candidate);
            if (!library.load()) {
                errors.append(QStringLiteral("%1: %2").arg(candidate, library.errorString()));
                continue;
            }

            DdsApi resolved;
            resolved.create = reinterpret_cast<DdsApi::CreateFn>(
                library.resolve("qxzn_pd02_dds_create"));
            resolved.destroy = reinterpret_cast<DdsApi::DestroyFn>(
                library.resolve("qxzn_pd02_dds_destroy"));
            resolved.takeHitEvent = reinterpret_cast<DdsApi::TakeHitEventFn>(
                library.resolve("qxzn_pd02_dds_take_hit_event"));
            resolved.publishLedCommand = reinterpret_cast<DdsApi::PublishLedCommandFn>(
                library.resolve("qxzn_pd02_dds_publish_led_command"));
            if (resolved.isComplete()) {
                api = resolved;
                return true;
            }

            errors.append(QStringLiteral("%1: required DDS symbols are missing").arg(candidate));
            library.unload();
        }

        *failure = QStringLiteral("Unable to load DDS core: %1").arg(errors.join(QStringLiteral("; ")));
        return false;
    }

    void attemptOpen() {
        if (!enabled)
            return;
        setState(QStringLiteral("loading"));

        QString failure;
        if (!injected && !loadDynamicApi(&failure)) {
            enterRetry(failure);
            return;
        }
        if (!api.isComplete()) {
            enterRetry(QStringLiteral("DDS core API is incomplete"));
            return;
        }

        const QByteArray participantUtf8 = participant.toUtf8();
        const QByteArray peersUtf8 = initialPeers.toUtf8();
        const QByteArray hitTopicUtf8 = hitEventTopic.toUtf8();
        const QByteArray ledTopicUtf8 = ledCommandTopic.toUtf8();
        qxzn_pd02_dds_config raw{};
        raw.domain_id = uint32_t(std::max(0, domainId));
        raw.enable_multicast = multicast ? 1 : 0;
        raw.participant_name = participantUtf8.constData();
        raw.initial_peers = peersUtf8.constData();
        raw.hit_event_topic = hitTopicUtf8.constData();
        raw.led_command_topic = ledTopicUtf8.constData();

        char error[QXZN_PD02_DDS_ERROR_LEN] = {};
        context = api.create(&raw, error, QXZN_PD02_DDS_ERROR_LEN);
        if (!context) {
            enterRetry(QStringLiteral("DDS context creation failed: %1")
                           .arg(errorString(error, sizeof(error))));
            return;
        }

        retryDelayMs = 2000;
        consecutivePublishFailures = 0;
        setLastError(QString());
        setReady(true);
        setState(QStringLiteral("ready"));
        pollTimer.start();
    }

    void closeTransport() {
        pollTimer.stop();
        receivingTimer.stop();
        if (context && api.destroy)
            api.destroy(context);
        context = nullptr;
        setReady(false);
        if (!injected) {
            api = {};
            if (library.isLoaded())
                library.unload();
        }
    }

    void enterRetry(const QString &message) {
        closeTransport();
        setLastError(message);
        setState(QStringLiteral("error"));
        retryTimer.start(retryDelayMs);
        retryDelayMs = std::min(retryDelayMs * 2, 10000);
    }

    void rebuildImmediately(const QString &message) {
        closeTransport();
        setLastError(message);
        setState(QStringLiteral("error"));
        retryTimer.start(0);
    }

    void pollHits() {
        if (!context || !api.takeHitEvent)
            return;
        for (int count = 0; count < 64; ++count) {
            qxzn_pd02_hit_event hit{};
            char error[QXZN_PD02_DDS_ERROR_LEN] = {};
            const int result = api.takeHitEvent(
                context, &hit, 0, error, QXZN_PD02_DDS_ERROR_LEN);
            if (result == 0)
                return;
            if (result < 0) {
                enterRetry(QStringLiteral("DDS hit receive failed: %1")
                               .arg(errorString(error, sizeof(error))));
                return;
            }
            handleHit(hit);
        }
    }

    void handleHit(const qxzn_pd02_hit_event &hit) {
        const QString segment = fixedString(hit.segment);
        if (!SegmentInput::isStandardSegment(segment)) {
            if (!invalidHitWarning.isValid() || invalidHitWarning.elapsed() >= 5000) {
                qWarning() << "Ignoring invalid DDS hit segment" << segment;
                invalidHitWarning.restart();
            }
            return;
        }

        const qint64 receivedAtMs = QDateTime::currentMSecsSinceEpoch();
        setLastHit(segment, receivedAtMs);
        setState(QStringLiteral("receiving"));
        receivingTimer.start();
        emit q->hitReceived(segment, fixedString(hit.level), hit.confidence,
                            fixedString(hit.sensor), int(hit.can_id),
                            int(hit.sensor_index), hit.hit_detected_at_ms);
    }

    bool publishSet(const QStringList &segments, const QColor &color, int durationMs,
                    const QString &sessionId, const QString &beatId,
                    const QString &reason) {
        if (!enabled)
            return false;
        if (!ready || !context) {
            setLastError(QStringLiteral("DDS is not ready"));
            return false;
        }
        if (!color.isValid() || segments.isEmpty()) {
            setLastError(QStringLiteral("LED command requires a color and at least one segment"));
            return false;
        }
        for (const QString &segment : segments) {
            if (!SegmentInput::isStandardSegment(segment)) {
                setLastError(QStringLiteral("Invalid LED segment: %1").arg(segment));
                return false;
            }
        }

        const QString effectiveSession = sessionId.isEmpty() ? processSessionId : sessionId;
        for (const QString &segment : segments) {
            if (!publishOne(QXZN_PD02_LED_COMMAND_SET, segment, color,
                            std::clamp(durationMs, 0, 5000), effectiveSession,
                            beatId, reason))
                return false;
        }
        return true;
    }

    bool publishAllOff(const QString &sessionId, const QString &reason) {
        if (!enabled)
            return false;
        if (!ready || !context) {
            setLastError(QStringLiteral("DDS is not ready"));
            return false;
        }
        const QString effectiveSession = sessionId.isEmpty() ? processSessionId : sessionId;
        return publishOne(QXZN_PD02_LED_COMMAND_ALL_OFF, QString(), QColor(0, 0, 0),
                          0, effectiveSession, QString(), reason);
    }

    bool publishOne(uint8_t commandType, const QString &segment, const QColor &color,
                    int durationMs, const QString &sessionId, const QString &beatId,
                    const QString &reason) {
        qxzn_pd02_led_command command{};
        command.sequence_id = nextSequence++;
        command.timestamp_us = uint64_t(QDateTime::currentMSecsSinceEpoch()) * 1000;
        writeFixed(command.source, QStringLiteral("pd02-qt-hmi"));
        writeFixed(command.session_id, sessionId);
        writeFixed(command.beat_id, beatId);
        writeFixed(command.segment, segment);
        command.command_type = commandType;
        command.r = uint8_t(color.red());
        command.g = uint8_t(color.green());
        command.b = uint8_t(color.blue());
        command.mode = commandType == QXZN_PD02_LED_COMMAND_SET ? 1 : 0;
        command.param = 0;
        command.duration_ms = durationMs;
        writeFixed(command.reason, reason);

        char error[QXZN_PD02_DDS_ERROR_LEN] = {};
        const int result = api.publishLedCommand(
            context, &command, error, QXZN_PD02_DDS_ERROR_LEN);
        if (result == 0) {
            consecutivePublishFailures = 0;
            setLastError(QString());
            return true;
        }

        ++consecutivePublishFailures;
        const QString message = QStringLiteral("DDS LED publish failed: %1")
            .arg(errorString(error, sizeof(error)));
        setLastError(message);
        if (consecutivePublishFailures >= 3)
            rebuildImmediately(message);
        return false;
    }
#endif

    DdsBridge *q;
    bool enabled = false;
    QString state = QStringLiteral("disabled");
    bool ready = false;
    QString lastError;
    QString lastHitSegment;
    qint64 lastHitAtMs = 0;

#if QXZN_HMI_DDS
    DdsApi api;
    bool injected = false;
    QLibrary library;
    qxzn_pd02_dds_context *context = nullptr;
    QTimer pollTimer;
    QTimer retryTimer;
    QTimer receivingTimer;
    QElapsedTimer invalidHitWarning;
    QString coreLib;
    int domainId = 37;
    bool multicast = false;
    QString initialPeers = QStringLiteral("127.0.0.1");
    QString participant = QStringLiteral("pd02-qt-hmi");
    QString hitEventTopic = QStringLiteral("pd02/hit/event");
    QString ledCommandTopic = QStringLiteral("pd02/led/command");
    QString processSessionId;
    int retryDelayMs = 2000;
    int consecutivePublishFailures = 0;
    uint64_t nextSequence = 1;
#endif
};

DdsBridge::DdsBridge(QObject *parent)
    : QObject(parent), m_impl(std::make_unique<Impl>(this)) {}

#if QXZN_HMI_DDS
DdsBridge::DdsBridge(const DdsApi &api, QObject *parent)
    : QObject(parent), m_impl(std::make_unique<Impl>(this, api)) {}
#endif

DdsBridge::~DdsBridge() {
    m_impl->shutdown();
}

void DdsBridge::start(const Config &config) { m_impl->start(config); }
void DdsBridge::stop() { m_impl->shutdown(); }

bool DdsBridge::enabled() const { return m_impl->enabled; }
QString DdsBridge::state() const { return m_impl->state; }
bool DdsBridge::ready() const { return m_impl->ready; }
QString DdsBridge::lastError() const { return m_impl->lastError; }
QString DdsBridge::lastHitSegment() const { return m_impl->lastHitSegment; }
qint64 DdsBridge::lastHitAtMs() const { return m_impl->lastHitAtMs; }

bool DdsBridge::flashSegments(const QStringList &segments, const QColor &color, int durationMs) {
#if QXZN_HMI_DDS
    return m_impl->publishSet(segments, color, durationMs, QString(), QString(),
                              QStringLiteral("qt_hmi"));
#else
    Q_UNUSED(segments);
    Q_UNUSED(color);
    Q_UNUSED(durationMs);
    return false;
#endif
}

bool DdsBridge::sendLedCommand(const QStringList &segments, const QColor &color, int durationMs,
                               const QString &sessionId, const QString &beatId,
                               const QString &reason) {
#if QXZN_HMI_DDS
    return m_impl->publishSet(segments, color, durationMs, sessionId, beatId, reason);
#else
    Q_UNUSED(segments);
    Q_UNUSED(color);
    Q_UNUSED(durationMs);
    Q_UNUSED(sessionId);
    Q_UNUSED(beatId);
    Q_UNUSED(reason);
    return false;
#endif
}

bool DdsBridge::turnOffAllLeds(const QString &sessionId, const QString &reason) {
#if QXZN_HMI_DDS
    return m_impl->publishAllOff(sessionId, reason);
#else
    Q_UNUSED(sessionId);
    Q_UNUSED(reason);
    return false;
#endif
}
