#include "segment_input.h"
#include <Qt>

QString SegmentInput::mapKey(int qtKey) {
    switch (qtKey) {
    case Qt::Key_Q: return QStringLiteral("head_left");
    case Qt::Key_W: case Qt::Key_E: return QStringLiteral("head_mid");
    case Qt::Key_R: return QStringLiteral("head_right");
    case Qt::Key_X: return QStringLiteral("chin");
    case Qt::Key_A: return QStringLiteral("waist_left");
    case Qt::Key_S: case Qt::Key_D: return QStringLiteral("waist_mid");
    case Qt::Key_F: return QStringLiteral("waist_right");
    default: return QString();
    }
}

bool SegmentInput::isStandardSegment(const QString &segment) {
    return segment == QStringLiteral("head_left") ||
           segment == QStringLiteral("head_mid") ||
           segment == QStringLiteral("head_right") ||
           segment == QStringLiteral("chin") ||
           segment == QStringLiteral("waist_left") ||
           segment == QStringLiteral("waist_mid") ||
           segment == QStringLiteral("waist_right");
}
