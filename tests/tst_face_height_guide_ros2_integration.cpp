#include <QtTest/QtTest>

#include <QSignalSpy>

#include "face_height_guide_client.h"

class FaceHeightGuideRos2IntegrationTest : public QObject {
    Q_OBJECT

private slots:
    void reportsStartedFromRos2Service() {
        FaceHeightGuideClient client;
        QSignalSpy resultSpy(&client, &FaceHeightGuideClient::resultReceived);
        QVERIFY(client.start(QStringLiteral("qt-live-started")));
        QTRY_COMPARE_WITH_TIMEOUT(resultSpy.size(), 1, 12000);
        QCOMPARE(resultSpy.first().at(0).toBool(), true);
        QCOMPARE(resultSpy.first().at(1).toString(), QStringLiteral("started"));
        QCOMPARE(client.state(), QStringLiteral("started"));
    }

    void reportsNoPersonFromRos2Service() {
        FaceHeightGuideClient client;
        QSignalSpy resultSpy(&client, &FaceHeightGuideClient::resultReceived);
        QVERIFY(client.start(QStringLiteral("qt-live-no-person")));
        QTRY_COMPARE_WITH_TIMEOUT(resultSpy.size(), 1, 12000);
        QCOMPARE(resultSpy.first().at(0).toBool(), false);
        QCOMPARE(resultSpy.first().at(1).toString(), QStringLiteral("no person"));
        QCOMPARE(client.state(), QStringLiteral("no_person"));
    }
};

int main(int argc, char **argv) {
    if (!qEnvironmentVariableIsSet("QXZN_FACE_HEIGHT_GUIDE_LIVE_TEST")) {
        std::fprintf(stderr, "face_height_guide_ros2: live test disabled; skipping\n");
        return 77;
    }
    QCoreApplication app(argc, argv);
    FaceHeightGuideRos2IntegrationTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_face_height_guide_ros2_integration.moc"
