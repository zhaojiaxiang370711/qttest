# qxzn-hmi-qt HMI Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a runnable, interactive Qt Quick port of the Godot car-HMI shell (TopBar + Dashboard) where keyboard "segment" hits drive a live dashboard, and use it to dogfood `qtcli`.

**Architecture:** `qxzn_core` static lib holds testable C++ logic (Config parsing, SegmentInput key→segment mapping, SessionModel accumulation); the `qxzn_hmi` app is QML (loaded via `qt_add_resources` + `QQmlApplicationEngine`) bound to a `SessionModel` context property; a `tst_core` Qt-Test exe covers the logic.

**Tech Stack:** Qt 6.11 (Core/Gui/Quick/QuickControls2/Qml/Test), CMake ≥ 3.21, C++17, QML.

## Global Constraints

- Qt **6.11** at `/opt/Qt/6.11.1/gcc_64`; build with that Qt (`-DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64` if the `qtcli`/default `qmake6` isn't auto-detected). `qmake6` and `cmake` are on PATH.
- Project root: `/home/x/code/pd02/qxzn-hmi-qt` (own git repo, branch from `master`; spec already committed at `a0248b9`).
- Modules referenced: `Qt6::Core`, `Qt6::Gui`, `Qt6::Quick`, `Qt6::QuickControls2`, `Qt6::Qml`, `Qt6::Test`. Verify with `qtcli --json modules` (from `/home/x/code/pd02/tools/qtcli`).
- Font: reuse `/home/x/code/pd02/15-6inch-game-runtime-qxzn/assets/fonts/almmsht/AlimamaShuHeiTi-Bold.ttf` (copy into `resources/fonts/`).
- C++ standard 17, `CMAKE_AUTOMOC ON`. QML loaded via `qt_add_resources` (PREFIX `/`) and `engine.load(QUrl("qrc:/qml/main.qml"))`; sibling QML components resolve by shared directory.
- Dark theme (~bg `#0f1115`, panel `#16191f`, accent `#3fd0c9`); functional, not pixel-perfect.
- Segment keys map EXACTLY: Q→head_left, W/E→head_mid, R→head_right, X→chin, A→waist_left, S/D→waist_mid, F→waist_right; all other keys ignored.
- Commit per task. Message prefix style: `feat:`/`fix:`/`test:`/`docs:`/`chore:`.
- `.gitignore` already present: `/build/`, `*.user`, `*.log`, `.DS_Store`.

---

## File Structure

| File | Responsibility |
|---|---|
| `CMakeLists.txt` | Three targets: `qxzn_core` (static lib), `qxzn_hmi` (app exe), `tst_core` (Qt-Test exe). |
| `src/main.cpp` | QGuiApplication, font load, Config parse, SessionModel + duration QTimer, QQmlApplicationEngine, context properties, kiosk/show, `--quit-after-ms` smoke hook. |
| `src/config.h` / `config.cpp` | `Config : QObject` with Q_PROPERTY for wsUrl/apiBase/gameId/difficulty/maxFps/windowed; `Q_INVOKABLE parse(QStringList)`. |
| `src/segment_input.h` / `segment_input.cpp` | `SegmentInput::mapKey(int qtKey) -> QString` (static). |
| `src/session_model.h` / `session_model.cpp` | `SessionModel : QObject` with Q_PROPERTY (strikes/calories/frequency/duration/lastSegment + CONSTANT power/speed/endurance/battleLevel/score); `Q_INVOKABLE onKey(int)`, `onTick()`. |
| `qml/main.qml` | ApplicationWindow, key sink (→ `session.onKey`), TopBar, page Loader, Esc shortcut. |
| `qml/TopBar.qml` | Avatar + brand + 4 nav (sets `activeNav`) + wifi/battery icons + live clock (Timer) + exit button. |
| `qml/Dashboard.qml` | Summary + 3×StatPanel + 5×MetricPill + Schedule, bound to `session`. |
| `qml/MetricPill.qml` | Reusable: icon + value + caption. |
| `qml/StatPanel.qml` | Reusable: title + value + caption. |
| `qml/PlaceholderPage.qml` | "未移植" placeholder for non-home nav. |
| `resources/fonts/AlimamaShuHeiTi-Bold.ttf` | Bundled font (copied from Godot project). |
| `tests/tst_core.cpp` | Qt-Test: Config parse, SegmentInput mapping, SessionModel accumulation. |
| `tests/smoke.sh` | Offscreen run via `--quit-after-ms`, assert exit 0. |
| `README.md` / `README.zh-CN.md` / `LICENSE` | Docs. |
| `docs/dogfood/BACKLOG.md` | qtcli gaps found while building. |

---

### Task 1: CMake scaffold + minimal QML window

**Files:**
- Create: `CMakeLists.txt`, `src/main.cpp`, `qml/main.qml`

**Interfaces:**
- Produces: targets `qxzn_core` (empty for now — see note), `qxzn_hmi` (loads `qrc:/qml/main.qml`).

- [ ] **Step 1: Write `CMakeLists.txt`** (Task 1 form; later tasks append sources/resources)

```cmake
cmake_minimum_required(VERSION 3.21)
project(qxzn_hmi VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.11 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Qml Test)

qt_standard_project_setup()

# core logic library (sources added in later tasks)
add_library(qxzn_core STATIC)
target_include_directories(qxzn_core PUBLIC src)
target_link_libraries(qxzn_core PUBLIC Qt6::Core)

# application
qt_add_executable(qxzn_hmi src/main.cpp)
target_link_libraries(qxzn_hmi PRIVATE qxzn_core Qt6::Gui Qt6::Quick Qt6::QuickControls2 Qt6::Qml)
qt_add_resources(qxzn_hmi "appqml"
    PREFIX "/"
    FILES
        qml/main.qml
)
set_target_properties(qxzn_hmi PROPERTIES WIN32_EXECUTABLE TRUE MACOSX_BUNDLE TRUE)
```

- [ ] **Step 2: Write `src/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}
```

- [ ] **Step 3: Write `qml/main.qml`**

```qml
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    width: 1280
    height: 720
    visible: true
    color: "#0f1115"
    title: "QXZN HMI"

    Label {
        anchors.centerIn: parent
        text: "QXZN HMI Shell"
        color: "#e6e8eb"
        font.pixelSize: 48
    }
}
```

- [ ] **Step 4: Configure & build**

```bash
cd /home/x/code/pd02/qxzn-hmi-qt
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build
```
Expected: builds `build/qxzn_hmi` with no errors. (A static lib with no sources is allowed by CMake.)

- [ ] **Step 5: Verify it runs (offscreen)**

Run: `QSG_RHI_BACKEND=software ./build/qxzn_hmi -platform offscreen --quit-after-ms 500 2>/dev/null & sleep 1` — note: `--quit-after-ms` is not wired yet, so this will hang; instead verify with a quick timeout:
```bash
timeout 2 env ./build/qxzn_hmi -platform offscreen; echo "exit=$?"
```
Expected: runs for ~2s then `timeout` returns 124 (no crash; a crash would be 139/134).

- [ ] **Step 6: Commit**

```bash
git add CMakeLists.txt src/main.cpp qml/main.qml
git commit -m "feat: scaffold Qt Quick app with CMake (qxzn_core + qxzn_hmi)"
```

---

### Task 2: Font + dark theme baseline

**Files:**
- Create: `resources/fonts/AlimamaShuHeiTi-Bold.ttf` (copy)
- Modify: `CMakeLists.txt` (add font to resources), `src/main.cpp` (load font), `qml/main.qml` (apply font + dark style)

- [ ] **Step 1: Copy the font**

```bash
mkdir -p /home/x/code/pd02/qxzn-hmi-qt/resources/fonts
cp /home/x/code/pd02/15-6inch-game-runtime-qxzn/assets/fonts/almmsht/AlimamaShuHeiTi-Bold.ttf /home/x/code/pd02/qxzn-hmi-qt/resources/fonts/
```

- [ ] **Step 2: Add font to resources in `CMakeLists.txt`** — replace the `qt_add_resources` block with:

```cmake
qt_add_resources(qxzn_hmi "appqml"
    PREFIX "/"
    FILES
        qml/main.qml
        resources/fonts/AlimamaShuHeiTi-Bold.ttf
)
```

- [ ] **Step 3: Load the font in `src/main.cpp`** — add after the `QGuiApplication` line:

```cpp
#include <QFontDatabase>
// ... inside main, after QGuiApplication app(...):
QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaShuHeiTi-Bold.ttf"));
```

- [ ] **Step 4: Apply font in `qml/main.qml`** — set on the ApplicationWindow:

```qml
    font.family: "Alimama Shu HeiTi"
    Label {
        anchors.centerIn: parent
        text: "QXZN HMI 外壳"
        color: "#e6e8eb"
        font.family: "Alimama Shu HeiTi"
        font.pixelSize: 48
        font.bold: true
    }
```
(Replace the existing placeholder Label.)

- [ ] **Step 5: Build & verify**

```bash
cmake --build build
timeout 2 ./build/qxzn_hmi -platform offscreen; echo "exit=$?"
```
Expected: builds; runs without crash (exit 124 from timeout).

- [ ] **Step 6: Commit**

```bash
git add CMakeLists.txt src/main.cpp qml/main.qml resources/fonts/AlimamaShuHeiTi-Bold.ttf
git commit -m "feat: bundle AlimamaShuHeiTi font and dark baseline"
```

---

### Task 3: Config class + Qt-Test harness

**Files:**
- Create: `src/config.h`, `src/config.cpp`, `tests/tst_core.cpp`
- Modify: `CMakeLists.txt` (add config to qxzn_core; add tst_core target)

**Interfaces:**
- Produces: `Config` (QObject, Q_PROPERTY wsUrl/apiBase/gameId/difficulty/maxFps/windowed, `Q_INVOKABLE void parse(const QStringList&)`); the `tst_core` test exe target.

- [ ] **Step 1: Write the failing test first (`tests/tst_core.cpp`)**

```cpp
#include <QtTest/QtTest>
#include <QStringList>
#include "config.h"

class CoreTest : public QObject {
    Q_OBJECT
private slots:
    void testConfigDefaults() {
        Config c;
        QCOMPARE(c.gameId(), QStringLiteral("qxzn_hmi"));
        QCOMPARE(c.difficulty(), QStringLiteral("simple"));
        QCOMPARE(c.maxFps(), 60);
        QVERIFY(!c.windowed());
    }
    void testConfigParse() {
        Config c;
        c.parse({"--game-id", "demo", "--difficulty", "hard",
                 "--max-fps", "30", "--windowed", "--ws-url", "ws://x/ws"});
        QCOMPARE(c.gameId(), QStringLiteral("demo"));
        QCOMPARE(c.difficulty(), QStringLiteral("hard"));
        QCOMPARE(c.maxFps(), 30);
        QVERIFY(c.windowed());
        QCOMPARE(c.wsUrl(), QStringLiteral("ws://x/ws"));
    }
};

QTEST_MAIN(CoreTest)
#include "tst_core.moc"
```

- [ ] **Step 2: Wire the test target in `CMakeLists.txt`** — append:

```cmake
enable_testing()
qt_add_executable(tst_core tests/tst_core.cpp)
target_link_libraries(tst_core PRIVATE qxzn_core Qt6::Test)
add_test(NAME tst_core COMMAND tst_core)
```
And add the config source to qxzn_core:
```cmake
add_library(qxzn_core STATIC
    src/config.cpp
)
```
(replacing the empty `add_library(qxzn_core STATIC)` line.)

- [ ] **Step 3: Run the test to verify it fails (RED)**

```bash
cmake --build build && (cd build && ctest --output-on-failure)
```
Expected: build FAILS — `config.h` not found / `Config` undefined.

- [ ] **Step 4: Write `src/config.h`**

```cpp
#pragma once
#include <QObject>
#include <QString>
#include <QStringList>

class Config : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString wsUrl READ wsUrl CONSTANT)
    Q_PROPERTY(QString apiBase READ apiBase CONSTANT)
    Q_PROPERTY(QString gameId READ gameId CONSTANT)
    Q_PROPERTY(QString difficulty READ difficulty CONSTANT)
    Q_PROPERTY(int maxFps READ maxFps CONSTANT)
    Q_PROPERTY(bool windowed READ windowed CONSTANT)
public:
    explicit Config(QObject *parent = nullptr);
    Q_INVOKABLE void parse(const QStringList &args);
    QString wsUrl() const { return m_wsUrl; }
    QString apiBase() const { return m_apiBase; }
    QString gameId() const { return m_gameId; }
    QString difficulty() const { return m_difficulty; }
    int maxFps() const { return m_maxFps; }
    bool windowed() const { return m_windowed; }
private:
    QString m_wsUrl   = QStringLiteral("ws://localhost:8000/ws");
    QString m_apiBase = QStringLiteral("http://localhost:8000");
    QString m_gameId  = QStringLiteral("qxzn_hmi");
    QString m_difficulty = QStringLiteral("simple");
    int m_maxFps = 60;
    bool m_windowed = false;
};
```

- [ ] **Step 5: Write `src/config.cpp`**

```cpp
#include "config.h"

Config::Config(QObject *parent) : QObject(parent) {}

void Config::parse(const QStringList &args) {
    for (int i = 0; i < args.size(); ++i) {
        const QString &a = args.at(i);
        auto next = [&]() -> QString { return (i + 1 < args.size()) ? args.at(++i) : QString(); };
        if (a == QStringLiteral("--ws-url")) m_wsUrl = next();
        else if (a == QStringLiteral("--api-base")) m_apiBase = next();
        else if (a == QStringLiteral("--game-id")) m_gameId = next();
        else if (a == QStringLiteral("--difficulty")) m_difficulty = next();
        else if (a == QStringLiteral("--max-fps")) m_maxFps = next().toInt();
        else if (a == QStringLiteral("--windowed")) m_windowed = true;
        // unknown args ignored
    }
}
```

- [ ] **Step 6: Run tests to verify pass (GREEN)**

```bash
cmake --build build && (cd build && ctest --output-on-failure)
```
Expected: `tst_core` passes (2 slots).

- [ ] **Step 7: Commit**

```bash
git add CMakeLists.txt src/config.h src/config.cpp tests/tst_core.cpp
git commit -m "feat: add Config (CLI parsing) with Qt-Test harness"
```

---

### Task 4: SegmentInput mapping + tests

**Files:**
- Create: `src/segment_input.h`, `src/segment_input.cpp`
- Modify: `CMakeLists.txt` (add segment_input.cpp to qxzn_core), `tests/tst_core.cpp` (add mapping test)

**Interfaces:**
- Produces: `SegmentInput::mapKey(int qtKey) -> QString` (static).

- [ ] **Step 1: Add failing test slots in `tests/tst_core.cpp`** — add include and slots:

```cpp
#include "segment_input.h"
// inside CoreTest private slots:
    void testSegmentMapping() {
        using SI = SegmentInput;
        QCOMPARE(SI::mapKey(Qt::Key_Q), QStringLiteral("head_left"));
        QCOMPARE(SI::mapKey(Qt::Key_W), QStringLiteral("head_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_E), QStringLiteral("head_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_R), QStringLiteral("head_right"));
        QCOMPARE(SI::mapKey(Qt::Key_X), QStringLiteral("chin"));
        QCOMPARE(SI::mapKey(Qt::Key_A), QStringLiteral("waist_left"));
        QCOMPARE(SI::mapKey(Qt::Key_S), QStringLiteral("waist_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_D), QStringLiteral("waist_mid"));
        QCOMPARE(SI::mapKey(Qt::Key_F), QStringLiteral("waist_right"));
        QCOMPARE(SI::mapKey(Qt::Key_Space), QStringLiteral(""));
    }
```

- [ ] **Step 2: Add to `CMakeLists.txt` qxzn_core sources:**

```cmake
add_library(qxzn_core STATIC
    src/config.cpp
    src/segment_input.cpp
)
```

- [ ] **Step 3: Build/test → RED** (`SegmentInput` undefined).

- [ ] **Step 4: Write `src/segment_input.h`**

```cpp
#pragma once
#include <QString>

class SegmentInput {
public:
    // Map a Qt::Key_* to a standard segment name; empty string if unmapped.
    static QString mapKey(int qtKey);
};
```

- [ ] **Step 5: Write `src/segment_input.cpp`**

```cpp
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
```

- [ ] **Step 6: Build/test → GREEN** (`ctest` passes 3 slots).

- [ ] **Step 7: Commit**

```bash
git add CMakeLists.txt src/segment_input.h src/segment_input.cpp tests/tst_core.cpp
git commit -m "feat: add SegmentInput standard key->segment mapping"
```

---

### Task 5: SessionModel + tests

**Files:**
- Create: `src/session_model.h`, `src/session_model.cpp`
- Modify: `CMakeLists.txt` (add session_model.cpp to qxzn_core), `tests/tst_core.cpp` (add accumulation test)

**Interfaces:**
- Consumes: `SegmentInput::mapKey`.
- Produces: `SessionModel` (QObject): `Q_INVOKABLE void onKey(int)`, `void onTick()`; Q_PROPERTY strikes/calories/frequency/duration/lastSegment (with NOTIFY) + power/speed/endurance/battleLevel/score (CONSTANT).

- [ ] **Step 1: Add failing test slots in `tests/tst_core.cpp`:**

```cpp
#include "session_model.h"
// inside CoreTest private slots:
    void testSessionAccumulation() {
        SessionModel s;
        QCOMPARE(s.strikes(), 0);
        s.onKey(Qt::Key_Q);
        s.onKey(Qt::Key_A);
        QCOMPARE(s.strikes(), 2);
        QCOMPARE(s.lastSegment(), QStringLiteral("waist_left"));
        QVERIFY(s.calories() > 0.0);
        QVERIFY(s.frequency() >= 1);
        s.onTick();
        QCOMPARE(s.duration(), 1);
    }
    void testSessionIgnoresUnknownKey() {
        SessionModel s;
        s.onKey(Qt::Key_Space);
        QCOMPARE(s.strikes(), 0);
        QVERIFY(s.lastSegment().isEmpty());
    }
```

- [ ] **Step 2: Add `src/session_model.cpp` to qxzn_core in `CMakeLists.txt`.**

- [ ] **Step 3: Build/test → RED.**

- [ ] **Step 4: Write `src/session_model.h`**

```cpp
#pragma once
#include <QObject>
#include <QString>
#include <QList>
#include <qglobal.h>

class SessionModel : public QObject {
    Q_OBJECT
    Q_PROPERTY(int strikes READ strikes NOTIFY strikesChanged)
    Q_PROPERTY(double calories READ calories NOTIFY caloriesChanged)
    Q_PROPERTY(int frequency READ frequency NOTIFY frequencyChanged)
    Q_PROPERTY(int duration READ duration NOTIFY durationChanged)
    Q_PROPERTY(QString lastSegment READ lastSegment NOTIFY lastSegmentChanged)
    Q_PROPERTY(int power READ power CONSTANT)
    Q_PROPERTY(int speed READ speed CONSTANT)
    Q_PROPERTY(int endurance READ endurance CONSTANT)
    Q_PROPERTY(int battleLevel READ battleLevel CONSTANT)
    Q_PROPERTY(int score READ score CONSTANT)
public:
    explicit SessionModel(QObject *parent = nullptr);
    Q_INVOKABLE void onKey(int qtKey);
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
    void strikesChanged();
    void caloriesChanged();
    void frequencyChanged();
    void durationChanged();
    void lastSegmentChanged();
private:
    int m_strikes = 0;
    double m_calories = 0.0;
    int m_frequency = 0;
    int m_duration = 0;
    QString m_lastSegment;
    QList<qint64> m_hitTimes; // epoch ms of recent hits (sliding 60s window)
    // static seed values
    int m_power = 72, m_speed = 68, m_endurance = 75, m_battleLevel = 3, m_score = 1280;
};
```

- [ ] **Step 5: Write `src/session_model.cpp`**

```cpp
#include "session_model.h"
#include "segment_input.h"
#include <QDateTime>

SessionModel::SessionModel(QObject *parent) : QObject(parent) {}

void SessionModel::onKey(int qtKey) {
    const QString seg = SegmentInput::mapKey(qtKey);
    if (seg.isEmpty())
        return;
    m_strikes += 1;
    m_calories += 0.8;
    m_lastSegment = seg;
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
```

- [ ] **Step 6: Build/test → GREEN** (`ctest` passes 5 slots).

- [ ] **Step 7: Commit**

```bash
git add CMakeLists.txt src/session_model.h src/session_model.cpp tests/tst_core.cpp
git commit -m "feat: add SessionModel (segment-driven live stats)"
```

---

### Task 6: Wire model + input loop into the app

**Files:**
- Modify: `src/main.cpp` (instantiate Config/SessionModel, duration QTimer, context properties, kiosk, `--quit-after-ms`), `qml/main.qml` (key sink → `session.onKey`)

**Interfaces:**
- Consumes: `Config`, `SessionModel`.

- [ ] **Step 1: Rewrite `src/main.cpp`**

```cpp
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QFontDatabase>
#include <QQuickWindow>
#include <QTimer>
#include "config.h"
#include "session_model.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    QFontDatabase::addApplicationFont(QStringLiteral(":/resources/fonts/AlimamaShuHeiTi-Bold.ttf"));

    Config config;
    config.parse(QGuiApplication::arguments().mid(1));

    SessionModel session;
    QTimer durationTimer;
    durationTimer.setInterval(1000);
    QObject::connect(&durationTimer, &QTimer::timeout, &session, &SessionModel::onTick);
    durationTimer.start();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("session"), &session);
    engine.rootContext()->setContextProperty(QStringLiteral("config"), &config);
    engine.load(QUrl(QStringLiteral("qrc:/qml/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

    QObject *root = engine.rootObjects().first();
    auto *window = qobject_cast<QQuickWindow *>(root);
    if (window) {
        if (config.windowed())
            window->show();
        else
            window->showFullScreen();
    }

    // smoke-test hook: quit after N ms if requested
    const auto args = QGuiApplication::arguments().mid(1);
    for (int i = 0; i + 1 < args.size(); ++i) {
        if (args.at(i) == QStringLiteral("--quit-after-ms")) {
            QTimer::singleShot(args.at(i + 1).toInt(), &app, &QGuiApplication::quit);
        }
    }
    return app.exec();
}
```

- [ ] **Step 2: Add a key sink to `qml/main.qml`** — add inside `ApplicationWindow` (before any visible children that need focus is fine; force focus on the sink):

```qml
    Item {
        id: keySink
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) { session.onKey(event.key) }
    }
    Component.onCompleted: keySink.forceActiveFocus()
```
(Remove the placeholder `Label` from Task 2 — the Dashboard comes in Task 8.)

- [ ] **Step 3: Build & verify (offscreen smoke now clean)**

```bash
cmake --build build
./build/qxzn_hmi -platform offscreen --quit-after-ms 800; echo "exit=$?"
```
Expected: exits 0 after ~0.8s (no crash). Run unit tests too: `(cd build && ctest --output-on-failure)` → 5 slots pass.

- [ ] **Step 4: Commit**

```bash
git add src/main.cpp qml/main.qml
git commit -m "feat: wire SessionModel + segment key input into the app"
```

---

### Task 7: TopBar component (brand, nav, live clock, exit)

**Files:**
- Create: `qml/TopBar.qml`
- Modify: `CMakeLists.txt` (add `qml/TopBar.qml` to resources), `qml/main.qml` (place TopBar)

- [ ] **Step 1: Write `qml/TopBar.qml`**

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: bar
    color: "#16191f"
    property int activeNav: 0

    // Left cluster (Row lays children left-to-right; the Row itself is vertically centered
    // on the bar — do NOT put anchors.verticalCenter on children inside a Row, Row ignores it).
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 24

        Rectangle { width: 48; height: 48; radius: 24; color: "#2a2f38"
            Label { anchors.centerIn: parent; text: "👤"; font.pixelSize: 24 } }
        Column { spacing: 2
            Label { text: "QXZN 运行时"; color: "#e6e8eb"; font.pixelSize: 20; font.bold: true }
            Label { text: "15.6″ HMI"; color: "#8a9099"; font.pixelSize: 12 } }

        Repeater {
            model: ["首页", "课程", "健身", "设置"]
            delegate: Rectangle {
                width: navLabel.implicitWidth + 24; height: 40; radius: 8
                color: bar.activeNav === index ? "#243040" : "transparent"
                Label { id: navLabel; anchors.centerIn: parent; text: modelData; color: bar.activeNav === index ? "#3fd0c9" : "#aab2bd"; font.pixelSize: 16 }
                TapHandler { onTapped: bar.activeNav = index }
            }
        }
    }

    // Right cluster: wifi, battery, clock, exit.
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 20
        Label { text: "📶"; font.pixelSize: 18 }
        Label { text: "🔋 87%"; color: "#aab2bd"; font.pixelSize: 14 }
        Label { id: clock; text: "--:--:--"; color: "#e6e8eb"; font.pixelSize: 18; font.bold: true }
        Rectangle { width: 40; height: 40; radius: 8; color: "#2a2f38"
            Label { anchors.centerIn: parent; text: "✕"; color: "#e6e8eb"; font.pixelSize: 16 }
            TapHandler { onTapped: Qt.quit() } }
    }

    Timer { interval: 1000; running: true; repeat: true;
        onTriggered: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss") }
    Component.onCompleted: clock.text = Qt.formatDateTime(new Date(), "HH:mm:ss")
}
```

- [ ] **Step 2: Add `qml/TopBar.qml` to the resources block in `CMakeLists.txt`** (after `qml/main.qml`).

- [ ] **Step 3: Place TopBar in `qml/main.qml`** — add inside `ApplicationWindow`:

```qml
    TopBar {
        id: topBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 96
    }
