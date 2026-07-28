#pragma once
#include <QString>

class SegmentInput {
public:
    // Map a Qt::Key_* to a standard segment name; empty string if unmapped.
    static QString mapKey(int qtKey);
    static bool isStandardSegment(const QString &segment);
};
