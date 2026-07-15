#include <QtTest/QtTest>
#include <QStringList>
#include "config.h"

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
};

QTEST_MAIN(CoreTest)
#include "tst_core.moc"
