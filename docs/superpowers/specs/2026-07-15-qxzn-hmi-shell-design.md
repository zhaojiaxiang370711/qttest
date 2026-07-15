# qxzn-hmi-qt — HMI 外壳移植设计(spec)

- 日期:2026-07-15
- 状态:已批准(设计评审通过),待实现规划
- 来源:Godot 工程 `/home/x/code/pd02/15-6inch-game-runtime-qxzn`(车载健身 HMI kiosk 运行时)
- 关联:`qtcli`(`/home/x/code/pd02/tools/qtcli`)—— 本工程全程用它 dogfood

## 1. 目标与背景

把 Godot 车载 HMI **外壳**移植成**可独立运行、可交互**的 Qt Quick 应用。移植是**手段**:用一个真实、有规模的 Qt 工程驱动 qtcli,暴露它的短板并持续增强。不是把整个产品(8 游戏 + 课程 + 原生桥接)全量重写。

原 Godot 外壳结构(实测):`Main.tscn` = `Control` 根 → `ShellLayout` → `HomePageView`(健身仪表盘)+ `TopBarView`(顶栏),脚本 `shell_controller.gd`。HomePage 是**仪表盘**(对战等级/分数、Power/Speed/Endurance、Impact/Duration/Calories/Strikes/Frequency 指标 pill、Schedule)。TopBar = 头像 + 品牌 + 4 项导航 + wifi/电量/时钟 + 退出。

## 2. 范围

### 2.1 本切片包含(In)

- **kiosk 窗口**:全屏 1920×1080;命令行/环境无显示器时退化为窗口化。深色主题。字体 AlimamaShuHeiTi(从 Godot 工程复用 `AlimamaShuHeiTi-Bold.ttf`)。
- **TopBar 组件**:头像位 + 品牌标题/副标题 + 4 项顶栏导航(Nav0–Nav3,可切换高亮)+ wifi 图标 + 电量图标 + **实时时钟(每秒刷新)** + 退出按钮。
- **Dashboard 仪表盘组件**:
  - Summary:对战等级(BattleLevel)+ 分数(Score)。
  - 三项 StatPanel:Power / Speed / Endurance(数值 + caption)。
  - 五个 MetricPill(可复用组件):Impact / Duration / Calories / Strikes / Frequency(图标 + 数值 + caption)。
  - Schedule 面板(静态样例内容)。
- **标准 segment 输入映射**(键盘 → 7 segment,见 §5):击打实时累加 **Strikes**、推算 **Frequency**(近窗击打/分钟)、累加 **Calories**(每次固定系数);**Duration** 会话计时跑动;最近 segment 显示用于视觉反馈。仪表盘数值由真实输入驱动,QML 属性绑定实时刷新。
- **CLI 配置**(对齐 Godot):`--ws-url`、`--api-base`、`--game-id`、`difficulty=simple|hard`、`--max-fps`;解析并保存于 `Config`,暴露给 QML 显示。WS/API/LED/电机/视频全部 **stub(仅 log)**。
- 退出:`Esc` 或退出按钮 → 干净退出。

### 2.2 本切片不做(Out)

- 8 个游戏、课程页、媒体播放的**实际逻辑**(TopBar 导航项保留为占位:点击非首页项显示「未移植」占位页)。
- 真实 WS/API/LED/电机/视频/GStreamer —— 全部 stub。
- 像素级复刻 Godot 观感;用 Qt Quick Controls 2 惯用风格**逼近**深色仪表盘。
- 实时电量/wifi 状态(用静态图标占位;时钟为唯一实时状态)。

## 3. 架构

