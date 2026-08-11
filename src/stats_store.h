// ============================================================
// 【教学导读】SQLite 统计存储层：Qt SQL 模块的最小完整用法
// 职责：把"游戏次数（训练会话数）、每日击打次数、累计击打次数"
// 持久化到本地 SQLite 数据库，应用重启后数据仍在。
// 本文件演示的 Qt 概念：
//   1. QSqlDatabase / QSqlQuery — Qt SQL 模块的核心类（驱动 QSQLITE）
//   2. 命名连接 + removeDatabase — 多实例/重复打开时的正确姿势
//   3. QStandardPaths::AppDataLocation — 跨平台的应用数据目录
//      （依赖 main.cpp 的 setApplicationName/setOrganizationName）
// 数据库 schema（见 stats_store.cpp 构造函数）：
//   daily_stats(day PK, strikes)      — 每日击打次数
//   sessions(id PK, started/ended, duration_s, strikes) — 每次运行一行
// 配套阅读：src/main.cpp（接线）、tests/tst_core.cpp（持久化测试）
// ============================================================
#pragma once

#include <QObject>
#include <QSqlDatabase>
#include <QString>

class StatsStore : public QObject {
    Q_OBJECT
    // ready 用 CONSTANT：打开失败是启动期就确定的事，运行中不会变
    Q_PROPERTY(bool ready READ ready CONSTANT)
    Q_PROPERTY(int todayStrikes READ todayStrikes NOTIFY statsChanged)
    Q_PROPERTY(int totalStrikes READ totalStrikes NOTIFY statsChanged)
    Q_PROPERTY(int totalSessions READ totalSessions NOTIFY statsChanged)
public:
    // dbPath 留空时走 QStandardPaths 默认数据目录；测试传入临时目录路径
    explicit StatsStore(QObject *parent = nullptr, const QString &dbPath = QString());
    ~StatsStore() override;

    bool ready() const { return m_ready; }
    int todayStrikes() const { return m_todayStrikes; }
    int totalStrikes() const { return m_totalStrikes; }
    int totalSessions() const { return m_totalSessions; }

    void recordHit();   // 记录一次有效击打（每日 +1、累计 +1）
    void beginSession();                                 // 应用启动：开启一次训练会话
    void endSession(int durationSec, int strikes);       // 应用退出：补全该会话

signals:
    void statsChanged();

private:
    void refreshTotals();   // 启动时从数据库读出三个统计值

    QSqlDatabase m_db;
    QString m_connectionName;   // 命名连接：避免多实例共享默认连接互相覆盖
    bool m_ready = false;
    qint64 m_sessionId = -1;
    int m_todayStrikes = 0;
    int m_totalStrikes = 0;
    int m_totalSessions = 0;
};
