# qxzn-hmi-qt 移植交接文档（Godot 外壳 → Qt/QML）

> 写给接手继续移植的工程师/AI。读完本文应能零额外上下文继续工作。
> 文档日期：2026-07-22。对应计划：`本仓 docs/superpowers/specs/2026-07-15-qxzn-hmi-shell-design.md`（切片 B 已完成并远超其范围）。

## 0. 一句话现状

Godot 项目 `15-6inch-game-runtime-qxzn` 的**外壳全部页面**已按 1920×1080 像素级移植到本仓（Qt 6.11.1 / CMake / 纯 QML + 少量 C++）；DDS 通信第一切片（`pd02/hit/event` 输入 + `pd02/led/command` 输出）已完成并本地 round-trip 验证；**课程播放器第一切片已完成**——三门纯视频课（专项练习 / 站姿 / 右直拳）经自定义 GStreamer 后端端到端播放并通过真实媒体测试；**AI 教练页面和云端文案增强客户端已完成**。其余页面数据仍以静态种子为主；**游戏、AI 动作纠正、BodyCombat 电机编排、其余 REST 设备接口仍未移植**。

⚠️ **当前所有移植改动还在工作区未提交**（~48 项改动）。接手前请先 `git status` 确认，建议先提交或打包保留，避免被误清。

## 1. 仓库与环境

- 本仓：`/home/x/code/pd02/qxzn-hmi-qt`（独立 git 仓，分支 master，远端 github.com:zhaojiaxiang370711/qttest）
- Godot 源项目（**只读参考，禁止修改**）：`/home/x/code/pd02/15-6inch-game-runtime-qxzn`
- Qt 6.11.1：`/opt/Qt/6.11.1/gcc_64`；构建目录 `build/`（已配置）
- **构建并发永远 ≤6**：`cmake --build build --parallel 6`（PD02 根 AGENTS.md 硬约束）
- qtcli（本项目是其 dogfood 工程）：`~/.cargo/bin/qtcli`，skill 在 `/home/x/code/pd02/.agents/skills/qtcli/SKILL.md`

## 2. 已完成清单（验证全绿）

页面（`qml/`，均已像素级移植并截图目检通过）：

| QML | Godot 源 | 备注 |
|---|---|---|
| `TopBar.qml` | `scenes/TopBarView.tscn` + `scripts/shell_top_bar.gd` | 头像双色环/4 nav tab/wifi→device/时钟/退出 |
| `HomePage.qml` | `scenes/pages/HomePageView.tscn` + `scripts/pages/home_page.gd` | 训练总览+日程+发现课程+推荐卡横滑 |
| `LearningPage.qml` | `modules/course/internal/course_view.gd` | 课程轮播+大播放钮+5 入口卡（合并布局，见偏差） |
| `ResultPage.qml` | `scripts/pages/result_page.gd` + `sparring_history_page.gd` | 双 tab；预览帧图+渐变遮罩；训练数据+柱状图 |
| `CombatPowerPage.qml` | `scripts/pages/combat_power_page.gd` | 分数卡+开始/结束+三模式卡 |
| `DevicePage.qml` + 10 个 `Device*Panel.qml` | `scripts/pages/device_page.gd` | 13 卡 4 列网格+10 覆盖面板（volume/display/system/pressure/face 完整，余简化）+ 重启关机确认框 |
| `EntertainmentPage.qml` | `scripts/pages/card_page.gd` + `scripts/shell_card_grid.gd` | 14 卡封面网格 |
| `GameLauncher` | App `/api/v1/game/start` | `vr_beats_kit` 卡片触发 Qt → Godot → Qt 的既有后端交接链 |
| `FitnessPage.qml` / `AiCoachPage.qml` / `BoxingKnowledgePage.qml` | `scripts/pages/fitness_page.gd` / Web `DeviceAiPage.vue` / `boxing_knowledge_page.gd`(+`shell_page_data.gd`) | 子页；AI 助手支持快捷筛查、自由文本、筛查摘要/安全提示、C++ HTTPS 云端增强、本地安全兜底和推荐入口路由 |
| `CourseLessonPage.qml` | `modules/course/internal/course_lesson_page.gd`（仅纯视频形态） | GStreamer 视频播放器子页；返回/标题、进度+动作标记、播放/标记导航、音量/静音、加载/缺媒体/错误/结束遮罩 |

地基：`Main.qml`（1920×1080 设计坐标，等比缩放适配实际屏幕——2026-07-22 修复黑边）、单例 `Theme/AppState/ShellData`、C++ 单例 `Config/AiAssistantClient/SessionModel/DdsBridge`、课程后端 `CourseCatalog/CoursePlaybackController(QML CoursePlayer)/CourseVideoSurface`、组件 `HmiCard/HmiInset/HmiIcon/HmiButton/ClickFlash/CalloutHost/HmiBarChart/NeumorphShadow`、资产同步脚本 `scripts/sync_godot_assets.sh`（239 个资产）、CLI `--nav/--overlay/--screenshot/--course/--media-root`。

