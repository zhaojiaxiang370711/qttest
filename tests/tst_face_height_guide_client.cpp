#include <QtTest/QtTest>

#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>

#include "face_height_guide_client.h"

namespace {

QString writeHelper(QTemporaryDir &dir, const QByteArray &body) {
    const QString path = dir.filePath(QStringLiteral("fake-face-height-guide.sh"));
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return QString();
    file.write("#!/bin/sh\n");
    file.write(body);
    file.close();
    file.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    return path;
}

} // namespace

class FaceHeightGuideClientTest : public QObject {
    Q_OBJECT

private slots:
    void reportsStartedResponse() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString helper = writeHelper(
            dir, "printf \"response:\\nFaceHeightGuideStart_Response(success=True, message='started')\\n\"\n");
        QVERIFY(!helper.isEmpty());
        qputenv("QXZN_FACE_HEIGHT_GUIDE_HELPER", helper.toUtf8());

        FaceHeightGuideClient client;
        QSignalSpy resultSpy(&client, &FaceHeightGuideClient::resultReceived);
        QVERIFY(client.start(QStringLiteral("qt-test-started")));
        QVERIFY(!client.start(QStringLiteral("duplicate")));
        QTRY_COMPARE_WITH_TIMEOUT(resultSpy.size(), 1, 3000);
        QCOMPARE(client.state(), QStringLiteral("started"));
        QCOMPARE(client.message(), QStringLiteral("started"));
        QVERIFY(!client.busy());
        QCOMPARE(resultSpy.first().at(0).toBool(), true);
        QCOMPARE(resultSpy.first().at(2).toString(), QStringLiteral("qt-test-started"));
    }

    void reportsNoPersonResponse() {
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString helper = writeHelper(
            dir, "printf \"response:\\nFaceHeightGuideStart_Response(success=False, message='no person')\\n\"\n");
        QVERIFY(!helper.isEmpty());
        qputenv("QXZN_FACE_HEIGHT_GUIDE_HELPER", helper.toUtf8());

        FaceHeightGuideClient client;
        QSignalSpy resultSpy(&client, &FaceHeightGuideClient::resultReceived);
        QVERIFY(client.start());
        QTRY_COMPARE_WITH_TIMEOUT(resultSpy.size(), 1, 3000);
        QCOMPARE(client.state(), QStringLiteral("no_person"));
        QCOMPARE(client.message(), QStringLiteral("no person"));
        QCOMPARE(resultSpy.first().at(0).toBool(), false);
        QVERIFY(!client.requestId().isEmpty());
    }
};

QTEST_GUILESS_MAIN(FaceHeightGuideClientTest)

#include "tst_face_height_guide_client.moc"
