#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QTimer>

class FaceHeightGuideClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString message READ message NOTIFY messageChanged)
    Q_PROPERTY(QString requestId READ requestId NOTIFY requestIdChanged)

public:
    explicit FaceHeightGuideClient(QObject *parent = nullptr);
    ~FaceHeightGuideClient() override;

    bool busy() const { return m_busy; }
    QString state() const { return m_state; }
    QString message() const { return m_message; }
    QString requestId() const { return m_requestId; }

    // Starts one synchronous ROS2 service request without blocking the QML thread.
    // The service response is delivered through resultReceived.
    Q_INVOKABLE bool start(const QString &requestId = QString());

signals:
    void busyChanged();
    void stateChanged();
    void messageChanged();
    void requestIdChanged();
    void resultReceived(bool success, const QString &message, const QString &requestId);

private:
    QString helperPath() const;
    void complete(bool success, const QString &message, const QString &state);
    void setBusy(bool busy);
    void setState(const QString &state);
    void setMessage(const QString &message);
    void setRequestId(const QString &requestId);

    QProcess m_process;
    QTimer m_timeout;
    bool m_busy = false;
    QString m_state = QStringLiteral("idle");
    QString m_message = QStringLiteral("等待高度控制状态");
    QString m_requestId;
};