- **QML(UI 外壳)+ C++(输入/配置/会话模型)**,CMake + Qt 6.11,用 `qt_add_qml_module` 注册 QML。
- 预计引用 Qt 模块:`Core`、`Gui`、`Quick`、`QuickControls2`、`Qml`(运行 `qtcli modules` 比对验证)。
- C++ 后端(注册为 QML 单例或 context 属性):
  - `Config`:解析 CLI/默认值,持有 ws-url/api-base/game-id/difficulty/max-fps;`Q_PROPERTY` 暴露给 QML。
  - `SegmentInput`:键盘事件 → segment 名(映射见 §5);`Q_INVOKABLE`/信号把 segment 发给 `SessionModel`。
  - `SessionModel`:持有可被 QML 绑定的会话属性(strikes/calories/frequency/duration/power/speed/endurance/battleLevel/score/lastSegment);击打与定时器驱动更新;`Q_OBJECT` + `Q_PROPERTY` + `Q_SIGNAL`。
- QML 组件:
  - `main.qml`:`ApplicationWindow`(kiosk/全屏)+ 装载 `TopBar` + `Dashboard`;捕获键盘 → `SegmentInput`。
  - `TopBar.qml`:顶栏全部元素 + `Timer` 驱动时钟。
  - `Dashboard.qml`:Summary + 3×StatPanel + 5×MetricPill + Schedule。
  - `MetricPill.qml`:可复用指标 pill(icon/caption/value)。
  - `StatPanel.qml`:可复用三项面板。
  - `PlaceholderPage.qml`:「未移植」占位。

## 4. 数据流(交互闭环)

```
键盘(Q/W/E/R/X/A/S/D/F)
  → main.qml Keys.onPressed
  → SegmentInput.mapKey(...) -> segment 字符串
  → SessionModel.onSegment(segment)
  → 更新 strikes(+1) / calories(+系数) / frequency(滑窗) / lastSegment
  → (独立 Timer) duration 每秒 +1
  → Q_PROPERTY NOTIFY → QML 绑定自动刷新仪表盘
```
这条闭环让仪表盘「活」起来,是 dogfooding 的真实驱动场景。

**输入驱动 vs 静态样例(明确):** 本切片中 `strikes` / `calories` / `frequency` / `duration` / `lastSegment` 由 segment 输入与会话计时**实时驱动**;`Power` / `Speed` / `Endurance` / `BattleLevel` / `Score` 用**静态样例值**(seed),不随输入变化(真实算法留给后续阶段)。

## 5. 标准 Segment 输入映射(对齐 Godot README)

| Segment | 中文 | 键 |
|---|---|---|
| `head_left` | 左头 | Q |
| `head_mid` | 中头 | W / E |
| `head_right` | 右头 | R |
| `chin` | 下巴 | X |
| `waist_left` | 左腰 | A |
| `waist_mid` | 腰中 | S / D |
| `waist_right` | 右腰 | F |

归一:`head_mid` 接收 W 或 E;`waist_mid` 接收 S 或 D。其余键忽略。

## 6. 配置与 stub 策略

- CLI:`--ws-url URL`、`--api-base URL`、`--game-id ID`、`--difficulty simple|hard`、`--max-fps N`;均带默认值;未知参数忽略(不崩)。
- `Config` 暴露给 QML(顶栏/仪表盘可显示 game-id/difficulty)。
- WS/API/LED/电机/视频:本切片**不实现**,仅在启动时 log 一行「stubbed」表明配置已被接收。

## 7. 主题 / 字体 / 资产

- 深色主题:背景近黑(`#0f1115` 量级)、卡片深灰、强调色(品牌色,取近似的青/橙)。具体色值在实现时定,以「逼近原 Godot 深色仪表盘」为准,不要求像素一致。
- 字体:复用 `AlimamaShuHeiTi-Bold.ttf`;通过 Qt 资源(`qrc`)或 `QFontDatabase::addApplicationFont` 加载。
- 图标:用 Qt Quick Controls 2 / 简单 SVG 或 Unicode/emoji 占位;不强制复刻 Godot 的 svg 资产。

## 8. qtcli dogfooding 计划(本工程的核心目的之一)

