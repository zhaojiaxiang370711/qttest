#pragma once

#include <QElapsedTimer>
#include <QImage>
#include <QMutex>
#include <QObject>
#include <QSize>
#include <QString>
#include <atomic>

#include <gst/app/gstappsink.h>

class QTimer;

class GstPlaybackWorker : public QObject {
    Q_OBJECT
public:
    explicit GstPlaybackWorker(QObject *parent = nullptr);
    ~GstPlaybackWorker() override;

public slots:
    void initialize();
    void load(const QString &path, const QString &decoderMode, const QString &audioSink,
              quint64 generation, double volume, bool muted);
    void play(quint64 generation);
    void pause(quint64 generation);
    void stop(quint64 generation);
    void seekMs(qint64 positionMs, quint64 generation);
    void setVolume(double volume, quint64 generation);
    void setMuted(bool muted, quint64 generation);
    void shutdown();

signals:
    void stateChanged(quint64 generation, const QString &state);
    void positionChanged(quint64 generation, qint64 positionMs, qint64 durationMs);
    void frameReady(quint64 generation, const QImage &frame, const QSize &sourceSize,
                    double decodedFps);
    void decoderChanged(quint64 generation, const QString &mode,
                        const QString &decoderName);
    void playbackError(quint64 generation, const QString &diagnostic);

private:
    static GstFlowReturn onNewSample(GstAppSink *sink, gpointer userData);
    GstFlowReturn pullSample(GstAppSink *sink);
    GstElement *createVideoSink(QString *error);
    void drainBus();
    void updatePosition();
    void handleMessage(GstMessage *message);
    void deliverLatestFrame();
    void teardownPipeline();
    bool generationMatches(quint64 generation) const;

    GstElement *m_pipeline = nullptr;
    GstBus *m_bus = nullptr;
    GstAppSink *m_appSink = nullptr;
    QTimer *m_busTimer = nullptr;
    QTimer *m_positionTimer = nullptr;
    std::atomic<quint64> m_generation{0};
    bool m_wantsPlayback = false;
    QString m_decoderMode;
    qint64 m_durationMs = 0;

    QMutex m_frameMutex;
    QImage m_latestFrame;
    QSize m_latestSourceSize;
    quint64 m_latestFrameGeneration = 0;
    bool m_deliveryQueued = false;
    QElapsedTimer m_fpsTimer;
    int m_fpsFrames = 0;
    double m_decodedFps = 0.0;
    // Manual pull pacing (appsink sync= was mis-paced to ~1fps). Last pull time
    // in microseconds (monotonic) so we throttle consumption to the media fps.
    qint64 m_lastPullUsec = 0;
};