```

- [ ] **Step 4: Build & verify**

```bash
cmake --build build && ./build/qxzn_hmi -platform offscreen --quit-after-ms 800; echo "exit=$?"
```
Expected: exits 0, no QML errors on stderr.

- [ ] **Step 5: Commit**

```bash
git add CMakeLists.txt qml/TopBar.qml qml/main.qml
git commit -m "feat: add TopBar (brand, nav, live clock, exit)"
```

---

### Task 8: Dashboard + reusable pills/panels + page loader

**Files:**
- Create: `qml/MetricPill.qml`, `qml/StatPanel.qml`, `qml/Dashboard.qml`, `qml/PlaceholderPage.qml`
- Modify: `CMakeLists.txt` (add the 4 QML files), `qml/main.qml` (Loader below TopBar bound to `topBar.activeNav`)

- [ ] **Step 1: Write `qml/MetricPill.qml`**

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    property string icon: ""
    property string caption: ""
    property string value: ""
    width: 150; height: 96; radius: 12; color: "#1b2027"
    Column {
        anchors.centerIn: parent; spacing: 4
        Label { text: parent.parent.icon; font.pixelSize: 20; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: value; color: "#3fd0c9"; font.pixelSize: 24; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: caption; color: "#8a9099"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
```
Note: the inner Column references the pill's properties via the pill id — add `id: pill` to the Rectangle and bind to `pill.icon`/`pill.value`/`pill.caption`. (Use the corrected form below.)