- 全程用 qtcli 管理/检查本工程:
  - `qtcli doctor --json`:确认 qmake6/cmake/compiler/Qt 版本与前缀。
  - `qtcli info --json`:确认 build_system=cmake、引用模块、target。
  - `qtcli modules --json`:比对引用 vs 已装模块,发现缺失。
  - `qtcli find-projects --recursive`:在 pd02 下定位本工程。
- **预期撞上的 qtcli 短板**(→ 记入增强积压,逐步做):
  - 不识别 `.qml`(info 不报 QML 文件数/结构)。
  - 不能列工程源码文件 / 工程结构概览。
  - 不能 lint / 格式化 QML(`qmlformat`/`qmllint`)。
  - 不展示 CMake 的 `qt_add_qml_module` 等 Qt 专属细节。
  - find-projects 对「纯 QML 工程」(只有 main.qml 没 find_package?)的判定。
- 每撞一个短板 → 在本 spec 末尾或单独 backlog 记录 → 后续迭代增强 qtcli。

## 9. 工程结构(目标)

```
qxzn-hmi-qt/
  CMakeLists.txt          qt_add_qml_module + find_package(Qt6 COMPONENTS ...)
  README.md / README.zh-CN.md
  LICENSE (MIT)
  .gitignore              /build/ *.user *.log .DS_Store
  docs/superpowers/specs/2026-07-15-qxzn-hmi-shell-design.md  (本文件)
  src/
    main.cpp              装 Config/SegmentInput/SessionModel + QQmlApplicationEngine + kiosk
    config.h/.cpp         CLI 解析 + Q_PROPERTY
    segment_input.h/.cpp  键→segment 映射
    session_model.h/.cpp  会话属性 + 击打/计时更新
  qml/
    main.qml, TopBar.qml, Dashboard.qml, MetricPill.qml, StatPanel.qml, PlaceholderPage.qml
  resources/
    fonts/AlimamaShuHeiTi-Bold.ttf   (从 Godot 工程拷入)
    qml.qrc
  tests/                  (按需;优先 QML 单测 + 一个 CLI smoke)
```

## 10. 测试

- **C++ 单测**(可选用 Qt Test 或最小手写):SegmentInput 映射(W/E→head_mid、S/D→waist_mid、未知键忽略)、Config CLI 解析、SessionModel 击打累加/计时。
- **CLI smoke**:启动二进制 → 窗口出现、顶栏时钟走动、按键累加 Strikes(可通过 offscreen 平台 + 日志断言,或人工/截图)。
- 受限于 GUI,核心逻辑(映射/累加/配置)走单测;视觉走人工/截图核验。

## 11. 已敲定的决策

1. **切片**:B —— HMI 外壳(TopBar + Dashboard),可独立运行可交互。
2. **技术栈**:QML/Qt Quick(UI)+ C++(后端),CMake + Qt 6.11。
3. **仪表盘由真实 segment 输入驱动**(非静态)。
4. **工程位置**:独立仓 `/home/x/code/pd02/qxzn-hmi-qt/`(镜像 qtcli/godotctl)。
5. **硬件/网络全部 stub**;仅键盘 segment 映射与配置解析为真实实现。

## 12. 后续阶段(本 spec 不展开)

- 阶段 D1:qtcli 增强 —— 基于本工程 dogfooding 撞上的短板(认 .qml / 列结构 / lint)。
- 阶段 D2:移植一个最小 2D 小游戏(如 PianoTiles)以测试 Qt Quick 动画/游戏能力。
- 阶段 D3:真实 WS/API 桥接、LED/电机 stub → 真实。
- 阶段 D4:课程页 / 媒体播放。

## 13. 风险与备注

- Qt Quick Controls 2 的主题/样式在不同平台默认不同;需显式设定深色 palette/style 以保证一致观感。
- kiosk 全屏在不同窗口系统(X11/Wayland)行为略异;提供 `--windowed` 兜底。
- 频率 Frequency 的「击打/分钟」用滑动窗口近似,非精确生理指标(本切片只求可交互)。
- 字体加载失败需有兜底(系统默认字体),不能崩。