验证基线（接手后每次改动必须保持全绿）：

```bash
cd /home/x/code/pd02/qxzn-hmi-qt
cmake --build build --parallel 6
ctest --test-dir build --output-on-failure        # tst_core + tst_course_video_surface + qml_smoke；dds_smoke/course_playback 无测试件时 skip
QXZN_MEDIA_DIR=/home/x/code/pd02/15-6inch-game-runtime-qxzn/media/library \
  QXZN_GST_DECODER=software QXZN_MEDIA_AUDIO_SINK=fakesink \
  ctest --test-dir build -R '^course_playback$' --output-on-failure   # 真实媒体播放生命周期
qtcli --json --project . lint                     # qmllint 0 诊断
qtcli --json --project . qml-audit --strict       # 0 findings
```

页面截图目检（软件渲染离屏，必须带 `--windowed`，`--nav` 接受页面 id 和子页 id，`--overlay` 开设备面板）：

```bash
QT_QUICK_BACKEND=software ./build/qxzn_hmi -platform offscreen --windowed \
    --nav learning --screenshot /tmp/x.png --quit-after-ms 1500
```

## 3. 架构契约（新代码必须遵守）

- **坐标规则**：Godot 多数页面按 1280×720 书写、运行时 ×1.5 → QML 用 `Theme.px(v)`（=round(v×1.5)）；字号 ×1.56 → `Theme.fontPx(v)`；`scenes/*.tscn` 节点版数值（1920 基准）直接用。页面根 = 页面容器内容区，局部坐标 = Godot 屏幕坐标 − (48,150)。关键矩形注释注明 Godot 源值。
- **Theme 单例**（`import QxznHmi`）：色板 `panel panelMask text muted mutedSoft primary cyan success warn danger orange purple cardBorder cardHighlight edgeDark navSelected windowBackground`；字体 `bodyFamily`("Alimama ShuHeiTi") / `brandFamily`("Alimama Agile VF")；圆角 `radiusCard 28/radiusCardInner 22/radiusTab 18/radiusPill 29/radiusButton 18`；字号 `fontTiny 14…fontHuge 137`；`topBarRect`/`pageRect`。
- **AppState 单例**：`selectedNav`(home/learning/result/entertainment/device/combat)、`subPage`(fitness/ai_coach/boxing_knowledge/course_lesson)、`overlayPanel`、`courseId`(默认 `special_practice`)、`selectNav/openSubPage/openOverlay/closeOverlay/back/showCallout/applyInitial/openCourse`。新页面在 `Main.qml` 的 Loader 映射表登记（navPages/subPages）。
- **课程后端 C++ 单例**：`CourseCatalog`（6 启动器 + 3 视频课 + 动作标记；`launchers/courses/defaultCourseId/defaultLauncherIndex/contains/course`）、`CoursePlaybackController`（QML 名 `CoursePlayer`；在 `main.cpp` 用 `Config` 配置媒体根+解码策略，`aboutToQuit` 调 `stop()`）、`CourseVideoSurface`（可实例化 `QQuickItem`，非单例，`controller` 属性接 `CoursePlayer`）。课程媒体**只走外部** `QXZN_MEDIA_DIR`/`--media-root`，CMake 在 `QXZN_ASSET_FILES` 见视频即 FATAL_ERROR；课程代码不引用 DDS/SessionModel/REST/摄像头/电机/LED。
- **ShellData 单例**：全部静态种子（照抄 `shell_data.gd`）：`navItems/learningCards/resultCards/deviceCards/entertainmentCards/combatModes/homeSummary/deviceStatus/sparringSummary` + `coverFor(cardId)`。后续 REST/状态模型接入时保持字段名不变，逐步把静态值换成实时绑定。
- **AiAssistantClient C++ 单例**：只调用 `https://cloud.qxrobot.com/api/v1/ai/training-assistant`（可由 `QXZN_CLOUD_API_BASE` / `--cloud-api-base` 覆盖），从 `QXZN_DEVICE_SYNC_TOKEN_FILE` / `--device-sync-token-file` 读取可撤销设备令牌；供应商 API key 只能放在 `cloud-server`。30 秒超时/服务错误必须回退到页面本地安全规则，不能阻断筛查。
- **DdsBridge C++ 单例**：通过 `QLibrary` 动态加载 `dds-fastdds-core` C ABI；订阅 `pd02/hit/event` 并与键盘共用 `SessionModel.onSegment()`，显式发布 `pd02/led/command`。状态为 `disabled/loading/ready/receiving/error`；`ready` 不代表远端 match；hit 不自动触发 LED。DDS 不可用时 UI 和键盘回退必须继续工作。
- **组件**：`HmiCard{default property alias content; radius; fillColor; showShadow}`、`HmiInset`、`HmiIcon{name; tone(white/muted/cyan/green/yellow/red/orange); size}`、`HmiButton{text; kind(primary/ghost/danger); clicked()}`、`ClickFlash{flash()}`、`CalloutHost`（已在 Main 挂载，只调 `AppState.showCallout`）、`HmiBarChart{values; barColor}`。
- **资源**：全部走 qrc，`qrc:/resources/images/<dir>/<file>`、`qrc:/resources/icons/lucide/<name>_<tone>.svg`（29 图标 × 7 色，新图标在 `sync_godot_assets.sh` 里加源文件后重跑脚本，**不要手改** `resources/assets-manifest.cmake`）。
- 每个 QML 文件首行 `pragma ComponentBehavior: Bound`；新文件加进 `CMakeLists.txt` 的 `QML_FILES`；新单例的 `set_source_files_properties(... QT_QML_SINGLETON_TYPE TRUE)` 必须写在 `qt_add_qml_module` **之前**。
- 未移植入口点击统一 `AppState.showCallout("info","未移植","<名称>将在后续阶段移植")`。