Corrected `qml/MetricPill.qml`:

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: pill
    property string icon: ""
    property string caption: ""
    property string value: ""
    width: 150; height: 96; radius: 12; color: "#1b2027"
    Column {
        anchors.centerIn: parent; spacing: 4
        Label { text: pill.icon; font.pixelSize: 20; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: pill.value; color: "#3fd0c9"; font.pixelSize: 24; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        Label { text: pill.caption; color: "#8a9099"; font.pixelSize: 12; anchors.horizontalCenter: parent.horizontalCenter }
    }
}
```

- [ ] **Step 2: Write `qml/StatPanel.qml`**

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: panel
    property string title: ""
    property string value: ""
    property string caption: ""
    width: 220; height: 130; radius: 14; color: "#1b2027"
    Column {
        anchors.centerIn: parent; spacing: 6
        Label { text: panel.title; color: "#8a9099"; font.pixelSize: 14 }
        Label { text: panel.value; color: "#e6e8eb"; font.pixelSize: 40; font.bold: true }
        Label { text: panel.caption; color: "#5b626b"; font.pixelSize: 12 }
    }
}
```

- [ ] **Step 3: Write `qml/Dashboard.qml`**

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    color: "#0f1115"
    anchors.fill: parent

    Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        // Summary
        Rectangle { width: parent.width; height: 90; radius: 14; color: "#16191f"
            Column { anchors.centerIn: parent; spacing: 4
                Label { text: "对战等级 L" + config.battleLevel + "   分数 " + config.score; color: "#e6e8eb"; font.pixelSize: 22; font.bold: true }
                Label { text: "Game: " + config.gameId + "  ·  难度: " + config.difficulty; color: "#8a9099"; font.pixelSize: 13 } } }
        // BUG: config.battleLevel/score don't exist on Config — those are SessionModel props. Fix below.
    }
}
```
Correction: `battleLevel` and `score` are `SessionModel` (session) properties, not `config`. Use `session`. Final `Dashboard.qml`:

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    color: "#0f1115"

    Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 24

        Rectangle { // Summary
            width: parent.width; height: 90; radius: 14; color: "#16191f"
            Column { anchors.centerIn: parent; spacing: 4
                Label { text: "对战等级 L" + session.battleLevel + "   分数 " + session.score
                        color: "#e6e8eb"; font.pixelSize: 22; font.bold: true }
                Label { text: "Game: " + config.gameId + "  ·  难度: " + config.difficulty
                        color: "#8a9099"; font.pixelSize: 13 } } }

        Row { // three stat panels (static seed)
            spacing: 24
            StatPanel { title: "力量"; value: session.power; caption: "Power" }
            StatPanel { title: "速度"; value: session.speed; caption: "Speed" }
            StatPanel { title: "耐力"; value: session.endurance; caption: "Endurance" }
        }

        Row { // five metric pills (input-driven + duration)
            spacing: 16
            MetricPill { icon: "💥"; caption: "Impact"; value: session.strikes }
            MetricPill { icon: "⏱"; caption: "Duration"; value: session.duration + "s" }
            MetricPill { icon: "🔥"; caption: "Calories"; value: Math.round(session.calories) }
            MetricPill { icon: "👊"; caption: "Strikes"; value: session.strikes }
            MetricPill { icon: "⚡"; caption: "Freq/min"; value: session.frequency }
        }

        Rectangle { // Schedule (static)
            width: parent.width; height: 120; radius: 14; color: "#16191f"
            Column { anchors.centerIn: parent; spacing: 4
                Label { text: "今日课程"; color: "#e6e8eb"; font.pixelSize: 18; font.bold: true }
                Label { text: "19:00  Boxing Basic  ·  20:00  HIIT"; color: "#8a9099"; font.pixelSize: 13 } } }

        Label { text: "最近击打: " + (session.lastSegment || "—"); color: "#5b626b"; font.pixelSize: 14 }
    }
}
```

