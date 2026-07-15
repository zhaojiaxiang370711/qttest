# qtcli Dogfooding Backlog — qxzn-hmi-qt

**Date:** 2026-07-15
**qtcli binary:** `/home/x/code/pd02/tools/qtcli/target/release/qtcli`
**Project:** `/home/x/code/pd02/qxzn-hmi-qt` (Qt 6.11.1 Quick app, cmake build)

---

## 1. What qtcli Got Right

### 1.1 `doctor` — Environment Check

```
qtcli --project /home/x/code/pd02/qxzn-hmi-qt --json doctor
```

**Result:** `ok: true` — all checks passed.

| Check | Status |
|-------|--------|
| qmake6 | ok — found on PATH |
| cmake | ok — found on PATH |
| compiler (c++) | ok — found on PATH |
| Project directory | ok |
| Qt project marker | ok — found `CMakeLists.txt` with `find_package Qt` |

Qt version query returned `QT_VERSION:6.11.1` and `QT_INSTALL_PREFIX:/opt/Qt/6.11.1/gcc_64`.

**Verdict:** Correctly detects toolchain, Qt prefix/version, and cmake project marker. This is the most useful command for onboarding — "will this project even build here?"

### 1.2 `info` — Project Summary

```
qtcli --project /home/x/code/pd02/qxzn-hmi-qt --json info
```

**Result:**

```json
{
  "build_system": "cmake",
  "marker_file": "CMakeLists.txt",
  "modules": ["Core", "Gui", "Qml", "Quick", "QuickControls2", "Test"],
  "qt_version": "6",
  "targets": ["qxzn_hmi", "tst_core"]
}
```

**Verdict:** Correctly identifies build system, all 6 referenced Qt modules, qt_version major, and both cmake targets (app + test). The module list matches the `find_package(Qt6 ... COMPONENTS ...)` line exactly.

### 1.3 `modules` — Installed vs. Referenced

```
qtcli --project /home/x/code/pd02/qxzn-hmi-qt --qmake qmake6 --json modules
```

**Result:**

- **Qt version:** 6.11.1, prefix `/opt/Qt/6.11.1/gcc_64`
- **Referenced:** Core, Gui, Qml, Quick, QuickControls2, Test
- **Installed:** 80+ modules (Charts, Concurrent, DBus, Designer, Multimedia, Network, OpenGL, Quick3D, ShaderTools, Sql, Svg, WebSockets, Widgets, Xml, ...)
- **Missing:** `[]` — no missing modules

**Verdict:** Correctly cross-references what the project needs against what is installed. The "missing: []" output is the key value — it tells you the project is complete from a dependency standpoint.

### 1.4 `find-projects` — Project Discovery

```
qtcli --project /home/x/code/pd02 --json find-projects /home/x/code/pd02 --recursive
```

**Result:** Correctly located `/home/x/code/pd02/qxzn-hmi-qt` (build_system: cmake, marker: CMakeLists.txt) among hundreds of Qt source tree projects. The command also discovered all the Qt source examples and test projects under the Qt source tree — useful for finding all Qt projects in a workspace.

### 1.5 `capabilities` — Command Introspection

```json
{
  "commands": [
    {"name": "info", "category": "inspect", "json": true},
    {"name": "find-projects", "category": "inspect", "json": true},
    {"name": "modules", "category": "inspect", "json": true},
    {"name": "doctor", "category": "verify", "json": true},
    {"name": "capabilities", "category": "meta", "json": true}
  ]
}
```

**Verdict:** Clean, machine-readable capability listing. All commands support `--json`.

---

## 2. GAPS — Enhancement Backlog

Each gap is a concrete enhancement qtcli could add, ranked by dogfooding value.

### GAP-1: No QML File Enumeration ✅ CLOSED

> **Status (2026-07-15): CLOSED** — implemented as the `qtcli qml-files` command (qtcli `master` commit `a07cd58`). Verified on this project: `count: 6, total_lines: 173`.

**Problem:** qtcli has no command to list `.qml` files in a project. `info` returns modules and targets, but not the QML source tree.

**Current workaround:** Manual `find . -name "*.qml"` returns:
```
qml/Dashboard.qml
qml/main.qml
qml/MetricPill.qml
qml/PlaceholderPage.qml
qml/StatPanel.qml
qml/TopBar.qml
```

**Enhancement:** Add a `qml-files` command (or extend `info`) that:
- Enumerates all `.qml` files under the project
- Shows the resource prefix mapping (`qrc:/qml/...`)
- Reports file count and total line count
- Optionally shows `import` statements per file

**Impact:** High — QML files are the primary source for a Qt Quick app. Without this, qtcli has no visibility into the actual UI layer.

### GAP-2: No QML Module / `qt_add_qml_module` Awareness ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `qtcli info` now reports `qt_add_resources` / `qt_add_qml_module` bundles (qtcli `master` commit `148fc10`). Verified on this project: `bundles: 1 / qt_add_resources appqml prefix=/ files=7`.

**Problem:** `info` reports `find_package` modules but does not detect `qt_add_qml_module()` calls. This project uses `qt_add_resources()` (not `qt_add_qml_module`), but newer Qt 6 projects use `qt_add_qml_module` to declare QML modules with URI, version, and type registration.

**Enhancement:** Extend `info` to:
- Parse `qt_add_qml_module()` calls and report URI, version, QML files registered
- Parse `qt_add_resources()` calls and report prefix + files
- Show the resource structure (prefix, file list, font/asset files)

**Impact:** Medium-high — this is the core of how Qt Quick apps bundle their UI. Without it, qtcli cannot tell you "this project has a QML module `qxzn.hmi` with 6 files and 1 font."

