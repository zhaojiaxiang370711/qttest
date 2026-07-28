#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QStringList>
#include <memory>

#ifndef QXZN_HMI_DDS
#define QXZN_HMI_DDS 0
#endif

class Config;
#if QXZN_HMI_DDS
struct DdsApi;
#endif

class DdsBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString lastHitSegment READ lastHitSegment NOTIFY lastHitSegmentChanged)
    Q_PROPERTY(qint64 lastHitAtMs READ lastHitAtMs NOTIFY lastHitAtMsChanged)
public:
    explicit DdsBridge(QObject *parent = nullptr);
#if QXZN_HMI_DDS
    explicit DdsBridge(const DdsApi &api, QObject *parent = nullptr);
#endif
    ~DdsBridge() override;

    void start(const Config &config);
    void stop();

    bool enabled() const;
    QString state() const;
    bool ready() const;
    QString lastError() const;
    QString lastHitSegment() const;
    qint64 lastHitAtMs() const;

    Q_INVOKABLE bool flashSegments(const QStringList &segments, const QColor &color, int durationMs);
    Q_INVOKABLE bool sendLedCommand(const QStringList &segments, const QColor &color, int durationMs,
                                    const QString &sessionId, const QString &beatId,
                                    const QString &reason);
    Q_INVOKABLE bool turnOffAllLeds(const QString &sessionId, const QString &reason);

signals:
    void enabledChanged();
    void stateChanged();
    void readyChanged();
    void lastErrorChanged();
    void lastHitSegmentChanged();
    void lastHitAtMsChanged();
    void hitReceived(const QString &segment, const QString &level, double confidence,
                     const QString &sensor, int canId, int sensorIndex, qint64 detectedAtMs);

private:
    class Impl;
    std::unique_ptr<Impl> m_impl;
};
