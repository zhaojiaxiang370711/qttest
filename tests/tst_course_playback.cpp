#include <QtTest/QtTest>

#include <QCoreApplication>
#include <QFileInfo>
#include <QSignalSpy>
#include <cmath>
#include <cstdio>

#include "config.h"
#include "course_playback_controller.h"

class CoursePlaybackTest : public QObject {
    Q_OBJECT
private slots:
    void playbackLifecycle() {
        const QString mediaRoot = QString::fromUtf8(qgetenv("QXZN_MEDIA_DIR"));
        QVERIFY(!mediaRoot.isEmpty());
        qputenv("QXZN_GST_DECODER", "software");
        qputenv("QXZN_MEDIA_AUDIO_SINK", "fakesink");

        Config config;
        config.parse({QStringLiteral("--media-root"), mediaRoot,
                      QStringLiteral("--course"), QStringLiteral("special_practice"),
                      QStringLiteral("--no-dds")});
        CoursePlaybackController player;
        player.configure(config);
        QSignalSpy frameSpy(&player, &CoursePlaybackController::frameReady);

        QVERIFY(player.openCourse(QStringLiteral("special_practice")));
        QTRY_VERIFY_WITH_TIMEOUT(player.state() == QStringLiteral("playing") ||
                                 player.state() == QStringLiteral("buffering"), 5000);
        QTRY_VERIFY_WITH_TIMEOUT(frameSpy.count() > 0, 10000);
        QTRY_COMPARE_WITH_TIMEOUT(player.decoderName(), QStringLiteral("avdec_h264"), 5000);
        QCOMPARE(player.rendererMode(), QStringLiteral("cpu-copy"));
        QCOMPARE(player.courseId(), QStringLiteral("special_practice"));
        QVERIFY(player.durationMs() > 100000);

        player.pause();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), QStringLiteral("paused"), 3000);

        // Marker labels: 10190/14040/17190ms = "左直拳", 22140/25190/29040ms =
        // "右直拳". Probe each label at a midpoint that stays inside one marker's
        // range even with GStreamer keyframe seek slop, so the assertion does not
        // depend on landing exactly on a boundary.
        player.seekMs(13000);
        QTRY_COMPARE_WITH_TIMEOUT(player.currentMarkerLabel(), QStringLiteral("左直拳"), 3000);
        player.seekMs(25500);
        QTRY_COMPARE_WITH_TIMEOUT(player.currentMarkerLabel(), QStringLiteral("右直拳"), 3000);

        QVERIFY(player.hasPreviousMarker());
        QVERIFY(player.hasNextMarker());
        const qint64 anchor = player.positionMs();
        player.seekNextMarker();
        QTRY_VERIFY_WITH_TIMEOUT(player.positionMs() > anchor, 3000);
        const qint64 afterNext = player.positionMs();
        player.seekPreviousMarker();
        QTRY_VERIFY_WITH_TIMEOUT(player.positionMs() < afterNext, 3000);

        player.setVolume(0.35);
        QCOMPARE(player.volume(), 0.35);
        player.setMuted(true);
        QVERIFY(player.muted());
        player.setMuted(false);
        QVERIFY(!player.muted());

        player.seekMs(player.durationMs() - 700);
        player.play();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), QStringLiteral("ended"), 6000);
        player.replay();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), QStringLiteral("playing"), 3000);
        QTRY_VERIFY_WITH_TIMEOUT(player.positionMs() < 3000, 3000);

        player.stop();
        QTRY_COMPARE_WITH_TIMEOUT(player.state(), QStringLiteral("idle"), 3000);
    }
};

int main(int argc, char **argv) {
    const QString root = QString::fromUtf8(qgetenv("QXZN_MEDIA_DIR"));
    const QString fixture = root + QStringLiteral("/course/special_practice.mp4");
    if (root.isEmpty() || !QFileInfo::exists(fixture)) {
        std::fprintf(stderr, "course_playback: QXZN_MEDIA_DIR fixture missing; skipping\n");
        return 77;
    }
    QCoreApplication app(argc, argv);
    CoursePlaybackTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_course_playback.moc"