### GAP-3: No QML Lint / Format Integration ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `qtcli lint` (qmllint) + `qtcli format` (qmlformat --check) commands shipped (qtcli `master` `aa25989`). On this project: lint `6 files, 3 with diagnostics`; format `6 files, 6 need formatting`.

**Problem:** qtcli has no `lint` or `format` command. Qt ships `qmllint` and `qmlformat` at `/opt/Qt/6.11.1/gcc_64/bin/`, but qtcli does not invoke or wrap them.

**Current state:** `qmllint` and `qmlformat` exist in the Qt installation but are not on PATH and not integrated into qtcli.

**Enhancement:** Add:
- `qtcli lint [--fix]` — runs `qmllint` on all `.qml` files, reports diagnostics
- `qtcli format [--check]` — runs `qmlformat` on all `.qml` files, reports diffs
- Both should discover qmllint/qmlformat from the Qt prefix reported by `doctor`

**Impact:** Medium — QML linting catches real bugs (undefined properties, missing imports). Without this, developers must manually invoke the tools.

### GAP-4: No Project Structure Overview ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `qtcli structure` shipped (qtcli `master` `da5560e`): file/line inventory by extension + per-directory. On this project: 25 files / 5978 lines (qml 6, cpp 5, md 5, h 3, ttf 1…). Dogfooding also surfaced + fixed two bugs: binary `.ttf` crashed line counting (now byte-based) and `.superpowers` scratch polluted the inventory (now skipped).

**Problem:** qtcli can report modules and targets, but has no command to show the project's source layout — directory tree, file counts by type (.cpp, .h, .qml, .qrc), or dependency graph.

**Enhancement:** Add a `structure` command that:
- Shows directory tree (C++ sources, QML sources, tests, resources)
- Reports file counts: N .cpp, N .h, N .qml, N .qrc
- Shows cmake target dependencies (qxzn_core -> qxzn_hmi, tst_core -> qxzn_core)

**Impact:** Medium — useful for onboarding and code review. The current `info` output is minimal.

### GAP-5: No Build / Run Integration ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `qtcli build` / `test` / `run` shipped (qtcli `master` `662a98b`): auto-configure (`cmake -B build -DCMAKE_PREFIX_PATH=<qmake prefix>`), text inherits stdio, JSON captures. Verified on this project: build ok; `test` runs `tst_core` (pass); `run` launches `qxzn_hmi` offscreen (exit 0). Side-enabler: `read_project_info` now detects non-Qt CMake projects too.

**Problem:** qtcli is inspect-only. It cannot configure, build, or run the project. For a "project helper," the gap between "check if it can build" and "actually build it" is significant.

**Enhancement:** Add:
- `qtcli build [--target NAME]` — runs cmake configure + build
- `qtcli run [--target NAME]` — builds and runs the executable
- `qtcli test` — runs ctest

**Impact:** Medium — would make qtcli a true project lifecycle tool, not just an inspector.

### GAP-6: No C++ Source Awareness ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `qtcli cpp-files` shipped (qtcli `master` `8797a36`): lists `.cpp/.h` with line counts + aggregates `#include <Q…>` Qt headers. On this project: 8 C++ files / 258 lines; headers QString(3), QObject(2), QQmlApplicationEngine, QQuickWindow, QFontDatabase, QtTest/QtTest, etc. (Class-hierarchy / signal-slot parsing still deferred — needs a C++ parser.)

**Problem:** qtcli does not parse or report on C++ source files.

**Enhancement:** Add:
- `qtcli sources` — lists .cpp/.h files with line counts
- Optionally: `qtcli includes` — shows which Qt headers are actually used vs. what `find_package` declares

**Impact:** Low-medium — C++ awareness is less critical for a QML-first project, but useful for validating module claims.

### GAP-7: `find-projects` Returns Too Much Noise ✅ CLOSED

> **Status (2026-07-15): CLOSED** — `find-projects --recursive` now skips the Qt source checkout (`qt-everywhere-src*`) + `.superpowers` and bounds recursion with `--max-depth` (default 5). On pd02: **3584 → 3** real projects (qxzn-hmi-qt, dds-fastdds-core, motor_dds_bridge).

**Problem:** Running `find-projects` on `/home/x/code/pd02` with `--recursive` returned hundreds of projects from the Qt source tree

**Enhancement:** Add filtering options:
- `--exclude-pattern` to skip known source trees
- `--max-depth` to limit recursion
- Default exclude for common patterns like `qt-everywhere-src-*`
- Summary output: "Found N projects (N user, N system)"

**Impact:** Low — the command works, but the UX degrades in large workspaces.

### GAP-8: No Version / Compatibility Matrix

**Problem:** `doctor` reports Qt 6.11.1 is installed, and `info` reports qt_version "6", but there is no check for version compatibility. If the project requires Qt 6.11 but only 6.5 is installed, qtcli would not flag this.

**Enhancement:** Extend `doctor` or `info` to:
- Parse `find_package(Qt6 6.11 REQUIRED ...)` and compare against installed version
- Warn if installed Qt is older than required minimum
- Report compatibility matrix: required vs. installed per module

**Impact:** Low-medium — the current "missing: []" check catches absent modules, but not version mismatches.

---

## 3. Summary

| Area | Status |
|------|--------|
| Toolchain detection (doctor) | Correct |
| Project metadata (info) | Correct |
| Module cross-reference (modules) | Correct |
| Project discovery (find-projects) | Correct (but noisy) |
| QML awareness | Missing — 8 gaps recorded |

**qtcli v0.1 handles the C++/cmake inspection layer well.** It correctly identifies the project, its modules, targets, and toolchain. The dogfooding value is in the 8 gaps above — all centered on the QML layer that is the primary source for a Qt Quick application.
