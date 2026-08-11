// ============================================================
// 【教学导读】StatsStore 实现：打开数据库、建表、增删查
// Qt SQL 的标准流程：
//   addDatabase(驱动名, 连接名) → setDatabaseName(文件) → open() → exec(SQL)
// SQLite 的 "数据库" 就是一个本地文件，不需要服务器进程。
// 注意析构里的固定三步（close → 置空 → removeDatabase）：
// QSqlDatabase 要求连接对象全部销毁后才能移除命名连接，否则 Qt 会告警。
// ============================================================
#include "stats_store.h"

#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QVariant>
#include <QtGlobal>

namespace {
// 每日统计以本地日期（yyyy-MM-dd）为行主键
QString todayKey() {
    return QDate::currentDate().toString(Qt::ISODate);
}
} // namespace

StatsStore::StatsStore(QObject *parent, const QString &dbPath) : QObject(parent) {
    QString path = dbPath;
    if (path.isEmpty()) {
        // 例如 ~/.local/share/qxzn/qxzn_hmi/stats.db；
        // 该目录由 main.cpp 的 setOrganizationName/setApplicationName 决定
        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        if (dir.isEmpty() || !QDir().mkpath(dir)) {
            qWarning() << "StatsStore: no writable data dir, persistence disabled";
            return;
        }
        path = dir + QStringLiteral("/stats.db");
    }

    // 用 this 指针生成唯一连接名：默认连接名全局只有一个，
    // 测试里连续构造两个实例时会互相顶掉
    m_connectionName = QStringLiteral("stats_%1").arg(reinterpret_cast<quintptr>(this));
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_db.setDatabaseName(path);
    if (!m_db.open()) {
        qWarning() << "StatsStore: open failed:" << m_db.lastError().text();
        return;
    }

    // IF NOT EXISTS：老版本数据库文件直接复用，起到最简"迁移"效果
    QSqlQuery q(m_db);
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS daily_stats("
        "  day TEXT PRIMARY KEY,"
        "  strikes INTEGER NOT NULL DEFAULT 0)"));
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS sessions("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  started_at TEXT NOT NULL,"
        "  ended_at TEXT,"
        "  duration_s INTEGER NOT NULL DEFAULT 0,"
        "  strikes INTEGER NOT NULL DEFAULT 0)"));

    m_ready = true;
    refreshTotals();
}

StatsStore::~StatsStore() {
    // 固定三步：先 close，再销毁连接对象，最后移除命名连接
    m_db.close();
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(m_connectionName);
}

void StatsStore::recordHit() {
    if (!m_ready)
        return;
    // UPSERT：当天没有行就插入，有就 +1（SQLite 3.24+ 语法）
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "INSERT INTO daily_stats(day, strikes) VALUES(:day, 1) "
        "ON CONFLICT(day) DO UPDATE SET strikes = strikes + 1"));
    q.bindValue(QStringLiteral(":day"), todayKey());
    if (!q.exec()) {
        qWarning() << "StatsStore: recordHit failed:" << q.lastError().text();
        return;
    }
    m_todayStrikes += 1;
    m_totalStrikes += 1;
    emit statsChanged();
}

void StatsStore::beginSession() {
    if (!m_ready)
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral("INSERT INTO sessions(started_at) VALUES(:ts)"));
    q.bindValue(QStringLiteral(":ts"), QDateTime::currentDateTime().toString(Qt::ISODate));
    if (!q.exec()) {
        qWarning() << "StatsStore: beginSession failed:" << q.lastError().text();
        return;
    }
    m_sessionId = q.lastInsertId().toLongLong();
    m_totalSessions += 1;
    emit statsChanged();
}

void StatsStore::endSession(int durationSec, int strikes) {
    if (!m_ready || m_sessionId < 0)
        return;
    QSqlQuery q(m_db);
    q.prepare(QStringLiteral(
        "UPDATE sessions SET ended_at = :ts, duration_s = :dur, strikes = :n "
        "WHERE id = :id"));
    q.bindValue(QStringLiteral(":ts"), QDateTime::currentDateTime().toString(Qt::ISODate));
    q.bindValue(QStringLiteral(":dur"), durationSec);
    q.bindValue(QStringLiteral(":n"), strikes);
    q.bindValue(QStringLiteral(":id"), m_sessionId);
    if (!q.exec())
        qWarning() << "StatsStore: endSession failed:" << q.lastError().text();
}

void StatsStore::refreshTotals() {
    QSqlQuery q(m_db);
    if (q.exec(QStringLiteral("SELECT strikes FROM daily_stats WHERE day = '%1'").arg(todayKey()))
            && q.next())
        m_todayStrikes = q.value(0).toInt();
    if (q.exec(QStringLiteral("SELECT COALESCE(SUM(strikes), 0) FROM daily_stats")) && q.next())
        m_totalStrikes = q.value(0).toInt();
    if (q.exec(QStringLiteral("SELECT COUNT(*) FROM sessions")) && q.next())
        m_totalSessions = q.value(0).toInt();
}
