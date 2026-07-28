#include "gst_playback_worker.h"

#include "gst_decoder_policy.h"

#include <QDebug>
#include <QMetaObject>
#include <QMutexLocker>
#include <QTimer>
#include <QByteArray>
#include <QCoreApplication>
#include <algorithm>
#include <cstring>

#include <gst/video/video.h>

#ifndef QXZN_HMI_GST_FRAME_WIDTH
#define QXZN_HMI_GST_FRAME_WIDTH 1280
#endif
#ifndef QXZN_HMI_GST_FRAME_HEIGHT
#define QXZN_HMI_GST_FRAME_HEIGHT 720
#endif

namespace {
// Delivered frame size is compile-time default (1280x720) but runtime-tunable
// via QXZN_GST_FRAME_WIDTH / QXZN_GST_FRAME_HEIGHT, so the cpu-copy present load
// can be A/B tested without rebuilding (smaller frames = less convert/copy/upload).
int deliveredFrameWidth() {
    bool ok = false;
    const int v = qgetenv("QXZN_GST_FRAME_WIDTH").toInt(&ok);
    return (ok && v >= 320 && v <= 3840) ? v : QXZN_HMI_GST_FRAME_WIDTH;
}
int deliveredFrameHeight() {
    bool ok = false;
    const int v = qgetenv("QXZN_GST_FRAME_HEIGHT").toInt(&ok);
    return (ok && v >= 240 && v <= 2160) ? v : QXZN_HMI_GST_FRAME_HEIGHT;
}
} // namespace

GstPlaybackWorker::GstPlaybackWorker(QObject *parent)
    : QObject(parent) {}

GstPlaybackWorker::~GstPlaybackWorker() {
    teardownPipeline();
}

void GstPlaybackWorker::initialize() {
    if (m_busTimer)
        return;
    m_busTimer = new QTimer(this);
    m_busTimer->setInterval(20);
    connect(m_busTimer, &QTimer::timeout, this, &GstPlaybackWorker::drainBus);
    m_positionTimer = new QTimer(this);
    m_positionTimer->setInterval(100);
    connect(m_positionTimer, &QTimer::timeout, this, &GstPlaybackWorker::updatePosition);
}

void GstPlaybackWorker::load(const QString &path, const QString &decoderMode,
                             const QString &audioSink, quint64 generation,
                             double volume, bool muted) {
    initialize();
    teardownPipeline();
    m_generation.store(generation);
    m_decoderMode = decoderMode;
    m_durationMs = 0;
    m_wantsPlayback = true;
    m_fpsFrames = 0;
    m_decodedFps = 0.0;
    m_lastPullUsec = 0;
    m_fpsTimer.restart();

    const GstDecoderPolicyResult policy = GstDecoderPolicy::configure(decoderMode);
    if (!policy.ok) {
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, policy.error);
        return;
    }

    m_pipeline = gst_element_factory_make("playbin3", "course_player");
    if (!m_pipeline) {
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, QStringLiteral("GStreamer playbin3 is unavailable"));
        return;
    }

    QString sinkError;
    GstElement *videoSink = createVideoSink(&sinkError);
    if (!videoSink) {
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, sinkError);
        teardownPipeline();
        return;
    }

    const QByteArray audioFactory = audioSink.toUtf8();
    GstElement *audio = gst_element_factory_make(audioFactory.constData(), "course_audio_sink");
    if (!audio) {
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, QStringLiteral("GStreamer audio sink unavailable: %1")
                                       .arg(audioSink));
        gst_object_unref(videoSink);
        teardownPipeline();
        return;
    }

    GError *uriError = nullptr;
    const QByteArray pathUtf8 = path.toUtf8();
    gchar *uri = gst_filename_to_uri(pathUtf8.constData(), &uriError);
    if (!uri) {
        const QString diagnostic = uriError
            ? QString::fromUtf8(uriError->message)
            : QStringLiteral("cannot create media URI");
        if (uriError)
            g_error_free(uriError);
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, diagnostic);
        gst_object_unref(videoSink);
        gst_object_unref(audio);
        teardownPipeline();
        return;
    }

    g_object_set(m_pipeline,
                 "uri", uri,
                 "video-sink", videoSink,
                 "audio-sink", audio,
                 "volume", std::clamp(volume, 0.0, 1.0),
                 "mute", muted,
                 nullptr);
    g_free(uri);
    // playbin3 takes its own reference on the sink properties. Convert each
    // freshly-made floating element into a strong reference first, then drop our
    // reference so ownership ends with the pipeline (no leak, no double-free).
    gst_object_ref_sink(videoSink);
    gst_object_ref_sink(audio);
    gst_object_unref(videoSink);
    gst_object_unref(audio);

    m_bus = gst_element_get_bus(m_pipeline);
    m_busTimer->start();
    m_positionTimer->start();
    emit stateChanged(generation, QStringLiteral("loading"));

    const GstStateChangeReturn result = gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
    if (result == GST_STATE_CHANGE_FAILURE) {
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, QStringLiteral("GStreamer failed to start playback"));
        teardownPipeline();
    }
}

