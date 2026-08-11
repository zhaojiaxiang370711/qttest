#include <QtTest/QtTest>
#include <QByteArray>
#include <QDir>
#include <QFile>
#include <QList>
#include <QSignalSpy>
#include <QStringList>
#include <QTemporaryDir>
#include <cstdio>
#include <cstring>
#include <initializer_list>
#include "config.h"
#include "course_catalog.h"
#include "course_video_surface.h"
#include "dds_bridge.h"
#include "gst_decoder_policy.h"
#include "media_path_resolver.h"
#if QXZN_HMI_DDS
#include "dds_bridge_api.h"
#endif
#include "segment_input.h"
#include "session_model.h"
#include "stats_store.h"

namespace {

class EnvironmentGuard {
public:
    EnvironmentGuard() {
        for (const char *name : {
                 "PD02_DDS_ENABLE",
                 "PD02_DDS_CORE_LIB",
                 "PD02_DDS_DOMAIN_ID",
                 "PD02_DDS_MULTICAST",
                 "PD02_DDS_INITIAL_PEERS",
                 "PD02_DDS_PARTICIPANT_NAME",
                 "PD02_DDS_HIT_EVENT_TOPIC",
                 "PD02_DDS_LED_COMMAND_TOPIC",
                 "QXZN_MEDIA_DIR",
                 "QXZN_GST_DECODER",
             }) {
            const QByteArray key(name);
            m_saved.append({key, qEnvironmentVariableIsSet(name), qgetenv(name)});
            qunsetenv(name);
        }
    }

    ~EnvironmentGuard() {
        for (const Entry &entry : m_saved) {
            if (entry.wasSet)
                qputenv(entry.name.constData(), entry.value);
            else
                qunsetenv(entry.name.constData());
        }
    }

private:
    struct Entry {
        QByteArray name;
        bool wasSet;
        QByteArray value;
    };
    QList<Entry> m_saved;
};

#if QXZN_HMI_DDS

struct FakeDdsState {
    int createCount = 0;
    int destroyCount = 0;
    int publishAttempts = 0;
    int publishFailuresRemaining = 0;
    bool createFails = false;
    bool takeFails = false;
    QList<qxzn_pd02_hit_event> hits;
    QList<qxzn_pd02_led_command> published;
    uint32_t domainId = 0;
    bool multicast = false;
    QString participant;
    QString initialPeers;
    QString hitTopic;
    QString ledTopic;
};

FakeDdsState *g_fakeDdsState = nullptr;

class FakeDdsScope {
public:
    FakeDdsScope() { g_fakeDdsState = &state; }
    ~FakeDdsScope() { g_fakeDdsState = nullptr; }

    FakeDdsState state;
};

void writeFakeError(char *buffer, uint32_t length, const char *message) {
    if (buffer && length > 0)
        std::snprintf(buffer, length, "%s", message);
}

template <std::size_t Size>
void setFixed(char (&target)[Size], const char *value) {
    std::memset(target, 0, Size);
    std::snprintf(target, Size, "%s", value);
}

qxzn_pd02_dds_context *fakeCreate(const qxzn_pd02_dds_config *config,
                                  char *error, uint32_t errorLength) {
    if (!g_fakeDdsState) {
        writeFakeError(error, errorLength, "missing fake state");
        return nullptr;
    }
    FakeDdsState &state = *g_fakeDdsState;
    ++state.createCount;
    state.domainId = config->domain_id;
    state.multicast = config->enable_multicast != 0;
    state.participant = QString::fromUtf8(config->participant_name ? config->participant_name : "");
    state.initialPeers = QString::fromUtf8(config->initial_peers ? config->initial_peers : "");
    state.hitTopic = QString::fromUtf8(config->hit_event_topic ? config->hit_event_topic : "");
    state.ledTopic = QString::fromUtf8(config->led_command_topic ? config->led_command_topic : "");
    if (state.createFails) {
        writeFakeError(error, errorLength, "fake create failed");
        return nullptr;
    }
    return reinterpret_cast<qxzn_pd02_dds_context *>(&state);
}

void fakeDestroy(qxzn_pd02_dds_context *context) {
    if (context)
        ++reinterpret_cast<FakeDdsState *>(context)->destroyCount;
}

int fakeTakeHitEvent(qxzn_pd02_dds_context *context, qxzn_pd02_hit_event *event,
                     uint32_t, char *error, uint32_t errorLength) {
    auto &state = *reinterpret_cast<FakeDdsState *>(context);
    if (state.takeFails) {
        writeFakeError(error, errorLength, "fake take failed");
        return -1;
    }
    if (state.hits.isEmpty())
        return 0;
    *event = state.hits.takeFirst();
    return 1;
}

int fakePublishLedCommand(qxzn_pd02_dds_context *context,
                          const qxzn_pd02_led_command *command,
                          char *error, uint32_t errorLength) {
    auto &state = *reinterpret_cast<FakeDdsState *>(context);
    ++state.publishAttempts;
    if (state.publishFailuresRemaining > 0) {
        --state.publishFailuresRemaining;
        writeFakeError(error, errorLength, "fake publish failed");
        return -1;
    }
    state.published.append(*command);
    return 0;
}

DdsApi fakeDdsApi() {
    DdsApi api;
    api.create = &fakeCreate;
    api.destroy = &fakeDestroy;
    api.takeHitEvent = &fakeTakeHitEvent;
    api.publishLedCommand = &fakePublishLedCommand;
    return api;
}

qxzn_pd02_hit_event fakeHit(const char *segment = "head_left") {
    qxzn_pd02_hit_event hit{};
    hit.sequence_id = 101;
    hit.timestamp_us = 202;
    setFixed(hit.source, "fake-runtime");
    setFixed(hit.segment, segment);
    setFixed(hit.sensor, "0x14E:0");
    hit.can_id = 0x14E;
    hit.sensor_index = 0;
    hit.change = 12.5;
    hit.rate = 8.25;
    hit.confidence = 1.3;
    setFixed(hit.level, "fast");
    hit.can_read_at_ms = 303;
    hit.hit_detected_at_ms = 404;
    return hit;
}

#endif

} // namespace