## 4. 已知偏差（有意为之，勿当 bug 修）

视频→静态抽帧仅限对战预览（`sparring_preview_frame.jpg`）；课程视频已改为 GStreamer 实播（cpu-copy RGBA → `QSGSimpleTextureNode`，非 Godot 播放器）；i18n→中文硬编码；手绘符号→Lucide SVG（变色为烘焙变体，因 Qt 软件渲染不支持运行时着色）；学习页轮播高 786→552 以同页放 5 张入口卡；设备网格 13 卡×4 列（Godot 为 12×3）；字体基线 ±2–3px（Qt/Godot 排版差异）；AI 推荐浮层/设备面板遮罩只覆盖页面容器（容器 clip）。完整清单见 `README.md` 末节。

## 5. 剩余工作（按建议顺序）

### D2a 通信层（DDS 第一切片已完成；继续扩展 live 数据）

- **已完成**：`DdsBridge` 通过 `QLibrary` 动态加载 `/home/x/code/pd02/dds-fastdds-core` 的稳定 C ABI；直接订阅 `pd02/hit/event`、显式发布 `pd02/led/command`，不链接 Fast DDS SDK，也不依赖 :8000 WebSocket 热路径。键盘与 DDS hit 共用 `SessionModel.onSegment()`；DeviceHitTestPanel/TopBar/DevicePage 已显示 live DDS 状态。
- 当前部署发现配置的权威默认值是 **domain 37 + multicast off + initial peer `127.0.0.1`**。core 支持 `server://HOST:PORT`，但当前并未默认使用 `127.0.0.1:11811` discovery server。
- 构建默认 `QXZN_HMI_DDS=ON`；独立仓可用 `-DQXZN_HMI_DDS=OFF`。运行时 core 路径可用 `PD02_DDS_CORE_LIB` / `--dds-core-lib`；部署时必须同时满足 `ldd` 列出的 Fast DDS/Fast CDR/foonathan 依赖。
- 可选集成测试：`PD02_DDS_CORE_LIB=/path/libqxzn_pd02_dds_core.so ctest --test-dir build -R '^dds_smoke$' --output-on-failure`，使用独立 domain/topic，不操作真实 LED。
- **剩余**：`pd02/pressure/sample` → 压力面板，`pd02/motor/state` → 电机/课程状态，`pd02/pressure/control` → 游戏 session；设备操作、诊断、战力/课程 session、OTA 仍通过后续 `RestClient` 对接 `--api-base`。Godot 的 `height_control_status` / `ai_motion_correction_status` 可先走低频 REST，不新增 WS 热路径。

### D2b 游戏移植（每个游戏 = 一个 QML 页 + AppState 路由）

Godot 源（均为自绘 Control 状态机，行数即工作量）：`scripts/games/ai_battle.gd`(560)、`piano_tiles.gd`(647)、`sparring_game_tab.gd`(715)、`tactical_sparring.gd`(970)、`performance_jam.gd`(1029)、`agility_challenge.gd`(1253)、`interstellar_bounce_scene.gd`(1276，BOUNCE 屏)、`tracking_challenge.gd`(1833)。建议从 `piano_tiles` 开始做样板。注意：游戏击打输入来自 WS/DDS hit_event（先做键盘 QWERXASDF 回退，`SegmentInput` 已有映射）；LED 控制走通信层。`FruitSliceGame.cs` 是 C# 3D——建议保留"外部启动"方式（POST `/api/v1/game/start`）或上 Qt3D，不要硬搬。

### D1 课程详情（纯视频切片已完成；AI/电机形态待移植）