- [ ] **Step 4: Write `qml/PlaceholderPage.qml`**

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    color: "#0f1115"
    Label { anchors.centerIn: parent; text: "未移植\n(本切片只做首页仪表盘)"; color: "#5b626b"; font.pixelSize: 24; horizontalAlignment: Text.AlignHCenter }
}
```

- [ ] **Step 5: Add the 4 QML files to `CMakeLists.txt` resources block** (after `qml/TopBar.qml`).

- [ ] **Step 6: Add page Loader to `qml/main.qml`** — add inside `ApplicationWindow`, below the TopBar block:

```qml
    Loader {
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        sourceComponent: topBar.activeNav === 0 ? dashboardComponent : placeholderComponent
    }
    Component { id: dashboardComponent; Dashboard {} }
    Component { id: placeholderComponent; PlaceholderPage {} }
```

- [ ] **Step 7: Build & verify (offscreen + unit)**

```bash
cmake --build build && ./build/qxzn_hmi -platform offscreen --quit-after-ms 800; echo "exit=$?"
(cd build && ctest --output-on-failure)
```
Expected: exits 0, no QML errors; 5 unit slots pass.

- [ ] **Step 8: Commit**

```bash
git add CMakeLists.txt qml/MetricPill.qml qml/StatPanel.qml qml/Dashboard.qml qml/PlaceholderPage.qml qml/main.qml
git commit -m "feat: add Dashboard (summary, stats, live metric pills, schedule) + page loader"
```

---

### Task 9: kiosk fullscreen, Esc quit, windowed fallback

**Files:**
- Modify: `qml/main.qml` (Esc shortcut), `src/main.cpp` (already does fullscreen/windowed from Task 6 — verify)

- [ ] **Step 1: Add Esc shortcut to `qml/main.qml`** — inside `ApplicationWindow`:

```qml
    Shortcut { sequence: "Esc"; onActivated: Qt.quit() }