class CoreTest : public QObject {
    Q_OBJECT
private slots:
    void testConfigDefaults() {
        Config c;
        QCOMPARE(c.gameId(), QStringLiteral("qxzn_hmi"));
        QCOMPARE(c.difficulty(), QStringLiteral("simple"));
        QCOMPARE(c.maxFps(), 60);
        QVERIFY(!c.windowed());
    }
    void testConfigParse() {
        Config c;
        c.parse({"--game-id", "demo", "--difficulty", "hard",
                 "--max-fps", "30", "--windowed", "--ws-url", "ws://x/ws"});
        QCOMPARE(c.gameId(), QStringLiteral("demo"));
        QCOMPARE(c.difficulty(), QStringLiteral("hard"));
        QCOMPARE(c.maxFps(), 30);
        QVERIFY(c.windowed());
        QCOMPARE(c.wsUrl(), QStringLiteral("ws://x/ws"));
    }
    void testCourseConfigDefaults() {
        EnvironmentGuard environment;
        Config c;
        c.parse({});
        QVERIFY(c.mediaRoot().isEmpty());
        QCOMPARE(c.initialCourse(), QStringLiteral("special_practice"));
    }
    void testCourseConfigEnvironmentAndCliOverride() {
        EnvironmentGuard environment;
        qputenv("QXZN_MEDIA_DIR", "/media/env");
        Config c;
        c.parse({});
        QCOMPARE(c.mediaRoot(), QStringLiteral("/media/env"));
        QCOMPARE(c.initialCourse(), QStringLiteral("special_practice"));

        c.parse({"--media-root", "/media/cli", "--course", "stance"});
        QCOMPARE(c.mediaRoot(), QStringLiteral("/media/cli"));
        QCOMPARE(c.initialCourse(), QStringLiteral("stance"));
    }
    void testCourseConfigParseResets() {
        EnvironmentGuard environment;
        Config c;
        c.parse({"--media-root", "/media/cli", "--course", "right_straight"});
        QCOMPARE(c.mediaRoot(), QStringLiteral("/media/cli"));
        QCOMPARE(c.initialCourse(), QStringLiteral("right_straight"));

        c.parse({});
        QVERIFY(c.mediaRoot().isEmpty());
        QCOMPARE(c.initialCourse(), QStringLiteral("special_practice"));
    }
    void testCourseCatalog() {
        CourseCatalog catalog;
        QCOMPARE(catalog.launchers().size(), 6);
        QCOMPARE(catalog.courses().size(), 3);
        QCOMPARE(catalog.defaultCourseId(), QStringLiteral("special_practice"));
        QCOMPARE(catalog.defaultLauncherIndex(), 3);
        QVERIFY(catalog.contains(QStringLiteral("special_practice")));
        QVERIFY(catalog.contains(QStringLiteral("stance")));
        QVERIFY(catalog.contains(QStringLiteral("right_straight")));
        QVERIFY(!catalog.contains(QStringLiteral("bodycombat")));

        int playableLaunchers = 0;
        for (const QVariant &value : catalog.launchers()) {
            const QVariantMap launcher = value.toMap();
            if (!launcher.value(QStringLiteral("videoCourseId")).toString().isEmpty())
                ++playableLaunchers;
        }
        QCOMPARE(playableLaunchers, 3);

        const QVariantMap special = catalog.course(QStringLiteral("special_practice"));
        QCOMPARE(special.value(QStringLiteral("mediaKey")).toString(),
                 QStringLiteral("course/special_practice.mp4"));
        const QVariantList markers = special.value(QStringLiteral("markers")).toList();
        QCOMPARE(markers.size(), 21);
        QCOMPARE(markers.first().toMap().value(QStringLiteral("timeMs")).toLongLong(), qint64(10190));
        QCOMPARE(markers.first().toMap().value(QStringLiteral("label")).toString(),
                 QStringLiteral("左直拳"));
        QCOMPARE(markers.last().toMap().value(QStringLiteral("timeMs")).toLongLong(), qint64(98030));
        for (const QVariant &markerValue : markers) {
            const QVariantMap marker = markerValue.toMap();
            QVERIFY(!marker.contains(QStringLiteral("action")));
            QVERIFY(!marker.contains(QStringLiteral("actions")));
            QVERIFY(!marker.contains(QStringLiteral("speed_scale")));
        }
        QVERIFY(catalog.course(QStringLiteral("stance"))
                    .value(QStringLiteral("markers")).toList().isEmpty());
        QVERIFY(catalog.course(QStringLiteral("right_straight"))
                    .value(QStringLiteral("markers")).toList().isEmpty());

        // Movements encyclopedia (course_data.gd::moves()): five techniques,
        // each with the fields the Movements view renders.
        const QVariantList moves = catalog.moves();
        QCOMPARE(moves.size(), 5);
        QCOMPARE(moves.first().toMap().value(QStringLiteral("title")).toString(),
                 QStringLiteral("The Lead Jab"));
        QCOMPARE(moves.last().toMap().value(QStringLiteral("chinese")).toString(),
                 QStringLiteral("Weave"));
        for (const QVariant &moveValue : moves) {
            const QVariantMap move = moveValue.toMap();
            QVERIFY(!move.value(QStringLiteral("difficulty")).toString().isEmpty());
            QVERIFY(!move.value(QStringLiteral("timeToLearn")).toString().isEmpty());
            QVERIFY(!move.value(QStringLiteral("desc")).toString().isEmpty());
            QVERIFY(move.value(QStringLiteral("cover")).toString().startsWith(
                        QStringLiteral("qrc:/resources/images/course/move_")));
            QVERIFY(move.value(QStringLiteral("steps")).toList().size() >= 2);
        }

        // Focus-mitt trainer units (course_data.gd::focus_mitt_units): three
        // sequential video units with sbkcourse media keys.
        const QVariantList fmUnits = catalog.focusMittUnits();
        QCOMPARE(fmUnits.size(), 3);
        QCOMPARE(fmUnits.first().toMap().value(QStringLiteral("id")).toString(),
                 QStringLiteral("twelve_punch_combo"));
        for (const QVariant &unitValue : fmUnits) {
            const QVariantMap unit = unitValue.toMap();
            QVERIFY(!unit.value(QStringLiteral("name")).toString().isEmpty());
            QVERIFY(unit.value(QStringLiteral("durationMs")).toLongLong() > 0);
            QVERIFY(unit.value(QStringLiteral("mediaKey")).toString().startsWith(
                        QStringLiteral("sbkcourse/")));
            QVERIFY(CourseCatalog::isMediaKeyAllowed(
                        unit.value(QStringLiteral("mediaKey")).toString()));
        }
    }
    void testMediaPathResolverFindsCatalogMediaAcrossRoots() {
        QTemporaryDir emptyRoot;
        QTemporaryDir mediaRoot;
        QVERIFY(emptyRoot.isValid());
        QVERIFY(mediaRoot.isValid());
        QVERIFY(QDir(mediaRoot.path()).mkpath(QStringLiteral("course")));
        const QString mediaPath = mediaRoot.filePath(QStringLiteral("course/stance_en.mp4"));
        QFile media(mediaPath);
        QVERIFY(media.open(QIODevice::WriteOnly));
        media.write("fixture");
        media.close();

        const QString roots = emptyRoot.path() + QDir::listSeparator() + mediaRoot.path();
        const MediaPathResult result = MediaPathResolver::resolve(
            roots, QStringLiteral("course/stance_en.mp4"));
        QVERIFY2(result.isValid(), qPrintable(result.diagnostic));
        QCOMPARE(result.path, QFileInfo(mediaPath).canonicalFilePath());
    }
    void testMediaPathResolverRejectsUnsafeKeys() {
        QTemporaryDir mediaRoot;
        QVERIFY(mediaRoot.isValid());
        for (const QString &key : {
                 QStringLiteral("../course/stance_en.mp4"),
                 QStringLiteral("/tmp/stance_en.mp4"),
                 QStringLiteral("file:///tmp/stance_en.mp4"),
                 QStringLiteral("qrc:/course/stance_en.mp4"),
                 QStringLiteral("course/not_in_catalog.mp4"),
                 QStringLiteral("course/stance_en.avi"),
             }) {
            const MediaPathResult result = MediaPathResolver::resolve(mediaRoot.path(), key);
            QVERIFY2(!result.isValid(), qPrintable(key));
        }
    }
    void testMediaPathResolverRejectsSymlinkEscape() {
        QTemporaryDir mediaRoot;
        QTemporaryDir outsideRoot;
        QVERIFY(mediaRoot.isValid());
        QVERIFY(outsideRoot.isValid());
        QVERIFY(QDir(mediaRoot.path()).mkpath(QStringLiteral("course")));
        const QString outsidePath = outsideRoot.filePath(QStringLiteral("stance_en.mp4"));
        QFile outside(outsidePath);
        QVERIFY(outside.open(QIODevice::WriteOnly));
        outside.write("fixture");
        outside.close();
        const QString linkPath = mediaRoot.filePath(QStringLiteral("course/stance_en.mp4"));
        QVERIFY(QFile::link(outsidePath, linkPath));

        const MediaPathResult result = MediaPathResolver::resolve(
            mediaRoot.path(), QStringLiteral("course/stance_en.mp4"));
        QVERIFY(!result.isValid());
    }
    void testMediaPathResolverRejectsMissingAndDirectoryTargets() {
        QTemporaryDir mediaRoot;
        QVERIFY(mediaRoot.isValid());
        QVERIFY(QDir(mediaRoot.path()).mkpath(QStringLiteral("course/right_straight_en.mp4")));
        QVERIFY(!MediaPathResolver::resolve(
            mediaRoot.path(), QStringLiteral("course/right_straight_en.mp4")).isValid());
        QVERIFY(!MediaPathResolver::resolve(
            mediaRoot.path(), QStringLiteral("course/special_practice.mp4")).isValid());
        QVERIFY(!MediaPathResolver::resolve(
            QString(), QStringLiteral("course/special_practice.mp4")).isValid());
    }
    void testGstDecoderPolicySoftware() {
        const GstDecoderPolicyResult result = GstDecoderPolicy::configure(
            QStringLiteral("software"));
        QVERIFY2(result.ok, qPrintable(result.error));
        QCOMPARE(result.mode, QStringLiteral("software"));
        QCOMPARE(result.preferredDecoder, QStringLiteral("avdec_h264"));
    }
    void testGstDecoderPolicyAuto() {
        const GstDecoderPolicyResult result = GstDecoderPolicy::configure(
            QStringLiteral("auto"));
        QVERIFY2(result.ok, qPrintable(result.error));
        QCOMPARE(result.mode, QStringLiteral("auto"));
        if (GstDecoderPolicy::factoryAvailable(QStringLiteral("mpph264dec")))
            QCOMPARE(result.preferredDecoder, QStringLiteral("mpph264dec"));
        else if (GstDecoderPolicy::factoryAvailable(QStringLiteral("mppvideodec")))
            QCOMPARE(result.preferredDecoder, QStringLiteral("mppvideodec"));
        else
            QCOMPARE(result.preferredDecoder, QStringLiteral("avdec_h264"));
    }
    void testGstDecoderPolicyMppRequirement() {
        const bool hasMpp = GstDecoderPolicy::factoryAvailable(QStringLiteral("mpph264dec")) ||
                            GstDecoderPolicy::factoryAvailable(QStringLiteral("mppvideodec"));
        const GstDecoderPolicyResult result = GstDecoderPolicy::configure(QStringLiteral("mpp"));
        QCOMPARE(result.ok, hasMpp);
        if (!hasMpp)
            QVERIFY(!result.error.isEmpty());
    }
    void testGstDecoderPolicyRejectsUnknownMode() {
        const GstDecoderPolicyResult result = GstDecoderPolicy::configure(
            QStringLiteral("mystery"));
        QVERIFY(!result.ok);
        QVERIFY(!result.error.isEmpty());
    }
    void testVideoSurfaceContainGeometry() {
        // Empty source/bounds produce no rectangle (no division by zero).
        QVERIFY(!CourseVideoSurface::containRect(QSize(), QRectF(0, 0, 100, 100))
                .isValid());
        QVERIFY(!CourseVideoSurface::containRect(QSize(640, 360), QRectF())
                .isValid());
        // Exact fill when source and area share the same aspect ratio.
        const QRectF fill = CourseVideoSurface::containRect(
            QSize(1280, 720), QRectF(0, 0, 1920, 1080));
        QCOMPARE(fill, QRectF(0, 0, 1920, 1080));
        // 16:9 video in a square area -> letterbox top/bottom, full width used,
        // height shrinks to preserve aspect (scale driven by the width).
        const QRectF letter = CourseVideoSurface::containRect(
            QSize(1280, 720), QRectF(0, 0, 1280, 1280));
        QCOMPARE(letter.width(), 1280.0);
        QCOMPARE(letter.height(), 720.0);
        QCOMPARE(letter.x(), 0.0);
        QCOMPARE(letter.y(), 280.0); // (1280 - 720) / 2
        // Portrait video in a landscape area -> pillarbox left/right, full
        // height used (scale driven by the height).
        const QRectF pillar = CourseVideoSurface::containRect(
            QSize(720, 1280), QRectF(0, 0, 1920, 1080));
        QCOMPARE(pillar.height(), 1080.0);
        QCOMPARE(pillar.width(), 607.5);
        QCOMPARE(pillar.y(), 0.0);
        QVERIFY(pillar.x() > 0.0);
        // The contained rect never exceeds its bounds.
        QVERIFY(letter.x() >= 0.0 && letter.y() >= 0.0);
        QVERIFY(letter.right() <= 1280.0 && letter.bottom() <= 1280.0);
        QVERIFY(pillar.x() >= 0.0 && pillar.right() <= 1920.0);
    }
    void testDdsConfigDefaults() {
        EnvironmentGuard environment;
        Config c;
        c.parse({});
        QVERIFY(c.ddsEnabled());
        QVERIFY(c.ddsCoreLib().isEmpty());
        QCOMPARE(c.ddsDomainId(), 37);
        QVERIFY(!c.ddsMulticast());
        QCOMPARE(c.ddsInitialPeers(), QStringLiteral("127.0.0.1"));
        QCOMPARE(c.ddsParticipant(), QStringLiteral("pd02-qt-hmi"));
        QCOMPARE(c.ddsHitEventTopic(), QStringLiteral("pd02/hit/event"));
        QCOMPARE(c.ddsLedCommandTopic(), QStringLiteral("pd02/led/command"));
    }
    void testDdsConfigEnvironment() {
        EnvironmentGuard environment;
        qputenv("PD02_DDS_ENABLE", "false");
        qputenv("PD02_DDS_CORE_LIB", "/env/libdds.so");
        qputenv("PD02_DDS_DOMAIN_ID", "45");
        qputenv("PD02_DDS_MULTICAST", "yes");
        qputenv("PD02_DDS_INITIAL_PEERS", "10.0.0.2");
        qputenv("PD02_DDS_PARTICIPANT_NAME", "env-hmi");
        qputenv("PD02_DDS_HIT_EVENT_TOPIC", "test/env/hit");
        qputenv("PD02_DDS_LED_COMMAND_TOPIC", "test/env/led");

        Config c;
        c.parse({});
        QVERIFY(!c.ddsEnabled());
        QCOMPARE(c.ddsCoreLib(), QStringLiteral("/env/libdds.so"));
        QCOMPARE(c.ddsDomainId(), 45);
        QVERIFY(c.ddsMulticast());
        QCOMPARE(c.ddsInitialPeers(), QStringLiteral("10.0.0.2"));
        QCOMPARE(c.ddsParticipant(), QStringLiteral("env-hmi"));
        QCOMPARE(c.ddsHitEventTopic(), QStringLiteral("test/env/hit"));
        QCOMPARE(c.ddsLedCommandTopic(), QStringLiteral("test/env/led"));
    }
    void testDdsConfigRejectsNegativeEnvironmentDomain() {
        EnvironmentGuard environment;
        qputenv("PD02_DDS_DOMAIN_ID", "-1");
        Config c;
        c.parse({});
        QCOMPARE(c.ddsDomainId(), 37);
    }
    void testDdsConfigCliOverridesEnvironment() {
        EnvironmentGuard environment;
        qputenv("PD02_DDS_ENABLE", "false");
        qputenv("PD02_DDS_CORE_LIB", "/env/libdds.so");
        qputenv("PD02_DDS_DOMAIN_ID", "45");
        qputenv("PD02_DDS_MULTICAST", "true");
        qputenv("PD02_DDS_INITIAL_PEERS", "10.0.0.2");
        qputenv("PD02_DDS_PARTICIPANT_NAME", "env-hmi");
        qputenv("PD02_DDS_HIT_EVENT_TOPIC", "test/env/hit");
        qputenv("PD02_DDS_LED_COMMAND_TOPIC", "test/env/led");

        Config c;
        c.parse({"--dds", "--dds-core-lib", "/cli/libdds.so",
                 "--dds-domain-id", "46", "--no-dds-multicast",
                 "--dds-initial-peers", "127.0.0.1",
                 "--dds-participant", "cli-hmi",
                 "--dds-hit-event-topic", "test/cli/hit",
                 "--dds-led-command-topic", "test/cli/led"});
        QVERIFY(c.ddsEnabled());
        QCOMPARE(c.ddsCoreLib(), QStringLiteral("/cli/libdds.so"));
        QCOMPARE(c.ddsDomainId(), 46);
        QVERIFY(!c.ddsMulticast());
        QCOMPARE(c.ddsInitialPeers(), QStringLiteral("127.0.0.1"));
        QCOMPARE(c.ddsParticipant(), QStringLiteral("cli-hmi"));
        QCOMPARE(c.ddsHitEventTopic(), QStringLiteral("test/cli/hit"));
        QCOMPARE(c.ddsLedCommandTopic(), QStringLiteral("test/cli/led"));
    }
    void testDdsConfigLastFlagWinsAndParseResets() {
        EnvironmentGuard environment;
        Config c;
        c.parse({"--no-dds", "--dds", "--dds-multicast", "--no-dds-multicast",
                 "--dds-domain-id", "99"});
        QVERIFY(c.ddsEnabled());
        QVERIFY(!c.ddsMulticast());
        QCOMPARE(c.ddsDomainId(), 99);

        c.parse({});
        QVERIFY(c.ddsEnabled());
        QVERIFY(!c.ddsMulticast());
        QCOMPARE(c.ddsDomainId(), 37);
    }
    void testConfigNavOverlayDefaults() {
        Config c;
        QCOMPARE(c.initialNav(), QStringLiteral("home"));
        QVERIFY(c.initialOverlay().isEmpty());
    }
    void testConfigNavOverlayParse() {
        Config c;
        c.parse({"--nav", "learning", "--overlay", "volume_settings"});
        QCOMPARE(c.initialNav(), QStringLiteral("learning"));
        QCOMPARE(c.initialOverlay(), QStringLiteral("volume_settings"));
    }
    void testDdsBridgeDisabledByConfig() {
        EnvironmentGuard environment;
        Config c;
        c.parse({"--no-dds"});

        DdsBridge bridge;
        bridge.start(c);
        QVERIFY(!bridge.enabled());
        QVERIFY(!bridge.ready());
        QCOMPARE(bridge.state(), QStringLiteral("disabled"));
        QVERIFY(bridge.lastError().isEmpty());
        QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor("#ff0000"), 180));
        QVERIFY(!bridge.sendLedCommand({QStringLiteral("head_left")}, QColor("#ff0000"), 180,
                                       QStringLiteral("session"), QString(), QStringLiteral("test")));
        QVERIFY(!bridge.turnOffAllLeds(QStringLiteral("session"), QStringLiteral("test")));
    }