`modules/course/internal/course_lesson_page.gd`（6533 行）三种形态：
- **专项练习 / 站姿 / 右直拳（纯视频）——已完成**：自定义 GStreamer 后端（`playbin3 → appsink RGBA 1280×720 → CourseVideoSurface`），`CourseLessonPage.qml` 全控件，真实媒体测试绿。详见 `README.md`「课程播放器」节与本仓 `docs/superpowers/specs/2026-07-23-course-video-player.md`。
- **AI 动作纠正**：三阶段状态机 + REST `/api/v1/ai-motion-correction/sessions` + MJPEG 摄像头 `/camera/stream`，未移植。
- **BodyCombat 搏击操**：电机编排 `bodycombat_hardware_orchestrator.gd` + DDS，未移植（手靶/搏击操/莱美三个互动入口当前提示"互动训练待移植"）。

### D4 媒体播放（课程视频已完成；摄像头流待移植）

课程视频播放已完成：自定义 GStreamer 后端（**不用** Qt Multimedia / 其 FFmpeg 插件），`QXZN_GST_DECODER=auto|software|mpp` 按.rank 选 `mpph264dec`/`mppvideodec`/`avdec_h264`；当前 x86 目标以 `avdec_h264` 软解验证，MPP 为 RK3588 预留。课程视频在 Godot 仓 `media/library/course/**/*.mp4`（按需拷贝/挂载到 `QXZN_MEDIA_DIR`，勿进 qrc——CMake 已加断言）。第一渲染器是明确标注的 **cpu-copy**，零拷贝/DMA-BUF/4K 为后续验收项。MJPEG 摄像头流（`QNetworkAccessManager` 流式解析 multipart）仍未移植。

### 其他遗留

- i18n：`scripts/shell_i18n.gd` 509 条 zh/en（当前硬编码中文）
- 音效：`assets/audio/sfx/hit.mp3` + 程序合成提示音 `scripts/audio_feedback.gd`（22050Hz 正弦）
- OTA：`http://127.0.0.1:9100` manifest/下载（`device_model.gd` 内）
- 真机验证：目标机 `172.16.1.222`（GNOME Wayland+Xwayland `:0`，外屏 3840×2160，部署前先 `xrandr --listmonitors`，启动后必须 `xwininfo` 核窗口几何——流程见 PD02 根 AGENTS.md"Runtime Test Machine"节）
- qml-test-audit 有既有警告 QTEST001（无 `tst_*.qml`），如引入 Qt Quick Test 可消

## 6. 并行代理工作法（本轮已验证有效）

1. 地基/共享文件（Theme/AppState/ShellData/Main/CMake）**先由单个代理完成并验证绿**；
2. 页面级任务用 swarm 并行，每代理只写自己的 QML 文件；共享 build 目录必须 `flock /tmp/qxzn_hmi_build.lock cmake --build build --parallel 2`；
3. 每代理交付标准：lint 0 诊断 + flock 构建绿 + 截图目检 + 偏差清单；
4. 主代理最后统一全量验证（§2 命令组）。

## 7. 踩过的坑（别再踩）

1. `QT_QML_SINGLETON_TYPE TRUE` 写在 `qt_add_qml_module` 之后 → 运行期单例 undefined（qmllint 查不出）。
2. `qt_add_resources` 不加 `BASE` → qrc 路径出现 `resources/resources/` 双目录。
3. offscreen 截图**必须带 `--windowed`**，否则 `showFullScreen()` 落到 800×800。
4. Qt 软件渲染（`QT_QUICK_BACKEND=software`）不支持 MultiEffect → SVG 变色必须在资产同步时烘焙（`sync_godot_assets.sh` 已处理 7 色变体）。
5. 字体真实族名是 "Alimama ShuHeiTi"（无空格）和 "Alimama Agile VF"（`fc-scan` 确认）。
6. Lucide 源 SVG 是 `stroke="#ffffff"`（非 currentColor），sed 按此替换。
7. Godot `HMI_PURPLE == HMI_DANGER`（原值如此，`Theme.purple` 有注释）。
8. 并行代理同时构建同一 build 目录会竞态 → 必须 flock。
9. `Qt.colorAlpha` 过不了 qmllint（误报）→ 用本地 `Qt.rgba(c.r,c.g,c.b,a)` 辅助函数（各页面已有 `alpha()` 惯例）。
10. 5120×2880 这类非 1920×1080 屏幕：Main.qml 已做等比缩放适配，新页面继续按 1920 设计坐标写即可，不要自己加缩放。

## 8. 完成定义（DoD）

- §2 的 4 条验证命令全绿；新增页面有 `--nav` 截图并与 Godot 源矩形核对（±2–3px 字体容差）
- 新偏差写进 `README.md` 末节；本交接文档相应章节更新
- 不动 Godot 仓；构建 ≤6 jobs；不提交任何 git（除非用户明确要求）
