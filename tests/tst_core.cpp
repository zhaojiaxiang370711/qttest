#include <QtTest/QtTest>
#include <QStringList>
#include "config.h"
#include "segment_input.h"
#include "session_model.h"

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
    void testSessionIgnoresUnknownKey() {
        SessionModel s;
        s.onKey(Qt::Key_Space);
        QCOMPARE(s.strikes(), 0);
        QVERIFY(s.lastSegment().isEmpty());
    }
};

QTEST_MAIN(CoreTest)
#include "tst_core.moc"
