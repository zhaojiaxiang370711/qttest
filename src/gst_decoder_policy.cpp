#include "gst_decoder_policy.h"

#include <gst/gst.h>
#include <mutex>

namespace {

std::once_flag g_initFlag;
bool g_initialized = false;
QString g_initError;

bool setFactoryRank(const char *name, guint rank) {
    GstElementFactory *factory = gst_element_factory_find(name);
    if (!factory)
        return false;
    gst_plugin_feature_set_rank(GST_PLUGIN_FEATURE(factory), rank);
    gst_object_unref(factory);
    return true;
}

QString factoryName(GstElement *element) {
    GstElementFactory *factory = gst_element_get_factory(element);
    if (!factory)
        return {};
    return QString::fromUtf8(gst_plugin_feature_get_name(GST_PLUGIN_FEATURE(factory)));
}

bool isVideoDecoder(GstElement *element) {
    GstElementFactory *factory = gst_element_get_factory(element);
    if (!factory)
        return false;
    const char *klass = gst_element_factory_get_metadata(factory, GST_ELEMENT_METADATA_KLASS);
    return klass && QString::fromUtf8(klass).contains(QStringLiteral("Decoder/Video"));
}

} // namespace

bool GstDecoderPolicy::ensureInitialized(QString *error) {
    std::call_once(g_initFlag, []() {
        GError *gstError = nullptr;
        g_initialized = gst_init_check(nullptr, nullptr, &gstError);
        if (!g_initialized) {
            g_initError = gstError
                ? QString::fromUtf8(gstError->message)
                : QStringLiteral("GStreamer initialization failed");
        }
        if (gstError)
            g_error_free(gstError);
    });
    if (!g_initialized && error)
        *error = g_initError;
    return g_initialized;
}

GstDecoderPolicyResult GstDecoderPolicy::configure(const QString &requestedMode) {
    GstDecoderPolicyResult result;
    result.mode = requestedMode.trimmed().toLower();
    if (result.mode.isEmpty())
        result.mode = QStringLiteral("auto");
    if (!ensureInitialized(&result.error))
        return result;
    if (result.mode != QStringLiteral("auto") &&
        result.mode != QStringLiteral("software") &&
        result.mode != QStringLiteral("mpp")) {
        result.error = QStringLiteral("Unsupported QXZN_GST_DECODER mode: %1")
            .arg(result.mode);
        return result;
    }

    const bool hasMppH264 = factoryAvailable(QStringLiteral("mpph264dec"));
    const bool hasMppVideo = factoryAvailable(QStringLiteral("mppvideodec"));
    const bool hasSoftware = factoryAvailable(QStringLiteral("avdec_h264"));

    setFactoryRank("mpph264dec", GST_RANK_NONE);
    setFactoryRank("mppvideodec", GST_RANK_NONE);
    setFactoryRank("avdec_h264", GST_RANK_NONE);

    if (result.mode == QStringLiteral("software")) {
        if (!hasSoftware) {
            result.error = QStringLiteral("Required GStreamer decoder avdec_h264 is unavailable");
            return result;
        }
        setFactoryRank("avdec_h264", GST_RANK_PRIMARY + 512);
        result.preferredDecoder = QStringLiteral("avdec_h264");
    } else if (result.mode == QStringLiteral("mpp")) {
        if (!hasMppH264 && !hasMppVideo) {
            result.error = QStringLiteral(
                "MPP decoder requested but mpph264dec/mppvideodec is unavailable");
            return result;
        }
        if (hasMppH264) {
            setFactoryRank("mpph264dec", GST_RANK_PRIMARY + 512);
            result.preferredDecoder = QStringLiteral("mpph264dec");
        } else {
            setFactoryRank("mppvideodec", GST_RANK_PRIMARY + 512);
            result.preferredDecoder = QStringLiteral("mppvideodec");
        }
    } else {
        if (hasSoftware)
            setFactoryRank("avdec_h264", GST_RANK_PRIMARY + 128);
        if (hasMppVideo)
            setFactoryRank("mppvideodec", GST_RANK_PRIMARY + 384);
        if (hasMppH264)
            setFactoryRank("mpph264dec", GST_RANK_PRIMARY + 512);

        if (hasMppH264)
            result.preferredDecoder = QStringLiteral("mpph264dec");
        else if (hasMppVideo)
            result.preferredDecoder = QStringLiteral("mppvideodec");
        else if (hasSoftware)
            result.preferredDecoder = QStringLiteral("avdec_h264");
        else {
            result.error = QStringLiteral("No supported H.264 GStreamer decoder is available");
            return result;
        }
    }

    result.ok = true;
    return result;
}

QString GstDecoderPolicy::modeFromEnvironment() {
    const QString mode = QString::fromUtf8(qgetenv("QXZN_GST_DECODER")).trimmed().toLower();
    return mode.isEmpty() ? QStringLiteral("auto") : mode;
}

bool GstDecoderPolicy::factoryAvailable(const QString &factoryName) {
    QString error;
    if (!ensureInitialized(&error))
        return false;
    const QByteArray utf8 = factoryName.toUtf8();
    GstElementFactory *factory = gst_element_factory_find(utf8.constData());
    if (!factory)
        return false;
    gst_object_unref(factory);
    return true;
}

QString GstDecoderPolicy::activeDecoder(GstElement *pipeline) {
    if (!pipeline || !GST_IS_BIN(pipeline))
        return {};

    QString fallback;
    GstIterator *iterator = gst_bin_iterate_recurse(GST_BIN(pipeline));
    GValue item = G_VALUE_INIT;
    bool done = false;
    while (!done) {
        switch (gst_iterator_next(iterator, &item)) {
        case GST_ITERATOR_OK: {
            auto *element = GST_ELEMENT(g_value_get_object(&item));
            const QString name = factoryName(element);
            if (name == QStringLiteral("mpph264dec") ||
                name == QStringLiteral("mppvideodec") ||
                name == QStringLiteral("avdec_h264")) {
                fallback = name;
                done = true;
            } else if (fallback.isEmpty() && isVideoDecoder(element)) {
                fallback = name;
            }
            g_value_reset(&item);
            break;
        }
        case GST_ITERATOR_RESYNC:
            gst_iterator_resync(iterator);
            break;
        case GST_ITERATOR_ERROR:
        case GST_ITERATOR_DONE:
            done = true;
            break;
        }
    }
    if (G_VALUE_TYPE(&item) != 0)
        g_value_unset(&item);
    gst_iterator_free(iterator);
    return fallback;
}