```

- [ ] **Step 2: Verify windowed flag works**

```bash
cmake --build build
./build/qxzn_hmi -platform offscreen --windowed --quit-after-ms 500; echo "exit=$?"
```
Expected: exits 0 (windowed path used; no crash). Fullscreen is the default and is exercised in real runs.

- [ ] **Step 3: Commit**

```bash
git add qml/main.qml
git commit -m "feat: kiosk fullscreen with --windowed fallback and Esc quit"
```

---

### Task 10: offscreen smoke script + README + LICENSE

**Files:**
- Create: `tests/smoke.sh`, `README.md`, `README.zh-CN.md`, `LICENSE`

- [ ] **Step 1: Write `tests/smoke.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BIN="${1:-build/qxzn_hmi}"
[ -x "$BIN" ] || { echo "missing binary: $BIN" >&2; exit 1; }
"$BIN" -platform offscreen --windowed --quit-after-ms 800
echo "smoke: exited cleanly"
```

- [ ] **Step 2: Write `README.md`**

````markdown
# qxzn-hmi-qt

A Qt Quick port of the QXZN 15.6″ car-HMI shell (originally a Godot project at `../15-6inch-game-runtime-qxzn`). Dark dashboard with a TopBar and a live fitness dashboard driven by standard "segment" keyboard input.

This project exists to **dogfood [`qtcli`](../tools/qtcli)** — a real Qt project to drive its inspection commands and surface gaps.

## Build & run

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/Qt/6.11.1/gcc_64
cmake --build build
./build/qxzn_hmi                      # fullscreen kiosk
./build/qxzn_hmi --windowed           # windowed
./build/qxzn_hmi -platform offscreen --windowed --quit-after-ms 800   # headless smoke
```

