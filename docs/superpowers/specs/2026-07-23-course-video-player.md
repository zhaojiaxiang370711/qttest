# 课程视频播放器设计 / 验证记录（2026-07-23）

> 切片：三门纯视频课的 GStreamer 端到端播放。对应计划：`/home/x/.claude/plans/enchanted-wibbling-gem.md`。
> 关联：`README.md`「课程播放器」节、`docs/PORTING_HANDOFF.md` §5 D1/D4。

## 1. 范围

**纳入**：三门纯视频课的完整播放流程——
- `special_practice`（专项练习，默认选中，103.5 s，21 个动作标记）
- `stance`（基础系列：站姿教学，22.1 s）
- `right_straight`（基础系列：右直拳教学，25.6 s）

**排除**（显式不在本切片）：AI 动作纠正 / REST session、MJPEG 摄像头流、DDS、电机、LED、击打判定、硬件动作标记、BodyCombat 电机编排。三个互动入口（`focus_mitt`/`bodycombat`/`lesmills_bodycombat`）保留可见，点击提示「互动训练待移植」。

## 2. 媒体架构（有意不用 Qt Multimedia）

自定义 C++ GStreamer 后端，**不**使用 `Qt6::Multimedia` / `MediaPlayer` / `VideoOutput` / `qml6glsink` / Qt FFmpeg 插件（`find_package` 不含 Multimedia，CMake 已固化）：

```text
playbin3（单一 A/V 时钟）
  video-sink = queue(leaky=downstream, max-buffers=2)
             ! videoscale ! videoconvert
             ! capsfilter(video/x-raw, RGBA, 1280×720, par 1/1)
             ! appsink(sync=true, max-buffers=2, drop=true)
  audio-sink = autoaudiosink（测试用 fakesink）
```

- GStreamer 负责 demux / H.264+AAC 解码 / seek / 缓冲 / 音视频同步。
- `appsink` 回调把最新 RGBA 帧深拷进一个受锁保护的单帧 `QImage` 槽。
- `CourseVideoSurface`（`QQuickItem`）在渲染线程通过 `QSGSimpleTextureNode` + `QQuickWindow::createTextureFromImage` 上传最新帧，aspect-contain 几何，黑色舞台。
- **帧 pacing**：`appsink sync=false` + `pullSample()` 里按媒体帧率 `g_usleep` 手动节流。原因：`appsink sync=true` 在本 playbin3 管线里被错调成 ~1fps（每帧间隔 ~1s），视频像幻灯片；`sync=false` 让上游全速跑（解码 ~64× 实时），所以在回调里按 caps 的 `fps_n/fps_d` 节流到 1× 播放。代价：长片下视频（壁钟）与音频（管线钟）可能漂移，训练片（1–2.5 分钟）可忽略；需要长片时再接入共享时钟。可用 `QXZN_HMI_VIDEO_DEBUG=1` 打印每秒 `decoded/presented` 帧率。
- **交付分辨率**运行时可调：`QXZN_GST_FRAME_WIDTH/HEIGHT`（默认 1280×720，编译期由同名 CMake cache 变量设定）。更小帧 = 更少的 videoconvert/拷贝/纹理上传，便于 A/B 测 cpu-copy 负载。

**诚实的渲染器边界**：`CoursePlayer.rendererMode == "cpu-copy"`。这是有界 CPU 拷贝路径（每帧拷贝 RGBA + 上传纹理），**不是**零拷贝 / DMA-BUF / 4K 实现。零拷贝为后续 RK3588 验收项。

### 2.1 组件

| 文件 | 职责 |
|---|---|
| `src/course_catalog.{h,cpp}` | 6 启动器 + 3 视频课 + 动作标记；`defaultCourseId=special_practice`、`defaultLauncherIndex=3`。标记只带 `timeMs+label`（刻意不带 action/speed_scale，杜绝硬件副作用）。 |
| `src/media_path_resolver.{h,cpp}` | 安全解析外部媒体：只接受目录里允许的 catalog key，拒绝遍历/符号链接逃逸/URL/缺失。 |
| `src/gst_decoder_policy.{h,cpp}` | `configure(auto\|software\|mpp)` 按.rank 选 `mpph264dec`>`mppvideodec`>`avdec_h264`；`activeDecoder()` 递归查实际解码器；`gst_init_check` 一次性。 |
| `src/gst_playback_worker.{h,cpp}` | `QObject` 在独立 `QThread`；own playbin3/appsink，20 ms 轮询 bus / 100 ms 查 position；generation 计数丢弃过期事件。 |
| `src/course_playback_controller.{h,cpp}` | QML 单例 `CoursePlayer`；完整属性/invokable；标记逻辑（prev=position−350ms，next=position+350ms，不回绕）。 |
| `src/course_video_surface.{h,cpp}` | `QQuickItem`；GUI 线程存帧→渲染线程 `updatePaintNode` 上传；`containRect()` 静态可测；提交帧时机回馈 controller 诊断。 |
| `qml/CourseLessonPage.qml` | 播放器 UI（返回/标题、时间、带标记刻度的进度条、传输钮、音量/静音、加载/缺媒体/错误/结束遮罩）。 |

