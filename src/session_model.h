// ============================================================
// 【教学导读】QObject 数据模型：QML 属性绑定机制的 C++ 一侧
// QML 界面靠 Q_PROPERTY 的 NOTIFY 信号自动刷新，无需手动更新界面
// 本文件演示的 Qt 概念：
//   1. Q_OBJECT — 自定义 QObject 类的必需宏（启用信号槽/属性/运行时类型信息）
//   2. Q_PROPERTY — 把 C++ 成员暴露为 QML 可绑定的属性
//   3. Q_INVOKABLE — 让 QML 的 JavaScript 能直接调用 C++ 成员函数
//   4. signals — 信号只有声明，实现由 moc 自动生成
// 配套阅读：src/session_model.cpp（emit 发射信号）、qml/ 中使用 SessionModel 的页面
// ============================================================
#pragma once
#include <QObject>
#include <QString>
#include <QList>
#include <qglobal.h>

class SessionModel : public QObject {
    // Q_OBJECT：自定义 QObject 类的必需宏，启用信号槽/属性/运行时类型信息
    //（由 moc 处理，依赖 CMakeLists.txt 里的 CMAKE_AUTOMOC）
    Q_OBJECT
    // Q_PROPERTY 把成员暴露为 QML 属性：READ 是 QML 读属性时调用的 getter；
    // NOTIFY 指定值变化时发射的信号，QML 绑定靠它自动更新界面
    Q_PROPERTY(int strikes READ strikes NOTIFY strikesChanged)
    Q_PROPERTY(double calories READ calories NOTIFY caloriesChanged)
    Q_PROPERTY(int frequency READ frequency NOTIFY frequencyChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString lastSegment READ lastSegment NOTIFY lastSegmentChanged)
    // CONSTANT：永不变的属性，QML 只读一次，因此不需要 NOTIFY 信号
    Q_PROPERTY(int power READ power CONSTANT)
    Q_PROPERTY(int speed READ speed CONSTANT)
    Q_PROPERTY(int endurance READ endurance CONSTANT)
    Q_PROPERTY(int battleLevel READ battleLevel CONSTANT)
    Q_PROPERTY(int score READ score CONSTANT)
public:
    explicit SessionModel(QObject *parent = nullptr);
    // Q_INVOKABLE：让 QML 的 JavaScript 能直接调用这个 C++ 成员函数
    Q_INVOKABLE void onKey(int qtKey);
    Q_INVOKABLE void onSegment(const QString &segment);
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
    // 信号只有声明没有实现，实现由 moc 自动生成；在 .cpp 里用 emit 发射
    void strikesChanged();
    void caloriesChanged();
    void frequencyChanged();
    void durationChanged();
    void lastSegmentChanged();
private:
    // m_ 前缀是 Qt 代码常见的成员变量命名约定
    int m_strikes = 0;
    double m_calories = 0.0;
    int m_frequency = 0;
    int m_duration = 0;
    QString m_lastSegment;
    QList<qint64> m_hitTimes; // epoch ms of recent hits (sliding 60s window)
    // static seed values
    int m_power = 72, m_speed = 68, m_endurance = 75, m_battleLevel = 3, m_score = 1280;
};
