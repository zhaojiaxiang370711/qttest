#pragma once

#include "course_catalog.h"

#include <QElapsedTimer>
#include <QImage>
#include <QObject>
#include <QSize>
#include <QThread>
#include <QVariantList>

class Config;
class GstPlaybackWorker;

class CoursePlaybackController : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY playbackChanged)
    Q_PROPERTY(QString courseId READ courseId NOTIFY playbackChanged)
    Q_PROPERTY(QString title READ title NOTIFY playbackChanged)
    Q_PROPERTY(qint64 positionMs READ positionMs NOTIFY playbackChanged)
    Q_PROPERTY(qint64 durationMs READ durationMs NOTIFY playbackChanged)
    Q_PROPERTY(double volume READ volume NOTIFY volumeChanged)
    Q_PROPERTY(bool muted READ muted NOTIFY mutedChanged)
    Q_PROPERTY(QString currentMarkerLabel READ currentMarkerLabel NOTIFY markerChanged)
    Q_PROPERTY(bool hasPreviousMarker READ hasPreviousMarker NOTIFY markerChanged)
    Q_PROPERTY(bool hasNextMarker READ hasNextMarker NOTIFY markerChanged)
    Q_PROPERTY(QString decoderMode READ decoderMode NOTIFY diagnosticsChanged)
    Q_PROPERTY(QString decoderName READ decoderName NOTIFY diagnosticsChanged)
    Q_PROPERTY(QString rendererMode READ rendererMode CONSTANT)
    Q_PROPERTY(QSize sourceSize READ sourceSize NOTIFY diagnosticsChanged)
    Q_PROPERTY(QSize deliveredSize READ deliveredSize NOTIFY diagnosticsChanged)
    Q_PROPERTY(double decodedFps READ decodedFps NOTIFY diagnosticsChanged)
    Q_PROPERTY(double presentedFps READ presentedFps NOTIFY diagnosticsChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY playbackChanged)
public:
    explicit CoursePlaybackController(QObject *parent = nullptr);
    ~CoursePlaybackController() override;

    void configure(const Config &config);

    QString state() const { return m_state; }
    QString courseId() const { return m_courseId; }
    QString title() const { return m_title; }
    qint64 positionMs() const { return m_positionMs; }
    qint64 durationMs() const { return m_durationMs; }
    double volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    QString currentMarkerLabel() const { return m_currentMarkerLabel; }
    bool hasPreviousMarker() const { return m_hasPreviousMarker; }
    bool hasNextMarker() const { return m_hasNextMarker; }
    QString decoderMode() const { return m_decoderMode; }
    QString decoderName() const { return m_decoderName; }
    QString rendererMode() const { return QStringLiteral("cpu-copy"); }
    QSize sourceSize() const { return m_sourceSize; }
    QSize deliveredSize() const { return m_deliveredSize; }
    double decodedFps() const { return m_decodedFps; }
    double presentedFps() const { return m_presentedFps; }
    QString errorMessage() const { return m_errorMessage; }

    Q_INVOKABLE bool openCourse(const QString &id);
    // Play an arbitrary allow-listed media key (e.g. a focus-mitt unit video),
    // resolved against the configured media root. Used by trainer pages that do
    // not map to a catalog video course.
    Q_INVOKABLE bool openMedia(const QString &mediaKey, const QString &title);
    Q_INVOKABLE void togglePlayback();
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void replay();
    Q_INVOKABLE void seekMs(qint64 positionMs);
    Q_INVOKABLE void seekPreviousMarker();
    Q_INVOKABLE void seekNextMarker();
    Q_INVOKABLE void setVolume(double volume);
    Q_INVOKABLE void setMuted(bool muted);

    void noteFramePresented();

signals:
    void playbackChanged();
    void volumeChanged();
    void mutedChanged();
    void markerChanged();
    void diagnosticsChanged();
    void frameReady(const QImage &frame);

private:
    void setState(const QString &state);
    void setError(const QString &userMessage, const QString &diagnostic);
    void beginPlayback(const QString &path, const QString &id, const QString &title,
                       const QVariantList &markers, qint64 durationHintMs);
    void updateMarkerState();
    qint64 previousMarkerTarget() const;
    qint64 nextMarkerTarget() const;
    bool currentGeneration(quint64 generation) const;

    CourseCatalog m_catalog;
    QString m_mediaRoot;
    QString m_state = QStringLiteral("idle");
    QString m_courseId;
    QString m_title;
    QString m_errorMessage;
    QString m_decoderMode = QStringLiteral("auto");
    QString m_decoderName;
    QVariantList m_markers;
    qint64 m_positionMs = 0;
    qint64 m_durationMs = 0;
    double m_volume = 1.0;
    bool m_muted = false;
    QString m_currentMarkerLabel;
    bool m_hasPreviousMarker = false;
    bool m_hasNextMarker = false;
    QSize m_sourceSize;
    QSize m_deliveredSize;
    double m_decodedFps = 0.0;
    double m_presentedFps = 0.0;
    QElapsedTimer m_presentedTimer;
    int m_presentedFrames = 0;
    quint64 m_generation = 0;

    QThread m_workerThread;
    GstPlaybackWorker *m_worker = nullptr;
};