void GstPlaybackWorker::play(quint64 generation) {
    if (!generationMatches(generation) || !m_pipeline)
        return;
    m_wantsPlayback = true;
    gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
}

void GstPlaybackWorker::pause(quint64 generation) {
    if (!generationMatches(generation) || !m_pipeline)
        return;
    m_wantsPlayback = false;
    gst_element_set_state(m_pipeline, GST_STATE_PAUSED);
}

void GstPlaybackWorker::stop(quint64 generation) {
    if (!generationMatches(generation))
        return;
    teardownPipeline();
    emit stateChanged(generation, QStringLiteral("idle"));
    emit positionChanged(generation, 0, 0);
}

void GstPlaybackWorker::seekMs(qint64 positionMs, quint64 generation) {
    if (!generationMatches(generation) || !m_pipeline)
        return;
    const qint64 maximum = m_durationMs > 0 ? m_durationMs : positionMs;
    const qint64 clamped = std::clamp(positionMs, qint64(0), maximum);
    m_lastPullUsec = 0;  // first post-seek frame should not inherit the old pacing gap
    gst_element_seek_simple(m_pipeline, GST_FORMAT_TIME,
                            GstSeekFlags(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
                            clamped * GST_MSECOND);
}

void GstPlaybackWorker::setVolume(double volume, quint64 generation) {
    if (!generationMatches(generation) || !m_pipeline)
        return;
    g_object_set(m_pipeline, "volume", std::clamp(volume, 0.0, 1.0), nullptr);
}

void GstPlaybackWorker::setMuted(bool muted, quint64 generation) {
    if (!generationMatches(generation) || !m_pipeline)
        return;
    g_object_set(m_pipeline, "mute", muted, nullptr);
}

void GstPlaybackWorker::shutdown() {
    teardownPipeline();
}

GstFlowReturn GstPlaybackWorker::onNewSample(GstAppSink *sink, gpointer userData) {
    return static_cast<GstPlaybackWorker *>(userData)->pullSample(sink);
}

GstFlowReturn GstPlaybackWorker::pullSample(GstAppSink *sink) {
    GstSample *sample = gst_app_sink_pull_sample(sink);
    if (!sample)
        return GST_FLOW_EOS;

    GstCaps *caps = gst_sample_get_caps(sample);
    GstBuffer *buffer = gst_sample_get_buffer(sample);
    GstVideoInfo info;
    if (!caps || !buffer || !gst_video_info_from_caps(&info, caps)) {
        gst_sample_unref(sample);
        return GST_FLOW_ERROR;
    }

    // Manual pull pacing. appsink sync=true mis-paced this pipeline to ~1fps
    // (it waited ~1s between frames regardless of the clock). With sync=false
    // upstream races (decode is ~64x realtime), so we throttle consumption here
    // to the media's frame rate, keeping playback at 1x and the render loop fed.
    const gint fpsNum = GST_VIDEO_INFO_FPS_N(&info);
    const gint fpsDen = GST_VIDEO_INFO_FPS_D(&info);
    if (fpsNum > 0 && fpsDen > 0) {
        const qint64 intervalUsec = qint64(fpsDen) * 1000000 / fpsNum;
        const qint64 now = qint64(g_get_monotonic_time());
        if (m_lastPullUsec > 0) {
            const qint64 elapsed = now - m_lastPullUsec;
            if (elapsed >= 0 && elapsed < intervalUsec)
                g_usleep(gulong(intervalUsec - elapsed));
        }
        m_lastPullUsec = qint64(g_get_monotonic_time());
    }

    GstMapInfo map;
    if (!gst_buffer_map(buffer, &map, GST_MAP_READ)) {
        gst_sample_unref(sample);
        return GST_FLOW_ERROR;
    }

    const int width = int(GST_VIDEO_INFO_WIDTH(&info));
    const int height = int(GST_VIDEO_INFO_HEIGHT(&info));
    const int stride = GST_VIDEO_INFO_PLANE_STRIDE(&info, 0);
    QImage frame(width, height, QImage::Format_RGBA8888);
    // Fast path: GStreamer's RGBA stride almost always matches QImage's tightly
    // packed bytesPerLine (width*4), so one bulk memcpy beats 720 row copies —
    // a real win under -O0. Fall back to per-row only when strides differ.
    if (frame.bytesPerLine() == stride) {
        std::memcpy(frame.bits(), map.data, std::size_t(stride) * std::size_t(height));
    } else {
        const qsizetype bytesPerRow = std::min(frame.bytesPerLine(), qint64(stride));
        for (int row = 0; row < height; ++row)
            std::memcpy(frame.scanLine(row), map.data + row * stride, std::size_t(bytesPerRow));
    }

    gst_buffer_unmap(buffer, &map);
    gst_sample_unref(sample);

    ++m_fpsFrames;
    if (m_fpsTimer.elapsed() >= 1000) {
        m_decodedFps = m_fpsFrames * 1000.0 / std::max<qint64>(1, m_fpsTimer.elapsed());
        m_fpsFrames = 0;
        m_fpsTimer.restart();
        if (qEnvironmentVariableIsSet("QXZN_HMI_VIDEO_DEBUG"))
            qWarning("video: decoded=%.1f fps (worker thread)", m_decodedFps);
    }

    bool queueDelivery = false;
    {
        QMutexLocker locker(&m_frameMutex);
        m_latestFrame = frame;
        m_latestSourceSize = frame.size();
        m_latestFrameGeneration = m_generation.load();
        if (!m_deliveryQueued) {
            m_deliveryQueued = true;
            queueDelivery = true;
        }
    }
    if (queueDelivery) {
        QMetaObject::invokeMethod(this, [this]() { deliverLatestFrame(); },
                                  Qt::QueuedConnection);
    }
    return GST_FLOW_OK;
}

GstElement *GstPlaybackWorker::createVideoSink(QString *error) {
    GstElement *bin = gst_bin_new("course_video_bin");
    GstElement *queue = gst_element_factory_make("queue", "course_video_queue");
    GstElement *scale = gst_element_factory_make("videoscale", "course_video_scale");
    GstElement *convert = gst_element_factory_make("videoconvert", "course_video_convert");
    GstElement *filter = gst_element_factory_make("capsfilter", "course_video_caps");
    GstElement *sink = gst_element_factory_make("appsink", "course_video_sink");
    if (!bin || !queue || !scale || !convert || !filter || !sink) {
        if (error)
            *error = QStringLiteral("Required GStreamer video elements are unavailable");
        if (bin)
            gst_object_unref(bin);
        return nullptr;
    }

    g_object_set(queue,
                 "leaky", 2,
                 "max-size-buffers", 2u,
                 "max-size-bytes", 0u,
                 "max-size-time", guint64(0),
                 nullptr);
    GstCaps *caps = gst_caps_new_simple(
        "video/x-raw",
        "format", G_TYPE_STRING, "RGBA",
        "width", G_TYPE_INT, deliveredFrameWidth(),
        "height", G_TYPE_INT, deliveredFrameHeight(),
        "pixel-aspect-ratio", GST_TYPE_FRACTION, 1, 1,
        nullptr);
    g_object_set(filter, "caps", caps, nullptr);
    gst_caps_unref(caps);
    g_object_set(sink,
                 // sync=false: appsink sync=true mis-paced this playbin3 pipeline
                 // to ~1fps (it waited ~1s between frames regardless of clock).
                 // Pacing is done manually in pullSample() against the media fps.
                 "sync", FALSE,
                 "max-buffers", guint64(2),
                 "drop", TRUE,
                 "enable-last-sample", FALSE,
                 nullptr);

    GstAppSinkCallbacks callbacks{};
    callbacks.new_sample = &GstPlaybackWorker::onNewSample;
    gst_app_sink_set_callbacks(GST_APP_SINK(sink), &callbacks, this, nullptr);

    gst_bin_add_many(GST_BIN(bin), queue, scale, convert, filter, sink, nullptr);
    if (!gst_element_link_many(queue, scale, convert, filter, sink, nullptr)) {
        if (error)
            *error = QStringLiteral("Failed to link GStreamer video sink pipeline");
        gst_object_unref(bin);
        return nullptr;
    }

    GstPad *queueSink = gst_element_get_static_pad(queue, "sink");
    GstPad *ghost = gst_ghost_pad_new("sink", queueSink);
    gst_object_unref(queueSink);
    if (!ghost || !gst_element_add_pad(bin, ghost)) {
        if (ghost)
            gst_object_unref(ghost);
        if (error)
            *error = QStringLiteral("Failed to create GStreamer video ghost pad");
        gst_object_unref(bin);
        return nullptr;
    }

    m_appSink = GST_APP_SINK(sink);
    return bin;
}

void GstPlaybackWorker::drainBus() {
    if (!m_bus)
        return;
    while (GstMessage *message = gst_bus_pop(m_bus)) {
        handleMessage(message);
        gst_message_unref(message);
    }
}

void GstPlaybackWorker::updatePosition() {
    if (!m_pipeline)
        return;
    gint64 position = 0;
    gint64 duration = 0;
    if (gst_element_query_duration(m_pipeline, GST_FORMAT_TIME, &duration))
        m_durationMs = duration / GST_MSECOND;
    if (gst_element_query_position(m_pipeline, GST_FORMAT_TIME, &position))
        emit positionChanged(m_generation.load(), position / GST_MSECOND, m_durationMs);
}

void GstPlaybackWorker::handleMessage(GstMessage *message) {
    const quint64 generation = m_generation.load();
    switch (GST_MESSAGE_TYPE(message)) {
    case GST_MESSAGE_ERROR: {
        GError *gstError = nullptr;
        gchar *debug = nullptr;
        gst_message_parse_error(message, &gstError, &debug);
        const QString diagnostic = gstError
            ? QString::fromUtf8(gstError->message)
            : QStringLiteral("Unknown GStreamer playback error");
        if (debug)
            qWarning() << "GStreamer course error:" << diagnostic << debug;
        if (gstError)
            g_error_free(gstError);
        g_free(debug);
        emit stateChanged(generation, QStringLiteral("error"));
        emit playbackError(generation, diagnostic);
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
        break;
    }
    case GST_MESSAGE_WARNING: {
        GError *gstError = nullptr;
        gchar *debug = nullptr;
        gst_message_parse_warning(message, &gstError, &debug);
        qWarning() << "GStreamer course warning:"
                   << (gstError ? gstError->message : "unknown")
                   << (debug ? debug : "");
        if (gstError)
            g_error_free(gstError);
        g_free(debug);
        break;
    }
    case GST_MESSAGE_EOS:
        m_wantsPlayback = false;
        emit positionChanged(generation, m_durationMs, m_durationMs);
        emit stateChanged(generation, QStringLiteral("ended"));
        break;
    case GST_MESSAGE_STATE_CHANGED:
        if (GST_MESSAGE_SRC(message) == GST_OBJECT(m_pipeline)) {
            GstState oldState;
            GstState newState;
            GstState pending;
            gst_message_parse_state_changed(message, &oldState, &newState, &pending);
            Q_UNUSED(oldState);
            Q_UNUSED(pending);
            if (newState == GST_STATE_PLAYING)
                emit stateChanged(generation, QStringLiteral("playing"));
            else if (newState == GST_STATE_PAUSED && !m_wantsPlayback)
                emit stateChanged(generation, QStringLiteral("paused"));
        }
        break;
    case GST_MESSAGE_ASYNC_DONE: {
        const QString decoder = GstDecoderPolicy::activeDecoder(m_pipeline);
        const bool softwareMismatch = m_decoderMode == QStringLiteral("software") &&
                                      decoder != QStringLiteral("avdec_h264");
        const bool mppMismatch = m_decoderMode == QStringLiteral("mpp") &&
                                 decoder != QStringLiteral("mpph264dec") &&
                                 decoder != QStringLiteral("mppvideodec");
        if (decoder.isEmpty() || softwareMismatch || mppMismatch) {
            const QString diagnostic = QStringLiteral("Unexpected active H.264 decoder: %1")
                .arg(decoder.isEmpty() ? QStringLiteral("unknown") : decoder);
            emit stateChanged(generation, QStringLiteral("error"));
            emit playbackError(generation, diagnostic);
            gst_element_set_state(m_pipeline, GST_STATE_NULL);
        } else {
            emit decoderChanged(generation, m_decoderMode, decoder);
            updatePosition();
        }
        break;
    }
    case GST_MESSAGE_BUFFERING: {
        gint percent = 100;
        gst_message_parse_buffering(message, &percent);
        if (percent < 100 && m_wantsPlayback) {
            gst_element_set_state(m_pipeline, GST_STATE_PAUSED);
            emit stateChanged(generation, QStringLiteral("buffering"));
        } else if (m_wantsPlayback) {
            gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
        }
        break;
    }
    case GST_MESSAGE_CLOCK_LOST:
        if (m_wantsPlayback) {
            gst_element_set_state(m_pipeline, GST_STATE_PAUSED);
            gst_element_set_state(m_pipeline, GST_STATE_PLAYING);
        }
        break;
    case GST_MESSAGE_LATENCY:
        gst_bin_recalculate_latency(GST_BIN(m_pipeline));
        break;
    default:
        break;
    }
}

void GstPlaybackWorker::deliverLatestFrame() {
    QImage frame;
    QSize sourceSize;
    quint64 generation = 0;
    double fps = 0.0;
    {
        QMutexLocker locker(&m_frameMutex);
        frame = m_latestFrame;
        sourceSize = m_latestSourceSize;
        generation = m_latestFrameGeneration;
        fps = m_decodedFps;
        m_deliveryQueued = false;
    }
    if (!frame.isNull())
        emit frameReady(generation, frame, sourceSize, fps);
}

void GstPlaybackWorker::teardownPipeline() {
    if (m_busTimer)
        m_busTimer->stop();
    if (m_positionTimer)
        m_positionTimer->stop();
    if (m_pipeline)
        gst_element_set_state(m_pipeline, GST_STATE_NULL);
    if (m_bus) {
        gst_object_unref(m_bus);
        m_bus = nullptr;
    }
    if (m_pipeline) {
        gst_object_unref(m_pipeline);
        m_pipeline = nullptr;
    }
    m_appSink = nullptr;
    m_wantsPlayback = false;
    m_durationMs = 0;
    QMutexLocker locker(&m_frameMutex);
    m_latestFrame = {};
    m_latestSourceSize = {};
    m_deliveryQueued = false;
}

bool GstPlaybackWorker::generationMatches(quint64 generation) const {
    return generation == m_generation.load();
}
