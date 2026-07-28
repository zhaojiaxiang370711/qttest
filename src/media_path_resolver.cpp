#include "media_path_resolver.h"

#include "course_catalog.h"

#include <QDir>
#include <QFileInfo>
#include <QStringList>

MediaPathResult MediaPathResolver::resolve(const QString &mediaRoots, const QString &mediaKey) {
    if (!CourseCatalog::isMediaKeyAllowed(mediaKey))
        return {{}, QStringLiteral("media key is not in the course catalog")};
    if (mediaRoots.trimmed().isEmpty())
        return {{}, QStringLiteral("QXZN_MEDIA_DIR is empty")};

    QStringList diagnostics;
    const QStringList roots = mediaRoots.split(QDir::listSeparator(), Qt::SkipEmptyParts);
    for (const QString &rawRoot : roots) {
        const QString root = rawRoot.trimmed();
        const QFileInfo rootInfo(root);
        if (!rootInfo.isAbsolute() || !rootInfo.exists() || !rootInfo.isDir()) {
            diagnostics.append(QStringLiteral("invalid media root: %1").arg(root));
            continue;
        }

        const QString canonicalRoot = rootInfo.canonicalFilePath();
        if (canonicalRoot.isEmpty()) {
            diagnostics.append(QStringLiteral("cannot canonicalize media root: %1").arg(root));
            continue;
        }

        const QFileInfo candidateInfo(QDir(canonicalRoot).filePath(mediaKey));
        if (!candidateInfo.exists() || !candidateInfo.isFile()) {
            diagnostics.append(QStringLiteral("media file missing under root: %1").arg(canonicalRoot));
            continue;
        }

        const QString canonicalCandidate = candidateInfo.canonicalFilePath();
        QString rootPrefix = canonicalRoot;
        if (!rootPrefix.endsWith(QDir::separator()))
            rootPrefix.append(QDir::separator());
        if (canonicalCandidate.isEmpty() || !canonicalCandidate.startsWith(rootPrefix)) {
            diagnostics.append(QStringLiteral("media file escapes root: %1").arg(canonicalRoot));
            continue;
        }

        return {canonicalCandidate, {}};
    }

    return {{}, diagnostics.join(QStringLiteral("; "))};
}