## 3. 解码策略与验证目标

`QXZN_GST_DECODER=auto|software|mpp`（默认 `auto`）：
- `auto`：rank 优先 MPP，否则 `avdec_h264`。
- `software`：强制 `avdec_h264`，不符即报错。
- `mpp`：要求 `mpph264dec`/`mppvideodec` 存在，否则报错。

**当前验证目标 `172.16.1.222` 为 x86_64**，以 `avdec_h264` 软解验证；本机 GStreamer 1.28.2，`mpph264dec`/`mppvideodec`/`qml6glsink` 均不存在。MPP 路径为未来 RK3588 预留。播放器诊断条显示实际解码器名与实时 `presentedFps`。

## 4. 外部媒体契约

课程 MP4 **永不进 qrc / git**：
- `CMakeLists.txt` 遍历 `QXZN_ASSET_FILES`，命中 `mp4/mov/mkv/...` 即 `FATAL_ERROR`。
- 运行时 `QXZN_MEDIA_DIR` / `--media-root` 解析，期望目录 `<root>/course/{special_practice,stance_en,right_straight_en}.mp4`。
- 无有效根目录 → 受控「课程媒体文件不可用，请配置 QXZN_MEDIA_DIR」遮罩 + 重试/返回，不崩溃。
- 交付帧尺寸缓存项：`QXZN_HMI_GST_FRAME_WIDTH/HEIGHT`（默认 1280×720）。

## 5. QML 接入

- `AppState`：新增 `course_lesson` 子页、`courseId`、`openCourse(id)`（经 `CourseCatalog.contains` 校验）、`applyInitial(nav, overlay, course)` 支持 `--nav course_lesson --course <id>`。
- `Main.qml`：Loader `subPages` 加 `course_lesson → CourseLessonPage.qml`。
- `LearningPage.qml`：硬编码数组换 `CourseCatalog.launchers`，默认 `defaultLauncherIndex`（专项练习）；video→`openCourse`，interactive→「互动训练待移植」callout。
- `main.cpp`：取 `CoursePlayer` 单例 `configure(Config)`，`aboutToQuit`→`stop()`。
- `qml_singletons.h`：`CourseCatalogQmlForeign`、`CoursePlayerQmlForeign`（单例）、`CourseVideoSurfaceQmlForeign`（可实例化类型）。
- `CourseLessonPage` 进入 `Qt.callLater` 开课（规避 deep-link 时 `configure` 与 `openCourse` 的竞态），`Component.onDestruction` 调 `stop()`。**不引用** DDS/SessionModel/REST/摄像头/电机/LED。

## 6. 验证结果（2026-07-23）

```bash
ctest --test-dir build --output-on-failure
# tst_core(39) + tst_course_video_surface(5) + qml_smoke(home + course_lesson 缺媒体) 全绿
# dds_smoke / course_playback 无测试件时 skip(77)
```

带测试件：
- `tst_course_playback`：真实 `special_practice.mp4`，`avdec_h264`，首帧→暂停/拖动/标记/音量/静音→结束→重播→停止，3/3 绿，无 GStreamer-CRITICAL。
- `tst_course_video_surface`：合成帧在 **software 与默认**两种场景图后端渲染，5/5 绿。
- `tst_dds_smoke`：带 core lib round-trip，3/3 绿（DDS 层未受影响）。
- DDS=ON / DDS=OFF 两种构建均通过（OFF 时 tst_core 31 项，DDS bridge 测试 #ifdef 掉）。

离屏真机级目检：`--nav course_lesson --course special_practice` + 真实媒体，视频帧（标题卡）经 `CourseVideoSurface` 渲染、控件齐全、无 QML 错误；缺媒体运行仅出现受控错误遮罩。

## 7. 后续（不在本切片）

- RK3588 MPP 硬解验收（`mpph264dec`/`mppvideodec`）。
- 零拷贝 / DMA-BUF 渲染器（替换 cpu-copy）。
- AI 动作纠正 + MJPEG 摄像头流 + BodyCombat 电机编排（D1 剩余形态）。
- 真机 `172.16.1.222` 部署（待用户明确批准后方可写入目标机）。