## Segment input (keyboard)

| Segment | Key | | Segment | Key |
|---|---|---|---|---|
| head_left | Q | | chin | X |
| head_mid | W / E | | waist_left | A |
| head_right | R | | waist_mid | S / D |
| | | | waist_right | F |

Hits update Strikes / Calories / Frequency; Duration ticks each second.

## CLI flags

`--ws-url`, `--api-base`, `--game-id`, `--difficulty simple|hard`, `--max-fps`, `--windowed`, `--quit-after-ms`. Networking/hardware are stubbed in this slice.

## Test

```bash
(cd build && ctest --output-on-failure)   # C++ unit tests
bash tests/smoke.sh                         # offscreen smoke
```

## License

MIT.
````

- [ ] **Step 3: Write `README.zh-CN.md`** (Chinese mirror of the above — same sections: 构建/运行、segment 输入表、CLI、测试、许可证 MIT).

- [ ] **Step 4: Write `LICENSE`** — standard MIT, `Copyright (c) 2026 qxzn-hmi-qt contributors`.

- [ ] **Step 5: Make smoke executable, run full verification**

```bash
chmod +x tests/smoke.sh
cmake --build build && (cd build && ctest --output-on-failure) && bash tests/smoke.sh
```
Expected: unit tests pass; smoke prints "smoke: exited cleanly".

