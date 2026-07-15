#pragma once
#include <QObject>
#include <QString>
#include <QList>
#include <qglobal.h>

class SessionModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(int strikes READ strikes NOTIFY strikesChanged)
    Q_PROPERTY(double calories READ calories NOTIFY caloriesChanged)
    Q_PROPERTY(int frequency READ frequency NOTIFY frequencyChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString lastSegment READ lastSegment NOTIFY lastSegmentChanged)
    Q_PROPERTY(int power READ power CONSTANT)
    Q_PROPERTY(int speed READ speed CONSTANT)
    Q_PROPERTY(int endurance READ endurance CONSTANT)
    Q_PROPERTY(int battleLevel READ battleLevel CONSTANT)
    Q_PROPERTY(int score READ score CONSTANT)
public:
    explicit SessionModel(QObject *parent = nullptr);
    Q_INVOKABLE void onKey(int qtKey);
    void onTick();
    int strikes() const { return m_strikes; }
    double calories() const { return m_calories; }
    int frequency() const { return m_frequency; }
    int duration() const { return m_duration; }
    QString lastSegment() const { return m_lastSegment; }
    int power() const { return m_power; }
    int speed() const { return m_speed; }
    int endurance() const { return m_endurance; }
    int battleLevel() const { return m_battleLevel; }
    int score() const { return m_score; }
signals:
    void strikesChanged();
    void caloriesChanged();
    void frequencyChanged();
    void durationChanged();
    void lastSegmentChanged();
private:
    int m_strikes = 0;
    double m_calories = 0.0;
    int m_frequency = 0;
    int m_duration = 0;
    QString m_lastSegment;
    QList<qint64> m_hitTimes; // epoch ms of recent hits (sliding 60s window)
    // static seed values
    int m_power = 72, m_speed = 68, m_endurance = 75, m_battleLevel = 3, m_score = 1280;
};