#if QXZN_HMI_DDS
    void testDdsBridgeMissingLibraryIsNonFatal() {
        EnvironmentGuard environment;
        Config c;
        c.parse({"--dds", "--dds-core-lib", "/definitely/missing/libqxzn_pd02_dds_core.so"});

        DdsBridge bridge;
        bridge.start(c);
        QVERIFY(bridge.enabled());
        QVERIFY(!bridge.ready());
        QCOMPARE(bridge.state(), QStringLiteral("error"));
        QVERIFY(bridge.lastError().contains(QStringLiteral("/definitely/missing")));
    }
    void testDdsBridgeReceivesHitAndReturnsReady() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        fake.state.hits.append(fakeHit());
        Config c;
        c.parse({"--dds", "--dds-domain-id", "47",
                 "--dds-initial-peers", "127.0.0.1",
                 "--dds-participant", "test-hmi",
                 "--dds-hit-event-topic", "test/hit",
                 "--dds-led-command-topic", "test/led"});

        DdsBridge bridge(fakeDdsApi());
        QSignalSpy hitSpy(&bridge, &DdsBridge::hitReceived);
        bridge.start(c);

        QTRY_COMPARE_WITH_TIMEOUT(hitSpy.count(), 1, 500);
        const QList<QVariant> arguments = hitSpy.takeFirst();
        QCOMPARE(arguments.at(0).toString(), QStringLiteral("head_left"));
        QCOMPARE(arguments.at(1).toString(), QStringLiteral("fast"));
        QCOMPARE(arguments.at(2).toDouble(), 1.3);
        QCOMPARE(arguments.at(3).toString(), QStringLiteral("0x14E:0"));
        QCOMPARE(arguments.at(4).toInt(), 0x14E);
        QCOMPARE(arguments.at(5).toInt(), 0);
        QCOMPARE(arguments.at(6).toLongLong(), 404);
        QCOMPARE(bridge.lastHitSegment(), QStringLiteral("head_left"));
        QVERIFY(bridge.lastHitAtMs() > 0);
        QCOMPARE(bridge.state(), QStringLiteral("receiving"));
        QVERIFY(bridge.ready());
        QCOMPARE(fake.state.domainId, uint32_t(47));
        QVERIFY(!fake.state.multicast);
        QCOMPARE(fake.state.participant, QStringLiteral("test-hmi"));
        QCOMPARE(fake.state.initialPeers, QStringLiteral("127.0.0.1"));
        QCOMPARE(fake.state.hitTopic, QStringLiteral("test/hit"));
        QCOMPARE(fake.state.ledTopic, QStringLiteral("test/led"));

        QTRY_COMPARE_WITH_TIMEOUT(bridge.state(), QStringLiteral("ready"), 2500);
    }
    void testDdsBridgeRejectsUnknownHit() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        fake.state.hits.append(fakeHit("head_center"));
        Config c;
        c.parse({"--dds"});

        DdsBridge bridge(fakeDdsApi());
        QSignalSpy hitSpy(&bridge, &DdsBridge::hitReceived);
        bridge.start(c);
        QTest::qWait(50);

        QCOMPARE(hitSpy.count(), 0);
        QVERIFY(bridge.lastHitSegment().isEmpty());
        QCOMPARE(bridge.state(), QStringLiteral("ready"));
    }
    void testDdsBridgeRoutesHitWithoutPublishingLed() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        fake.state.hits.append(fakeHit("waist_left"));
        Config c;
        c.parse({"--dds"});
        SessionModel session;
        DdsBridge bridge(fakeDdsApi());
        connect(&bridge, &DdsBridge::hitReceived, &session,
                [&session](const QString &segment) { session.onSegment(segment); });

        bridge.start(c);
        QTRY_COMPARE_WITH_TIMEOUT(session.strikes(), 1, 500);
        QCOMPARE(session.lastSegment(), QStringLiteral("waist_left"));
        QCOMPARE(fake.state.publishAttempts, 0);
    }
    void testDdsBridgeMarshalsLedCommands() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        Config c;
        c.parse({"--dds"});
        DdsBridge bridge(fakeDdsApi());
        bridge.start(c);

        QVERIFY(bridge.flashSegments(
            {QStringLiteral("head_left"), QStringLiteral("waist_right")},
            QColor(12, 34, 56), 6000));
        QCOMPARE(fake.state.published.size(), 2);
        const auto first = fake.state.published.at(0);
        const auto second = fake.state.published.at(1);
        QCOMPARE(QString::fromUtf8(first.segment), QStringLiteral("head_left"));
        QCOMPARE(QString::fromUtf8(second.segment), QStringLiteral("waist_right"));
        QCOMPARE(first.command_type, uint8_t(QXZN_PD02_LED_COMMAND_SET));
        QCOMPARE(first.r, uint8_t(12));
        QCOMPARE(first.g, uint8_t(34));
        QCOMPARE(first.b, uint8_t(56));
        QCOMPARE(first.mode, uint8_t(1));
        QCOMPARE(first.param, uint8_t(0));
        QCOMPARE(first.duration_ms, 5000);
        QCOMPARE(QString::fromUtf8(first.source), QStringLiteral("pd02-qt-hmi"));
        QVERIFY(!QString::fromUtf8(first.session_id).isEmpty());
        QVERIFY(QString::fromUtf8(first.beat_id).isEmpty());
        QCOMPARE(QString::fromUtf8(first.reason), QStringLiteral("qt_hmi"));
        QVERIFY(first.sequence_id < second.sequence_id);
        QVERIFY(first.timestamp_us > 0);

        QVERIFY(bridge.sendLedCommand({QStringLiteral("chin")}, QColor(1, 2, 3), 180,
                                      QStringLiteral("session-1"), QStringLiteral("beat-1"),
                                      QStringLiteral("game")));
        const auto custom = fake.state.published.at(2);
        QCOMPARE(QString::fromUtf8(custom.session_id), QStringLiteral("session-1"));
        QCOMPARE(QString::fromUtf8(custom.beat_id), QStringLiteral("beat-1"));
        QCOMPARE(QString::fromUtf8(custom.reason), QStringLiteral("game"));

        QVERIFY(bridge.turnOffAllLeds(QStringLiteral("session-1"), QStringLiteral("stop")));
        const auto allOff = fake.state.published.at(3);
        QCOMPARE(allOff.command_type, uint8_t(QXZN_PD02_LED_COMMAND_ALL_OFF));
        QVERIFY(QString::fromUtf8(allOff.segment).isEmpty());
        QCOMPARE(QString::fromUtf8(allOff.reason), QStringLiteral("stop"));
    }
    void testDdsBridgeStopsAtFirstPublishFailure() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        fake.state.publishFailuresRemaining = 1;
        Config c;
        c.parse({"--dds"});
        DdsBridge bridge(fakeDdsApi());
        bridge.start(c);

        QVERIFY(!bridge.flashSegments(
            {QStringLiteral("head_left"), QStringLiteral("head_right")},
            QColor(1, 2, 3), 180));
        QCOMPARE(fake.state.publishAttempts, 1);
        QCOMPARE(fake.state.published.size(), 0);
        QVERIFY(!bridge.lastError().isEmpty());
    }
    void testDdsBridgeRebuildsAfterThreePublishFailures() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        fake.state.publishFailuresRemaining = 3;
        Config c;
        c.parse({"--dds"});
        DdsBridge bridge(fakeDdsApi());
        bridge.start(c);

        for (int i = 0; i < 3; ++i)
            QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        QTRY_COMPARE_WITH_TIMEOUT(fake.state.createCount, 2, 500);
        QCOMPARE(fake.state.destroyCount, 1);
        QVERIFY(bridge.ready());
    }
    void testDdsBridgeSuccessfulPublishResetsFailureCount() {
        EnvironmentGuard environment;
        FakeDdsScope fake;
        Config c;
        c.parse({"--dds"});
        DdsBridge bridge(fakeDdsApi());
        bridge.start(c);

        fake.state.publishFailuresRemaining = 2;
        QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        QVERIFY(bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        fake.state.publishFailuresRemaining = 2;
        QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        QVERIFY(!bridge.flashSegments({QStringLiteral("head_left")}, QColor(1, 2, 3), 180));
        QTest::qWait(20);
        QCOMPARE(fake.state.createCount, 1);
        QCOMPARE(fake.state.destroyCount, 0);
    }
#endif
    void testSegmentMapping() {
        using SI = SegmentInput;
        QCOMPARE(SI::mapKey(Qt::Key_Q), QStringLiteral("head_left"));
        QCOMPARE(SI::mapKey(Qt::Key_W), QStringLiteral("head_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_E), QStringLiteral("head_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_R), QStringLiteral("head_right"));
        QCOMPARE(SI::mapKey(Qt::Key_X), QStringLiteral("chin"));
        QCOMPARE(SI::mapKey(Qt::Key_A), QStringLiteral("waist_left"));
        QCOMPARE(SI::mapKey(Qt::Key_S), QStringLiteral("waist_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_D), QStringLiteral("waist_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_F), QStringLiteral("waist_right"));
        QCOMPARE(SI::mapKey(Qt::Key_Space), QStringLiteral(""));
    }
    void testStandardSegmentValidation() {
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("head_left")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("head_mid")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("head_right")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("chin")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("waist_left")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("waist_mid")));
        QVERIFY(SegmentInput::isStandardSegment(QStringLiteral("waist_right")));
        QVERIFY(!SegmentInput::isStandardSegment(QStringLiteral("head_center")));
        QVERIFY(!SegmentInput::isStandardSegment(QString()));
    }
    void testSessionAccumulation() {
        SessionModel s;
        QCOMPARE(s.strikes(), 0);
        s.onKey(Qt::Key_Q);
        s.onKey(Qt::Key_A);
        QCOMPARE(s.strikes(), 2);
        QCOMPARE(s.lastSegment(), QStringLiteral("waist_left"));
        QVERIFY(s.calories() > 0.0);
        QVERIFY(s.frequency() >= 1);
        s.onTick();
        QCOMPARE(s.duration(), 1);
    }
    void testSessionDirectSegmentUsesKeyboardPath() {
        SessionModel direct;
        direct.onSegment(QStringLiteral("head_left"));

        SessionModel keyboard;
        keyboard.onKey(Qt::Key_Q);

        QCOMPARE(direct.strikes(), keyboard.strikes());
        QCOMPARE(direct.calories(), keyboard.calories());
        QCOMPARE(direct.frequency(), keyboard.frequency());
        QCOMPARE(direct.lastSegment(), keyboard.lastSegment());
    }
    void testSessionIgnoresUnknownKey() {
        SessionModel s;
        s.onKey(Qt::Key_Space);
        QCOMPARE(s.strikes(), 0);
        QVERIFY(s.lastSegment().isEmpty());
    }
    void testSessionIgnoresUnknownSegment() {
        SessionModel s;
        s.onSegment(QStringLiteral("head_center"));
        QCOMPARE(s.strikes(), 0);
        QVERIFY(s.lastSegment().isEmpty());
    }
    // StatsStore：写入 -> 销毁 -> 重新打开，验证数据真的落盘持久化
    void testStatsStorePersistsAcrossInstances() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString dbPath = dir.filePath(QStringLiteral("stats.db"));
        {
            StatsStore store(nullptr, dbPath);
            QVERIFY(store.ready());
            QCOMPARE(store.todayStrikes(), 0);
            QCOMPARE(store.totalSessions(), 0);
            store.beginSession();
            store.recordHit();
            store.recordHit();
            store.endSession(12, 2);
            QCOMPARE(store.todayStrikes(), 2);
            QCOMPARE(store.totalStrikes(), 2);
            QCOMPARE(store.totalSessions(), 1);
        }
        {   // 新实例打开同一数据库文件：统计值应从磁盘读回
            StatsStore reopened(nullptr, dbPath);
            QVERIFY(reopened.ready());
            QCOMPARE(reopened.todayStrikes(), 2);
            QCOMPARE(reopened.totalStrikes(), 2);
            QCOMPARE(reopened.totalSessions(), 1);
        }
    }
    // 无效路径（目录不存在且不可创建）时 ready 为 false，读写静默降级不崩溃
    void testStatsStoreOpenFailureIsNonFatal() {
        StatsStore store(nullptr, QStringLiteral("/nonexistent-dir-x/stats.db"));
        QVERIFY(!store.ready());
        store.beginSession();
        store.recordHit();
        store.endSession(1, 1);
        QCOMPARE(store.todayStrikes(), 0);
    }
};

QTEST_GUILESS_MAIN(CoreTest)
#include "tst_core.moc"
