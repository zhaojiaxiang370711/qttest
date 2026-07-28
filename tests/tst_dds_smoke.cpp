#include <QtTest/QtTest>

#include <QCoreApplication>
#include <QLibrary>
#include <QSignalSpy>
#include <cstddef>
#include <cstdio>
#include <cstring>

#include "config.h"
#include "dds_bridge.h"
#include <qxzn/pd02/dds/motor_bridge.h>

namespace {

template <std::size_t Size>
void setFixed(char (&target)[Size], const char *value) {
    std::memset(target, 0, Size);
    std::snprintf(target, Size, "%s", value);
}

struct ContextGuard {
    qxzn_pd02_dds_context *context = nullptr;
    decltype(&qxzn_pd02_dds_destroy) destroy = nullptr;

    ~ContextGuard() {
        if (context && destroy)
            destroy(context);
    }
};

} // namespace

class DdsSmokeTest : public QObject {
    Q_OBJECT
private slots:
    void roundTrip() {
        const QString corePath = QString::fromUtf8(qgetenv("PD02_DDS_CORE_LIB"));
        QLibrary library(corePath);
        QVERIFY2(library.load(), qPrintable(library.errorString()));

        const auto create = reinterpret_cast<decltype(&qxzn_pd02_dds_create)>(
            library.resolve("qxzn_pd02_dds_create"));
        const auto destroy = reinterpret_cast<decltype(&qxzn_pd02_dds_destroy)>(
            library.resolve("qxzn_pd02_dds_destroy"));
        const auto publishHit = reinterpret_cast<decltype(&qxzn_pd02_dds_publish_hit_event)>(
            library.resolve("qxzn_pd02_dds_publish_hit_event"));
        const auto takeLed = reinterpret_cast<decltype(&qxzn_pd02_dds_take_led_command)>(
            library.resolve("qxzn_pd02_dds_take_led_command"));
        QVERIFY(create);
        QVERIFY(destroy);
        QVERIFY(publishHit);
        QVERIFY(takeLed);

        const qint64 pid = QCoreApplication::applicationPid();
        const uint32_t domainId = uint32_t(140 + (pid % 30));
        const QString prefix = QStringLiteral("pd02/test/qxzn-hmi/%1").arg(pid);
        const QString hitTopic = prefix + QStringLiteral("/hit/event");
        const QString ledTopic = prefix + QStringLiteral("/led/command");
        const QByteArray peerName = QByteArrayLiteral("qxzn-hmi-dds-smoke-peer");
        const QByteArray peers = QByteArrayLiteral("127.0.0.1");
        const QByteArray hitTopicUtf8 = hitTopic.toUtf8();
        const QByteArray ledTopicUtf8 = ledTopic.toUtf8();

        qxzn_pd02_dds_config peerConfig{};
        peerConfig.domain_id = domainId;
        peerConfig.enable_multicast = 0;
        peerConfig.participant_name = peerName.constData();
        peerConfig.initial_peers = peers.constData();
        peerConfig.hit_event_topic = hitTopicUtf8.constData();
        peerConfig.led_command_topic = ledTopicUtf8.constData();
        char error[QXZN_PD02_DDS_ERROR_LEN] = {};
        ContextGuard peer;
        peer.destroy = destroy;
        peer.context = create(&peerConfig, error, QXZN_PD02_DDS_ERROR_LEN);
        QVERIFY2(peer.context, error);

        Config config;
        config.parse({
            QStringLiteral("--dds"),
            QStringLiteral("--dds-core-lib"), corePath,
            QStringLiteral("--dds-domain-id"), QString::number(domainId),
            QStringLiteral("--no-dds-multicast"),
            QStringLiteral("--dds-initial-peers"), QStringLiteral("127.0.0.1"),
            QStringLiteral("--dds-participant"), QStringLiteral("qxzn-hmi-dds-smoke"),
            QStringLiteral("--dds-hit-event-topic"), hitTopic,
            QStringLiteral("--dds-led-command-topic"), ledTopic,
        });
        DdsBridge bridge;
        QSignalSpy hitSpy(&bridge, &DdsBridge::hitReceived);
        bridge.start(config);
        QTRY_VERIFY_WITH_TIMEOUT(bridge.ready(), 3000);
        QTest::qWait(600);

        qxzn_pd02_hit_event hit{};
        hit.sequence_id = 7001;
        hit.timestamp_us = 7002;
        setFixed(hit.source, "dds-smoke-peer");
        setFixed(hit.segment, "waist_right");
        setFixed(hit.sensor, "0x14C:2");
        hit.can_id = 0x14C;
        hit.sensor_index = 2;
        hit.change = 22.5;
        hit.rate = 11.25;
        hit.confidence = 1.6;
        setFixed(hit.level, "fast");
        hit.can_read_at_ms = 7003;
        hit.hit_detected_at_ms = 7004;
        QVERIFY2(publishHit(peer.context, &hit, error, QXZN_PD02_DDS_ERROR_LEN) == 0, error);

        QTRY_COMPARE_WITH_TIMEOUT(hitSpy.count(), 1, 3000);
        const QList<QVariant> arguments = hitSpy.takeFirst();
        QCOMPARE(arguments.at(0).toString(), QStringLiteral("waist_right"));
        QCOMPARE(arguments.at(1).toString(), QStringLiteral("fast"));
        QCOMPARE(arguments.at(2).toDouble(), 1.6);
        QCOMPARE(arguments.at(3).toString(), QStringLiteral("0x14C:2"));
        QCOMPARE(arguments.at(4).toInt(), 0x14C);
        QCOMPARE(arguments.at(5).toInt(), 2);
        QCOMPARE(arguments.at(6).toLongLong(), qint64(7004));

        QVERIFY(bridge.sendLedCommand(
            {QStringLiteral("head_left")}, QColor(9, 8, 7), 180,
            QStringLiteral("dds-smoke-session"), QStringLiteral("beat-1"),
            QStringLiteral("dds-smoke")));
        qxzn_pd02_led_command led{};
        QCOMPARE(takeLed(peer.context, &led, 3000, error, QXZN_PD02_DDS_ERROR_LEN), 1);
        QCOMPARE(QString::fromUtf8(led.source), QStringLiteral("pd02-qt-hmi"));
        QCOMPARE(QString::fromUtf8(led.session_id), QStringLiteral("dds-smoke-session"));
        QCOMPARE(QString::fromUtf8(led.beat_id), QStringLiteral("beat-1"));
        QCOMPARE(QString::fromUtf8(led.segment), QStringLiteral("head_left"));
        QCOMPARE(led.command_type, uint8_t(QXZN_PD02_LED_COMMAND_SET));
        QCOMPARE(led.r, uint8_t(9));
        QCOMPARE(led.g, uint8_t(8));
        QCOMPARE(led.b, uint8_t(7));
        QCOMPARE(led.mode, uint8_t(1));
        QCOMPARE(led.param, uint8_t(0));
        QCOMPARE(led.duration_ms, 180);
        QCOMPARE(QString::fromUtf8(led.reason), QStringLiteral("dds-smoke"));
    }
};

int main(int argc, char **argv) {
    if (!qEnvironmentVariableIsSet("PD02_DDS_CORE_LIB")) {
        std::fprintf(stderr, "dds_smoke: PD02_DDS_CORE_LIB is unset; skipping\n");
        return 77;
    }
    QCoreApplication app(argc, argv);
    DdsSmokeTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "tst_dds_smoke.moc"
