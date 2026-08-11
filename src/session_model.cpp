// ============================================================
// 【教学导读】SessionModel 的实现：改数据 + emit 发射 NOTIFY 信号
// 模式很固定：修改成员变量后，立即 emit 对应的 <属性>Changed 信号。
// QML 侧绑定了该属性的表达式（如 Text { text: SessionModel.strikes }）
// 收到信号后自动重新求值 —— 这就是 QML 的"数据驱动界面"。
// 新手最常见的坑：C++ 里改了值却忘了 emit，结果界面不刷新。
// 配套阅读：src/session_model.h（Q_PROPERTY / signals 声明）
// ============================================================
#include "session_model.h"
#include "segment_input.h"
#include <QDateTime>

SessionModel::SessionModel(QObject *parent) : QObject(parent) {}

void SessionModel::onKey(int qtKey) {
    onSegment(SegmentInput::mapKey(qtKey));
}

void SessionModel::onSegment(const QString &segment) {
    if (!SegmentInput::isStandardSegment(segment))
        return;
    m_strikes += 1;
    m_calories += 0.8;
    m_lastSegment = segment;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    m_hitTimes.append(now);
    const qint64 cutoff = now - 60000;
    while (!m_hitTimes.isEmpty() && m_hitTimes.first() < cutoff)
        m_hitTimes.removeFirst();
    m_frequency = m_hitTimes.size();
    // 发射 NOTIFY 信号：QML 里所有绑定到对应属性的表达式会立刻重新求值，界面自动刷新
    emit strikesChanged();
    emit caloriesChanged();
    emit frequencyChanged();
    emit lastSegmentChanged();
}

void SessionModel::onTick() {
    // 每秒由 QTimer 触发一次（见 qml_singletons.h 的 SessionModel 单例工厂）
    m_duration += 1;
    // 发射 NOTIFY 信号，QML 侧的时长显示随即自动更新
    emit durationChanged();
}
