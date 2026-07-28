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
    emit strikesChanged();
    emit caloriesChanged();
    emit frequencyChanged();
    emit lastSegmentChanged();
}

void SessionModel::onTick() {
    m_duration += 1;
    emit durationChanged();
}