- [ ] **Step 6: Commit**

```bash
git add tests/smoke.sh README.md README.zh-CN.md LICENSE
git commit -m "docs: add README, LICENSE, and offscreen smoke script"
```

---

### Task 11: qtcli dogfooding checkpoint + backlog

**Files:**
- Create: `docs/dogfood/BACKLOG.md`

- [ ] **Step 1: Run qtcli against this project**

```bash
cd /home/x/code/pd02/tools/qtcli   # or use the installed qtcli
cargo run --release --quiet -- --project /home/x/code/pd02/qxzn-hmi-qt --json doctor
cargo run --release --quiet -- --project /home/x/code/pd02/qxzn-hmi-qt --json info
cargo run --release --quiet -- --project /home/x/code/pd02/qxzn-hmi-qt --qmake qmake6 --json modules
```

- [ ] **Step 2: Record findings in `docs/dogfood/BACKLOG.md`** — write what qtcli reported correctly AND the gaps it could not cover (e.g., it does not list `.qml` files, does not show the QML/CMake structure, cannot lint QML). Capture exact command output summaries. Each gap = one backlog item with a concrete enhancement idea.

- [ ] **Step 3: Commit**

```bash
cd /home/x/code/pd02/qxzn-hmi-qt
git add docs/dogfood/BACKLOG.md
git commit -m "docs: record qtcli dogfooding findings and enhancement backlog"
```

