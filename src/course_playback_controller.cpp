#include "course_playback_controller.h"

#include "config.h"
#include "gst_decoder_policy.h"
#include "gst_playback_worker.h"
#include "media_path_resolver.h"

#include <QDebug>
#include <QDir>
#include <QCoreApplication>
#include <QMetaObject>
#include <algorithm>

CoursePlaybackController::CoursePlaybackController(QObject *parent)
    : QObject(parent) {
    m_worker = new GstPlaybackWorker;
    m_worker->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);

    connect(m_worker, &GstPlaybackWorker::stateChanged, this,
            [this](quint64 generation, const QString &state) {
        if (currentGeneration(generation))
            setState(state);
    });
    connect(m_worker, &GstPlaybackWorker::positionChanged, this,
            [this](quint64 generation, qint64 position, qint64 duration) {
        if (!currentGeneration(generation))
            return;
        m_positionMs = position;
        m_durationMs = duration;
        updateMarkerState();
        emit playbackChanged();
    });
    connect(m_worker, &GstPlaybackWorker::frameReady, this,
            [this](quint64 generation, const QImage &frame, const QSize &sourceSize,
                   double decodedFps) {
        if (!currentGeneration(generation))
            return;
        m_sourceSize = sourceSize;
        m_deliveredSize = frame.size();
        m_decodedFps = decodedFps;
        emit diagnosticsChanged();
        emit frameReady(frame);
    });
    connect(m_worker, &GstPlaybackWorker::decoderChanged, this,
            [this](quint64 generation, const QString &mode, const QString &name) {
        if (!currentGeneration(generation))
            return;
        m_decoderMode = mode;
        m_decoderName = name;
        emit diagnosticsChanged();
    });
    connect(m_worker, &GstPlaybackWorker::playbackError, this,
            [this](quint64 generation, const QString &diagnostic) {
        if (currentGeneration(generation))
            setError(QStringLiteral("课程视频播放失败，请重试"), diagnostic);
    });

    m_workerThread.setObjectName(QStringLiteral("course-gstreamer-worker"));
    m_workerThread.start();
    QMetaObject::invokeMethod(m_worker, &GstPlaybackWorker::initialize,
                              Qt::BlockingQueuedConnection);
    m_presentedTimer.start();
}

CoursePlaybackController::~CoursePlaybackController() {
    if (m_workerThread.isRunning()) {
        QMetaObject::invokeMethod(m_worker, &GstPlaybackWorker::shutdown,
                                  Qt::BlockingQueuedConnection);
        m_workerThread.quit();
        m_workerThread.wait();
    }
    m_worker = nullptr;
}

void CoursePlaybackController::configure(const Config &config) {
    m_mediaRoot = config.mediaRoot();
    // Dev convenience: when no media root is configured, fall back to the
    // sibling media/ directory next to the executable (qxzn-hmi-qt/media, with
    // course/ and sbkcourse/) so launching from the IDE works without setting
    // QXZN_MEDIA_DIR. Absent in production -> resolver reports a clear error.
    if (m_mediaRoot.isEmpty()) {
        const QString candidate = QCoreApplication::applicationDirPath() +
                                  QStringLiteral("/../media");
        if (QDir(candidate).exists())
            m_mediaRoot = QDir(candidate).absolutePath();
    }
    m_decoderMode = GstDecoderPolicy::modeFromEnvironment();
    emit diagnosticsChanged();
}

bool CoursePlaybackController::openCourse(const QString &id) {
    const QVariantMap definition = m_catalog.course(id);
    if (definition.isEmpty()) {
        setError(QStringLiteral("该课程暂不支持视频教学"),
                 QStringLiteral("unknown video course id: %1").arg(id));
        return false;
    }

    const QString mediaKey = definition.value(QStringLiteral("mediaKey")).toString();
    const QString title = definition.value(QStringLiteral("title")).toString();
    const QVariantList markers = definition.value(QStringLiteral("markers")).toList();
    const qint64 durationHintMs = definition.value(QStringLiteral("durationHintMs")).toLongLong();
    const MediaPathResult media = MediaPathResolver::resolve(m_mediaRoot, mediaKey);
    if (!media.isValid()) {
        m_courseId = id;
        m_title = title;
        m_markers = markers;
        m_positionMs = 0;
        m_durationMs = durationHintMs;
        updateMarkerState();
        setError(QStringLiteral("课程媒体文件不可用，请配置 QXZN_MEDIA_DIR"),
                 media.diagnostic);
        return false;
    }
    beginPlayback(media.path, id, title, markers, durationHintMs);
    return true;
}

bool CoursePlaybackController::openMedia(const QString &mediaKey, const QString &title) {
    const MediaPathResult media = MediaPathResolver::resolve(m_mediaRoot, mediaKey);
    if (!media.isValid()) {
        m_courseId = mediaKey;
        m_title = title;
        m_markers.clear();
        m_positionMs = 0;
        m_durationMs = 0;
        updateMarkerState();
        setError(QStringLiteral("课程媒体文件不可用，请配置 QXZN_MEDIA_DIR"),
                 media.diagnostic);
        return false;
    }
    beginPlayback(media.path, mediaKey, title, {}, 0);
    return true;
}

