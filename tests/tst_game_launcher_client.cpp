#include <QtTest/QtTest>

#include <QSignalSpy>
#include <QTcpServer>
#include <QTcpSocket>

#include "config.h"
#include "game_launcher_client.h"

class GameLauncherClientTest : public QObject {
    Q_OBJECT

private slots:
    void rejectsUnknownGame() {
        Config config;
        config.parse({QStringLiteral("--api-base"), QStringLiteral("http://127.0.0.1:8000")});
        GameLauncherClient launcher;
        launcher.configure(config);
        QSignalSpy failed(&launcher, &GameLauncherClient::launchFailed);

        QVERIFY(!launcher.launchGame(QStringLiteral("unknown_game")));
        QCOMPARE(failed.count(), 1);
        QCOMPARE(failed.first().at(0).toString(), QStringLiteral("unknown_game"));
        QVERIFY(!launcher.lastError().isEmpty());
        QVERIFY(!launcher.busy());
    }

    void postsVrBeatsKitLaunchRequest() {
        QTcpServer server;
        QVERIFY(server.listen(QHostAddress::LocalHost, 0));
        QByteArray received;
        bool responded = false;

        connect(&server, &QTcpServer::newConnection, this, [&]() {
            QTcpSocket *socket = server.nextPendingConnection();
            QVERIFY(socket != nullptr);
            connect(socket, &QTcpSocket::readyRead, this, [&, socket]() {
                received.append(socket->readAll());
                if (responded || !received.contains("\r\n\r\n") ||
                    !received.contains("{\"game\":\"vr_beats_kit\"}"))
                    return;
                responded = true;
                const QByteArray body =
                    "{\"status\":\"started\",\"pid\":123,\"game\":\"vr_beats_kit\"}";
                socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " +
                              QByteArray::number(body.size()) + "\r\nConnection: close\r\n\r\n" + body);
                socket->disconnectFromHost();
            });
        });

        Config config;
        config.parse({QStringLiteral("--api-base"),
                      QStringLiteral("http://127.0.0.1:%1").arg(server.serverPort())});
        GameLauncherClient launcher;
        launcher.configure(config);
        QSignalSpy accepted(&launcher, &GameLauncherClient::launchAccepted);
        QSignalSpy failed(&launcher, &GameLauncherClient::launchFailed);

        QVERIFY(launcher.launchGame(QStringLiteral("vr_beats_kit")));
        QVERIFY(launcher.busy());
        QTRY_COMPARE_WITH_TIMEOUT(accepted.count(), 1, 2000);
        QCOMPARE(failed.count(), 0);
        QVERIFY(!launcher.busy());
        QVERIFY(received.startsWith("POST /api/v1/game/start HTTP/1.1\r\n"));
        QVERIFY(received.contains("Content-Type: application/json"));
        QCOMPARE(accepted.first().at(0).toString(), QStringLiteral("vr_beats_kit"));
    }
};

QTEST_MAIN(GameLauncherClientTest)
#include "tst_game_launcher_client.moc"
