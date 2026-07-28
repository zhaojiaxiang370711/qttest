#pragma once

#include <QString>

struct MediaPathResult {
    QString path;
    QString diagnostic;

    bool isValid() const { return !path.isEmpty(); }
};

class MediaPathResolver {
public:
    static MediaPathResult resolve(const QString &mediaRoots, const QString &mediaKey);
};