void CoursePlaybackController::beginPlayback(const QString &path, const QString &id,
                                             const QString &title,
                                             const QVariantList &markers,
                                             qint64 durationHintMs) {
    ++m_generation;
    m_courseId = id;
    m_title = title;
    m_markers = markers;
    m_positionMs = 0;
    m_durationMs = durationHintMs;
    m_errorMessage.clear();
    m_decoderMode = GstDecoderPolicy::modeFromEnvironment();
    m_decoderName.clear();
    m_sourceSize = {};
    m_deliveredSize = {};
    m_decodedFps = 0.0;
    m_presentedFps = 0.0;
    m_presentedFrames = 0;
    m_presentedTimer.restart();
    updateMarkerState();
    setState(QStringLiteral("loading"));
    emit playbackChanged();
    emit diagnosticsChanged();

    const quint64 generation = m_generation;
    const QString decoderMode = m_decoderMode;
    QString audioSink = QString::fromUtf8(qgetenv("QXZN_MEDIA_AUDIO_SINK")).trimmed();
    if (audioSink.isEmpty())
        audioSink = QStringLiteral("autoaudiosink");
    const double volume = m_volume;
    const bool muted = m_muted;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, path, decoderMode, audioSink,
         generation, volume, muted]() {
            worker->load(path, decoderMode, audioSink, generation, volume, muted);
        }, Qt::QueuedConnection);
}

void CoursePlaybackController::togglePlayback() {
    if (m_state == QStringLiteral("playing") || m_state == QStringLiteral("buffering"))
        pause();
    else if (m_state == QStringLiteral("ended"))
        replay();
    else
        play();
}

void CoursePlaybackController::play() {
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation]() { worker->play(generation); },
        Qt::QueuedConnection);
}

void CoursePlaybackController::pause() {
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation]() { worker->pause(generation); },
        Qt::QueuedConnection);
}

void CoursePlaybackController::stop() {
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation]() { worker->stop(generation); },
        Qt::QueuedConnection);
}

void CoursePlaybackController::replay() {
    seekMs(0);
    play();
}

void CoursePlaybackController::seekMs(qint64 positionMs) {
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation, positionMs]() {
            worker->seekMs(positionMs, generation);
        }, Qt::QueuedConnection);
}

void CoursePlaybackController::seekPreviousMarker() {
    const qint64 target = previousMarkerTarget();
    if (target >= 0)
        seekMs(target);
}

void CoursePlaybackController::seekNextMarker() {
    const qint64 target = nextMarkerTarget();
    if (target >= 0)
        seekMs(target);
}

void CoursePlaybackController::setVolume(double volume) {
    const double clamped = std::clamp(volume, 0.0, 1.0);
    if (qFuzzyCompare(m_volume, clamped))
        return;
    m_volume = clamped;
    emit volumeChanged();
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation, clamped]() {
            worker->setVolume(clamped, generation);
        }, Qt::QueuedConnection);
}

void CoursePlaybackController::setMuted(bool muted) {
    if (m_muted == muted)
        return;
    m_muted = muted;
    emit mutedChanged();
    const quint64 generation = m_generation;
    QMetaObject::invokeMethod(m_worker,
        [worker = m_worker, generation, muted]() {
            worker->setMuted(muted, generation);
        }, Qt::QueuedConnection);
}

void CoursePlaybackController::noteFramePresented() {
    ++m_presentedFrames;
    const qint64 elapsed = m_presentedTimer.elapsed();
    if (elapsed < 1000)
        return;
    m_presentedFps = m_presentedFrames * 1000.0 / std::max<qint64>(1, elapsed);
    m_presentedFrames = 0;
    m_presentedTimer.restart();
    emit diagnosticsChanged();
    if (qEnvironmentVariableIsSet("QXZN_HMI_VIDEO_DEBUG"))
        qWarning("video: decoded=%.1f fps presented=%.1f fps decoder=%s",
                 m_decodedFps, m_presentedFps, qPrintable(m_decoderName));
}

void CoursePlaybackController::setState(const QString &state) {
    if (m_state == state)
        return;
    m_state = state;
    emit playbackChanged();
}

void CoursePlaybackController::setError(const QString &userMessage,
                                        const QString &diagnostic) {
    qWarning() << "Course player:" << diagnostic;
    m_errorMessage = userMessage;
    setState(QStringLiteral("error"));
    emit playbackChanged();
}

void CoursePlaybackController::updateMarkerState() {
    QString label;
    for (const QVariant &value : m_markers) {
        const QVariantMap marker = value.toMap();
        if (marker.value(QStringLiteral("timeMs")).toLongLong() <= m_positionMs)
            label = marker.value(QStringLiteral("label")).toString();
        else
            break;
    }
    const bool previous = previousMarkerTarget() >= 0;
    const bool next = nextMarkerTarget() >= 0;
    if (label == m_currentMarkerLabel && previous == m_hasPreviousMarker &&
        next == m_hasNextMarker)
        return;
    m_currentMarkerLabel = label;
    m_hasPreviousMarker = previous;
    m_hasNextMarker = next;
    emit markerChanged();
}

qint64 CoursePlaybackController::previousMarkerTarget() const {
    const qint64 threshold = m_positionMs - 350;
    for (auto it = m_markers.crbegin(); it != m_markers.crend(); ++it) {
        const qint64 markerTime = it->toMap().value(QStringLiteral("timeMs")).toLongLong();
        if (markerTime < threshold)
            return markerTime;
    }
    return m_positionMs > 350 ? 0 : -1;
}

qint64 CoursePlaybackController::nextMarkerTarget() const {
    const qint64 threshold = m_positionMs + 350;
    for (const QVariant &value : m_markers) {
        const qint64 markerTime = value.toMap().value(QStringLiteral("timeMs")).toLongLong();
        if (markerTime > threshold)
            return markerTime;
    }
    return -1;
}

bool CoursePlaybackController::currentGeneration(quint64 generation) const {
    return generation == m_generation;
}
