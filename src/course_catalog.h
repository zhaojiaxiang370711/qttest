#pragma once

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class CourseCatalog : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList launchers READ launchers CONSTANT)
    Q_PROPERTY(QVariantList courses READ courses CONSTANT)
    Q_PROPERTY(QVariantList moves READ moves CONSTANT)
    Q_PROPERTY(QVariantList focusMittUnits READ focusMittUnits CONSTANT)
    Q_PROPERTY(QString defaultCourseId READ defaultCourseId CONSTANT)
    Q_PROPERTY(int defaultLauncherIndex READ defaultLauncherIndex CONSTANT)
public:
    explicit CourseCatalog(QObject *parent = nullptr);

    QVariantList launchers() const { return m_launchers; }
    QVariantList courses() const { return m_courses; }
    QVariantList moves() const { return m_moves; }
    QVariantList focusMittUnits() const { return m_focusMittUnits; }
    QString defaultCourseId() const { return QStringLiteral("special_practice"); }
    int defaultLauncherIndex() const { return 3; }

    Q_INVOKABLE bool contains(const QString &id) const;
    Q_INVOKABLE QVariantMap course(const QString &id) const;

    static bool isMediaKeyAllowed(const QString &mediaKey);

private:
    QVariantList m_launchers;
    QVariantList m_courses;
    QVariantList m_moves;
    QVariantList m_focusMittUnits;
};