---

## Self-Review

**1. Spec coverage:** §2.1 kiosk (T1/T9), dark+font (T2), TopBar (T7), Dashboard+pills+panels+summary+schedule (T8), segment input (T4/T6), live input-driven metrics (T5/T6/T8), CLI config + stub (T3/T6), Esc/exit (T7/T9) → all covered. §2.2 placeholders (T8 PlaceholderPage + Loader). §8 dogfooding (T11). §10 tests (T3–T5 unit, T10 smoke). §9 structure matches file table.

**2. Placeholder scan:** No TBD/TODO. (Task 8 deliberately shows a buggy draft then the corrected Dashboard.qml — the corrected version is the one to write; the draft is annotated "Correction:" to teach the implementer the SessionModel-vs-Config distinction. Implementer writes the corrected version.)

**3. Type consistency:** `SessionModel` properties (strikes/calories/frequency/duration/lastSegment/power/speed/endurance/battleLevel/score) match across header (T5), test (T5), and Dashboard.qml bindings (T8). `Config` properties (gameId/difficulty/wsUrl/apiBase/maxFps/windowed) match header (T3), test (T3), main.cpp (T6), and QML (T8). `SegmentInput::mapKey(int)->QString` consistent (T4/T5). `onKey(int)` / `onTick()` consistent (T5/T6). Resource paths `qrc:/qml/*.qml` and `:/resources/fonts/...` consistent (T2/T6).

---

## Execution Handoff

Plan complete and saved to `qxzn-hmi-qt/docs/superpowers/plans/2026-07-15-qxzn-hmi-shell.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.

**2. Inline Execution** — batch execution with checkpoints.

Which approach?
